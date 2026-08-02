import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/material_set.dart';
import '../../models/study_material.dart';
import '../../services/materials_service.dart';
import '../../services/song_store.dart';
import 'ai_summary_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final MaterialSet set;
  final Future<void> Function() onChanged; // 부모(AppData)에게 "세트가 바뀌었으니 다시 불러와" 알림

  const FolderDetailScreen({super.key, required this.set, required this.onChanged});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  bool _uploading = false;
  String? _error;
  String? _pickedFileName;

  static const _maxFilesPerSet = 5; // server/app/core/constants.py MAX_FILES_PER_SET

  // 주의: widget.set은 AppData.sets 안의 객체와 "같은 참조"를 그대로 들고 있는 것이다
  // (study_material_screen.dart에서 세트를 새 객체로 바꿔치기하지 않고 그대로 넘겨줌).
  // 그래서 업로드/삭제 후 widget.onChanged()가 AppData.refreshSetDetail을 호출해도
  // 그 메서드는 이 객체(existing)를 새 객체로 교체하지 않고 내용(materials 등)만 바꾼다 -
  // 덕분에 여기서 별도로 세트를 다시 들고 있을 필요 없이 widget.set을 그대로 쓰면 된다
  // (AiSummaryScreen에서 노래를 생성해도 같은 객체를 mutate하는 것이라 바로 반영됨).
  Future<void> _refresh() async {
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _pickAndUploadPdf() async {
    if (widget.set.materials.length >= _maxFilesPerSet) {
      setState(() => _error = '폴더당 PDF는 최대 $_maxFilesPerSet개까지 넣을 수 있어요.');
      return;
    }

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

    const maxBytes = 20 * 1024 * 1024; // server/app/core/constants.py MAX_FILE_SIZE_BYTES
    if (file.bytes!.length > maxBytes) {
      setState(() => _error = 'PDF가 너무 큽니다 (최대 20MB).');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
      _pickedFileName = file.name;
    });

    try {
      await MaterialsService.uploadPdf(
        setId: widget.set.id,
        fileName: file.name,
        bytes: file.bytes!,
        isMain: widget.set.materials.isEmpty, // 세트의 첫 파일을 메인 자료로 지정 (요약 생성 기준)
      );
      await _refresh();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMaterial(StudyMaterial m) async {
    try {
      await MaterialsService.delete(m.id);
      await SongStore.remove(m.id); // 자료가 지워졌으니 로컬 노래 연결 정보도 같이 정리
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
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
                        Text(set.title,
                            style: TextStyle(color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('PDF ${set.materials.length}/$_maxFilesPerSet개',
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
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadPdf,
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _uploading ? kBorder : kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _uploading
                          ? SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: kMuted, strokeWidth: 2),
                            )
                          : Text('PDF 업로드',
                              style: TextStyle(
                                  color: _uploading ? kMuted : Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),

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

                  if (_uploading && _pickedFileName != null) _pendingTile(_pickedFileName!),

                  if (set.materials.isEmpty && !_uploading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('아직 업로드된 PDF가 없어요.',
                          style: TextStyle(color: kMuted, fontSize: 13)),
                    ),

                  ...set.materials.map((m) => _fileTile(m)),
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
                    child: Text('업로드 중', style: TextStyle(color: kMuted, fontSize: 10)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('S3에 올리고 AI가 분석할 준비를 하고 있어요...', style: TextStyle(color: kMuted, fontSize: 12)),
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
    final pagesLabel = m.pageCount != null ? '${m.pageCount}p' : '-p';
    final statusColor = m.isReady ? kPrimary : (m.isFailed ? kRed : kMuted);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiSummaryScreen(
            material: m,
            set: widget.set,
            onDelete: () {
              _deleteMaterial(m);
              Navigator.pop(context);
            },
          ),
        ),
      ).then((_) {
        // AiSummaryScreen에서 노래를 만들었을 수 있으니(같은 객체를 mutate) 화면만 다시 그린다.
        if (mounted) setState(() {});
      }),
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
                    Expanded(child: Text(m.displayTitle, style: TextStyle(color: kFg, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(m.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('$pagesLabel · ${m.isMain ? '메인 자료' : '보조 자료'}',
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
