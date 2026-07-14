import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';
import 'alarm_ringing_screen.dart';

/// 가상 문제풀이 - 알람이 울리는 걸 기다리지 않고 학습자료를 골라 바로 퀴즈를 풀어보는 화면.
class PracticeQuizSelectScreen extends StatelessWidget {
  final List<StudyMaterial> materials;

  const PracticeQuizSelectScreen({super.key, required this.materials});

  void _start(BuildContext context, StudyMaterial material) {
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(
          alarm: AlarmModel(
            id: -1,
            time: time,
            label: '가상 문제풀이',
            active: true,
            days: const [],
            quizSubject: material.subject,
            materialId: material.id,
          ),
          material: material,
          practiceMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = materials.where((m) => m.quizQuestions.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kFg,
        title: const Text('가상 문제풀이', style: TextStyle(color: kFg, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: available.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '퀴즈가 있는 학습 자료가 없어요.\nAI학습 탭에서 PDF를 업로드해 보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, fontSize: 14),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: available.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = available[i];
                  return GestureDetector(
                    onTap: () => _start(context, m),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.quiz_outlined, color: kPrimary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.subject,
                                    style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(m.title,
                                    style: const TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('문제 ${m.quizQuestions.length}개',
                                    style: const TextStyle(color: kMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: kMuted, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
