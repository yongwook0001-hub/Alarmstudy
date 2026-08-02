import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/material_set.dart';
import 'folder_detail_screen.dart';

class StudyMaterialScreen extends StatefulWidget {
  final List<MaterialSet> sets;
  final Future<void> Function(String title) onCreateFolder;
  final Future<void> Function(int setId) onDeleteFolder;
  final Future<void> Function(int setId) onSetChanged;

  const StudyMaterialScreen({
    super.key,
    required this.sets,
    required this.onCreateFolder,
    required this.onDeleteFolder,
    required this.onSetChanged,
  });

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  bool _creating = false;

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
    if (name == null || name.isEmpty) return;

    setState(() => _creating = true);
    try {
      await widget.onCreateFolder(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _confirmDeleteFolder(MaterialSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('폴더를 삭제할까요?', style: TextStyle(color: kFg)),
        content: Text('"${set.title}" 폴더와 안의 PDF가 모두 삭제돼요. 이 폴더를 쓰던 알람은 "퀴즈 없음"으로 바뀝니다.',
            style: TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.onDeleteFolder(set.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 삭제 실패: $e')),
        );
      }
    }
  }

  void _openFolder(MaterialSet set) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderDetailScreen(
          set: set,
          onChanged: () => widget.onSetChanged(set.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.sets;

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
                    onTap: _creating ? null : _createFolder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _creating ? kMuted : kPrimary,
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
                child: sets.isEmpty
                    ? Center(
                  child: Text('폴더가 없어요. 우측 상단에서 만들어보세요.',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                )
                    : GridView.builder(
                  itemCount: sets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (_, i) => _folderCard(sets[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderCard(MaterialSet set) {
    return GestureDetector(
      onTap: () => _openFolder(set),
      onLongPress: () => _confirmDeleteFolder(set),
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
            const Spacer(),
            Text(set.title,
                style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('PDF ${set.materialCount}개 · 길게 눌러 삭제',
                style: TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
