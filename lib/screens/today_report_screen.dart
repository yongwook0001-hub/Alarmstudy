import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/quiz_answer_result.dart';

class TodayReportScreen extends StatelessWidget {
  final String alarmTime;
  final Duration elapsed;
  final List<QuizAnswerResult> results;
  final int streakDays;
  final String? weakestTopic;

  const TodayReportScreen({
    super.key,
    required this.alarmTime,
    required this.elapsed,
    required this.results,
    required this.streakDays,
    this.weakestTopic,
  });

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.year}년 ${now.month}월 ${now.day}일';
  }

  String get _elapsedLabel {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    if (minutes == 0) return '$seconds초';
    return '$minutes분 $seconds초';
  }

  void _finish(BuildContext context) {
    // 알람 화면 스택(퀴즈/미션/리포트)을 전부 걷어내고 홈으로 복귀
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final total = results.length;
    final correct = results.where((r) => r.isCorrect).length;
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('오늘의 리포트',
                  style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$_todayLabel · $alarmTime에 기상 완료',
                  style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 20),

              // 축하 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('오늘도 미라클모닝 성공!',
                              style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('$streakDays일 연속 기상 중이에요',
                              style: TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('$streakDays',
                        style: TextStyle(color: kPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('오늘의 기록', style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(children: [
                  _recordRow('알람을 끈 시간', alarmTime),
                  _recordRow('걸린 시간', _elapsedLabel),
                  _recordRow('푼 문제', '$total개'),
                  _recordRow('정답률', '$accuracy%', isLast: true),
                ]),
              ),
              const SizedBox(height: 24),

              Text('문제 리뷰', style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...results.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.value.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: e.value.isCorrect ? const Color(0xFF22C55E) : kRed,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key + 1}. ${e.value.question}',
                              style: TextStyle(color: kFg, fontSize: 14)),
                          if (!e.value.isCorrect) ...[
                            const SizedBox(height: 4),
                            Text('정답: ${e.value.correctAnswerText}',
                                style: TextStyle(color: kRed, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),

              if (weakestTopic != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, color: kAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$weakestTopic 파트가 약해요. 다음 알람에서 더 물어볼게요.',
                          style: TextStyle(color: kMuted, fontSize: 13, height: 1.5)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 28),

              GestureDetector(
                onTap: () => _finish(context),
                child: Container(
                  height: 56, width: double.infinity,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text('확인',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kMuted, fontSize: 14)),
          Text(value, style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}