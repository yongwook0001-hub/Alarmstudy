import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/study_material.dart';
import '../services/ai_service.dart';

class StudyMaterialScreen extends StatefulWidget {
  final List<StudyMaterial> materials;
  final Function(StudyMaterial) onSummary;
  final Function(StudyMaterial) onMaterialAdded;

  const StudyMaterialScreen({
    super.key,
    required this.materials,
    required this.onSummary,
    required this.onMaterialAdded,
  });

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  final _textController = TextEditingController();
  String _selectedSubject = '한국사';
  bool _loading = false;
  String? _error;
  String? _pickedFileName;

  static const _subjects = ['한국사', '영어', '수학', '과학', '사회', '기타'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // Gemini 인라인 전송 한도 10MB — 초과 시 API 에러 방지
    const maxBytes = 10 * 1024 * 1024;
    if (file.bytes!.length > maxBytes) {
      setState(() => _error = 'PDF가 너무 큽니다 (최대 20MB). 더 작은 파일을 사용해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _pickedFileName = file.name;
      _textController.clear();
    });

    try {
      final material = await AiService.summarizePdf(
        pdfBytes: file.bytes!,
        subject: _selectedSubject,
      );
      widget.onMaterialAdded(material);
      setState(() {
        _loading = false;
        _pickedFileName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 요약이 완료됐어요!'), backgroundColor: kPrimary),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'PDF 분석 실패: $e';
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
      _pickedFileName = null;
    });

    try {
      final material = await AiService.summarizeText(
        text: text,
        subject: _selectedSubject,
      );
      widget.onMaterialAdded(material);
      setState(() {
        _loading = false;
        _textController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 요약이 완료됐어요!'), backgroundColor: kPrimary),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'AI 요약 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('학습 자료'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: kPrimary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('AI 요약', style: TextStyle(color: kPrimary, fontSize: 13)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 입력 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('학습 자료 입력', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 12),

              // 과목 선택
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                dropdownColor: kCard,
                decoration: InputDecoration(
                  labelText: '과목',
                  labelStyle: const TextStyle(color: kMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kPrimary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(color: kFg),
                items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
              ),
              const SizedBox(height: 12),

              // 텍스트 입력
              TextField(
                controller: _textController,
                maxLines: 6,
                style: const TextStyle(color: kFg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '공부할 내용을 붙여넣거나 직접 입력하세요.\nAI가 자동으로 요약하고 퀴즈를 생성합니다.',
                  hintStyle: const TextStyle(color: kMuted, fontSize: 13, height: 1.5),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kPrimary),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: kBorder),
              const SizedBox(height: 12),

              // PDF 선택 표시
              if (_pickedFileName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kPrimary.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.picture_as_pdf, color: kPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_pickedFileName!,
                          style: const TextStyle(color: kPrimaryLight, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // 에러
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
                const SizedBox(height: 8),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // PDF 업로드 버튼
                  GestureDetector(
                    onTap: _loading ? null : _pickPdf,
                    child: Row(children: [
                      Icon(Icons.upload, color: _loading ? kMuted : kPrimary, size: 16),
                      const SizedBox(width: 6),
                      Text('PDF 업로드',
                          style: TextStyle(color: _loading ? kMuted : kPrimary, fontSize: 13)),
                    ]),
                  ),

                  // AI 요약 생성 버튼
                  GestureDetector(
                    onTap: _loading ? null : _summarizeText,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: _loading
                            ? null
                            : const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                        color: _loading ? kBorder : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
                            )
                          : const Row(children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('AI 요약 생성',
                                  style: TextStyle(color: Colors.white, fontSize: 13)),
                            ]),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // 저장된 자료 목록
          const Text('저장된 자료', style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...widget.materials.map((m) => GestureDetector(
            onTap: () => widget.onSummary(m),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(m.subject,
                        style: const TextStyle(color: kPrimaryLight, fontSize: 11)),
                  ),
                  const Icon(Icons.chevron_right, color: kMuted, size: 18),
                ]),
                const SizedBox(height: 8),
                Text(m.title,
                    style: const TextStyle(color: kFg, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(m.summary,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 10),
                const Divider(color: kBorder),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.psychology, color: kPrimary, size: 14),
                    const SizedBox(width: 4),
                    Text('퀴즈 ${m.quizCount}문제',
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ]),
                  Text(m.date, style: const TextStyle(color: kMuted, fontSize: 12)),
                ]),
              ]),
            ),
          )),
        ],
      ),
    );
  }
}
