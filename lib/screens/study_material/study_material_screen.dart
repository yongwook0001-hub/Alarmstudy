import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/study_material.dart';
import 'folder_detail_screen.dart';

class StudyMaterialScreen extends StatefulWidget {
  final List<StudyMaterial> materials;
  final Function(StudyMaterial) onMaterialAdded;
  final Function(int) onMaterialDeleted;

  const StudyMaterialScreen({
    super.key,
    required this.materials,
    required this.onMaterialAdded,
    required this.onMaterialDeleted,
  });

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  // 아직 파일이 하나도 없는 "빈 폴더" 이름들 (사용자가 미리 폴더만 만들어둔 경우)
  final Set<String> _emptyFolders = {};

  Map<String, List<StudyMaterial>> get _grouped {
    final map = <String, List<StudyMaterial>>{};
    for (final m in widget.materials) {
      map.putIfAbsent(m.subject, () => []).add(m);
    }
    return map;
  }

  List<String> get _folderNames {
    final names = {..._grouped.keys, ..._emptyFolders}.toList();
    names.sort();
    return names;
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('폴더 생성', style: TextStyle(color: kFg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: kFg),
          decoration: InputDecoration(
            hintText: '예: 운영체제',
            hintStyle: TextStyle(color: kMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('생성', style: TextStyle(color: kPrimary)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _emptyFolders.add(name));
    }
  }

  void _openFolder(String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderDetailScreen(
          subject: subject,
          materials: widget.materials.where((m) => m.subject == subject).toList(),
          onMaterialAdded: widget.onMaterialAdded,
          onMaterialDeleted: widget.onMaterialDeleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final names = _folderNames;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('학습자료',
                          style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('폴더를 생성하고 PDF를 넣어보세요!',
                          style: TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _createFolder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('폴더 생성',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: names.isEmpty
                    ? Center(
                  child: Text('폴더가 없어요. 우측 상단에서 만들어보세요.',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                )
                    : GridView.builder(
                  itemCount: names.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (_, i) {
                    final name = names[i];
                    final files = grouped[name] ?? [];
                    final totalQuiz = files.fold<int>(0, (sum, m) => sum + m.quizCount);
                    return _folderCard(name, files.length, totalQuiz);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderCard(String name, int fileCount, int totalQuiz) {
    return GestureDetector(
      onTap: () => _openFolder(name),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.folder, color: kPrimary, size: 18),
                ),
                if (fileCount == 0)
                  GestureDetector(
                    onTap: () => setState(() => _emptyFolders.remove(name)),
                    child: Icon(Icons.more_horiz, color: kMuted, size: 18),
                  ),
              ],
            ),
            const Spacer(),
            Text(name,
                style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('PDF ${fileCount}개 · 문제 ${totalQuiz}개',
                style: TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}