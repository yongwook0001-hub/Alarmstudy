import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/study_material.dart';

class AiSummaryScreen extends StatelessWidget {
  final StudyMaterial material;
  const AiSummaryScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 과목 태그
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(material.subject, style: const TextStyle(color: kPrimaryLight, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            Text(material.title,
                style: const TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // AI 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.auto_awesome, color: kPrimary, size: 16),
                SizedBox(width: 8),
                Text('AI가 핵심 내용을 자동 요약했습니다', style: TextStyle(color: kPrimaryLight, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 16),

            // 요약
            _card(
              title: '요약',
              child: Text(material.summary,
                  style: const TextStyle(color: kFg, fontSize: 14, height: 1.7)),
            ),
            const SizedBox(height: 12),

            // 핵심 포인트
            _card(
              title: '핵심 포인트',
              child: Column(
                children: material.keyPoints.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('${e.key + 1}',
                          style: const TextStyle(color: kPrimaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Text(e.value, style: const TextStyle(color: kFg, fontSize: 14)),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // 알람 퀴즈
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kAccent.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.psychology, color: kAccent, size: 16),
                  SizedBox(width: 6),
                  Text('알람 퀴즈', style: TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Text('이 자료를 기반으로 ${material.quizCount}개의 퀴즈가 생성되어 알람 해제에 사용됩니다.',
                    style: const TextStyle(color: kMuted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: kAccent, borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('미리 풀어보기 →',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}