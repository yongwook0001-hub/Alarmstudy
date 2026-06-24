import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/study_material.dart';

class StudyMaterialScreen extends StatelessWidget {
  final List<StudyMaterial> materials;
  final Function(StudyMaterial) onSummary;

  const StudyMaterialScreen({
    super.key,
    required this.materials,
    required this.onSummary,
  });

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
              const SizedBox(height: 8),
              const Text(
                '공부할 내용을 붙여넣거나 직접 입력하세요. AI가 자동으로 요약하고 퀴즈를 생성합니다.',
                style: TextStyle(color: kFg, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 60),
              const Divider(color: kBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.upload, color: kMuted, size: 16),
                    SizedBox(width: 6),
                    Text('파일 업로드', style: TextStyle(color: kMuted, fontSize: 13)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('AI 요약 생성', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('저장된 자료', style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...materials.map((m) => GestureDetector(
            onTap: () => onSummary(m),
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
                    child: Text(m.subject, style: const TextStyle(color: kPrimaryLight, fontSize: 11)),
                  ),
                  const Icon(Icons.chevron_right, color: kMuted, size: 18),
                ]),
                const SizedBox(height: 8),
                Text(m.title, style: const TextStyle(color: kFg, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(m.summary,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 10),
                const Divider(color: kBorder),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.psychology, color: kPrimary, size: 14),
                    const SizedBox(width: 4),
                    Text('퀴즈 ${m.quizCount}문제', style: const TextStyle(color: kMuted, fontSize: 12)),
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
