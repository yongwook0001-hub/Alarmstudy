import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/study_material.dart';
import '../../services/ai_service.dart';
import 'ai_summary_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final String subject; // 폴더 이름
  final List<StudyMaterial> materials; // 이 폴더 안의 파일들 (진입 시점 스냅샷)
  final Function(StudyMaterial) onMaterialAdded;
  final Function(int) onMaterialDeleted;

  const FolderDetailScreen({
    super.key,
    required this.subject,
    required this.materials,
    required this.onMaterialAdded,
    required this.onMaterialDeleted,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late List<StudyMaterial> _files;
  final _textController = TextEditingController();
  bool _showTextInput = false;
  bool _loading = false;
  String? _error;
  String? _pickedFileName;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.materials);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  int get _totalQuiz => _files.fold<int>(0, (sum, m) => sum + m.quizCount);

  String get _avgAccuracyLabel {
    final withAttempts = _files.where((m) => m.accuracy != null).toList();
    if (withAttempts.isEmpty) return '-';
    final avg = withAttempts.map((m) => m.accuracy!).reduce((a, b) => a + b) / withAttempts.length;
    return avg.round().toString();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'PDF 파일을 읽지 못했습니다. 다시 시도해주세요.');
      return;
    }

    const maxBytes = 10 * 1024 * 1024;
    if (file.bytes!.length > maxBytes) {
      setState(() => _error = 'PDF가 너무 큽니다 (최대 10MB).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _pickedFileName = file.name;
    });

    try {
      final material = await AiService.summarizePdf(
        pdfBytes: file.bytes!,
        subject: widget.subject,
      );
      widget.onMaterialAdded(material);
      setState(() {
        _files.insert(0, material);
        _loading = false;
        _pickedFileName = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _pickedFileName = null;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _summarizeText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '내용을 입력해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final material = await AiService.summarizeText(text: text, subject: widget.subject);
      widget.onMaterialAdded(material);
      setState(() {
        _files.insert(0, material);
        _loading = false;
        _textController.clear();
        _showTextInput = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'AI 요약 실패: $e';
      });
    }
  }

  void _deleteFile(int id) {
    widget.onMaterialDeleted(id);
    setState(() => _files.removeWhere((m) => m.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: kFg, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.subject,
                            style: TextStyle(color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('PDF ${_files.length}개 · 누적 문제 $_totalQuiz개 · 정답률 $_avgAccuracyLabel%',
                            style: TextStyle(color: kMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  // 세그먼트 버튼
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _loading ? null : () {
                            setState(() => _showTextInput = false);
                            _pickPdf();
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: !_showTextInput ? kPrimary : kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: !_showTextInput ? kPrimary : kBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text('PDF 업로드',
                                style: TextStyle(
                                    color: !_showTextInput ? Colors.white : kFg,
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showTextInput = !_showTextInput),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: _showTextInput ? kPrimary : kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _showTextInput ? kPrimary : kBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text('직접 입력',
                                style: TextStyle(
                                    color: _showTextInput ? Colors.white : kFg,
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_showTextInput) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 6,
                        style: TextStyle(color: kFg, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '공부할 내용을 붙여넣거나 직접 입력하세요.',
                          hintStyle: TextStyle(color: kMuted, fontSize: 13),
                          contentPadding: EdgeInsets.all(12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _loading ? null : _summarizeText,
                      child: Container(
                        height: 44,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _loading ? kBorder : kPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: _loading
                            ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: kMuted, strokeWidth: 2),
                        )
                            : const Text('AI 요약 생성',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kRed.withOpacity(0.3)),
                      ),
                      child: Text(_error!, style: TextStyle(color: kRed, fontSize: 12)),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Text('자료 목록',
                      style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // PDF 처리 중인 임시 항목 (로딩 중일 때만 상단에 표시)
                  if (_loading && _pickedFileName != null)
                    _pendingTile(_pickedFileName!),

                  ..._files.map((m) => _fileTile(m)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingTile(String filename) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: kMuted.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(Icons.picture_as_pdf, color: kMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(filename, style: TextStyle(color: kFg, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kMuted.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text('요약 중', style: TextStyle(color: kMuted, fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('AI가 분석하고 있어요...', style: TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(StudyMaterial m) {
    final accLabel = m.accuracy != null ? '${m.accuracy!.round()}%' : '-%';
    final pagesLabel = m.pages != null ? '${m.pages}p' : '-p';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiSummaryScreen(
            material: m,
            onDelete: () {
              _deleteFile(m.id);
              Navigator.pop(context);
            },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(Icons.picture_as_pdf, color: kPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(m.title, style: TextStyle(color: kFg, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kPrimary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text('요약 완료', style: TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('$pagesLabel · 문제 ${m.quizCount}개 · 정답률 $accLabel',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}