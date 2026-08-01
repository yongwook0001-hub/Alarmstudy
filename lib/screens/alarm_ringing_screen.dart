import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';
import '../models/quiz_question.dart';
import '../models/quiz_answer_result.dart';
import 'motion_mission_screen.dart';
import 'today_report_screen.dart';

/// 알람이 울릴 때 표시되는 화면 (1단계: 울림, 2단계: 퀴즈).
/// 퀴즈를 다 풀면 정답률에 따라 동작미션(motion_mission_screen)을 거치거나
/// 바로 오늘의 리포트(today_report_screen)로 넘어간다.
class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;
  final StudyMaterial? material;
  final int streakDays; // 오늘의 리포트에 표시할 연속 기상 일수
  final bool practiceMode; // true면 알람 울림 단계 없이 바로 퀴즈로 시작 (가상 문제풀이용)

  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.material,
    this.streakDays = 0,
    this.practiceMode = false,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  bool _quizMode = false;
  List<QuizQuestion>? _questions;
  int _current = 0;
  int? _selected;
  bool _answered = false;
  final List<QuizAnswerResult> _results = [];
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (widget.practiceMode && widget.material != null && widget.material!.quizQuestions.isNotEmpty) {
      _questions = widget.material!.quizQuestions;
      _quizMode = true;
    }
  }

  void _startQuiz() {
    if (widget.material == null) {
      Navigator.pop(context);
      return;
    }
    final questions = widget.material!.quizQuestions;
    if (questions.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _questions = questions;
      _quizMode = true;
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    final q = _questions![_current];
    final isCorrect = index == q.correctIndex;

    // 실제 통계에 반영 - 오늘 만든 recordAnswer가 여기서 처음 실전 호출됨
    widget.material?.recordAnswer(isCorrect: isCorrect, topic: q.topic);

    _results.add(QuizAnswerResult(
      question: q.question,
      correctAnswerText: q.options[q.correctIndex],
      isCorrect: isCorrect,
    ));

    setState(() {
      _selected = index;
      _answered = true;
    });
  }

  void _proceed() {
    if (_current < _questions!.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
      return;
    }
    _finishQuiz();
  }

  void _finishQuiz() {
    _stopwatch.stop();
    final total = _results.length;
    final wrongCount = _results.where((r) => !r.isCorrect).length;
    // 절반 넘게 틀리면 동작미션 - 예: 3문제 중 2개 이상 오답
    final needsMission = wrongCount > total ~/ 2;

    if (needsMission) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MotionMissionScreen(
            wrongCount: wrongCount,
            onComplete: () => _goToReport(),
          ),
        ),
      );
    } else {
      _goToReport();
    }
  }

  void _goToReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayReportScreen(
          alarmTime: widget.alarm.time,
          elapsed: _stopwatch.elapsed,
          results: _results,
          streakDays: widget.streakDays,
          weakestTopic: widget.material?.weakestTopic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _quizMode ? _buildQuizView() : _buildRingingView();
  }

  // ── 1단계: 알람 울림 (전체 파란 화면) ──────────────────────
  Widget _buildRingingView() {
    return Scaffold(
      backgroundColor: kPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(widget.alarm.time,
                style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('일어날 시간이에요',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(flex: 1),
            Container(
              width: 180, height: 180,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('🔔', style: TextStyle(fontSize: 72)),
            ),
            const Spacer(flex: 1),
            GestureDetector(
              onTap: () => Navigator.pop(context), // 임시 스누즈 - 실제 재알림 스케줄링은 별도 구현 필요
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text('5분 후 다시 알림', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: widget.material != null ? _startQuiz : () => Navigator.pop(context),
                child: Container(
                  height: 56, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.material != null ? '문제 풀고 알람 끄기' : '알람 끄기',
                          style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (widget.material != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward, color: kPrimary, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2단계: 퀴즈 화면 ──────────────────────────────────────
  Widget _buildQuizView() {
    final q = _questions![_current];
    final total = _questions!.length;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: kFg),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('문제 ${_current + 1} / $total',
                      style: TextStyle(color: kFg, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 48), // 균형용 (X버튼과 대칭)
                ],
              ),
              Text(widget.material?.subject ?? widget.alarm.quizSubject,
                  style: TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_current + 1) / total,
                  backgroundColor: kBorder,
                  color: kPrimary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Text(q.question, style: TextStyle(color: kFg, fontSize: 17, height: 1.5)),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: List.generate(q.options.length, (i) {
                    final letter = String.fromCharCode(65 + i); // A, B, C, D

                    Color border = kBorder;
                    Color bg = kCard;
                    Color circleColor = kMuted;
                    Widget? trailing;

                    if (_answered) {
                      if (i == q.correctIndex) {
                        border = const Color(0xFF22C55E);
                        bg = const Color(0xFF22C55E).withOpacity(0.08);
                        circleColor = const Color(0xFF22C55E);
                        trailing = const Icon(Icons.check, color: Color(0xFF22C55E), size: 20);
                      } else if (i == _selected) {
                        border = kRed;
                        bg = kRed.withOpacity(0.06);
                        circleColor = kRed;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => _selectOption(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: circleColor.withOpacity(0.15),
                              child: Text(letter, style: TextStyle(color: circleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(q.options[i], style: TextStyle(color: kFg, fontSize: 15))),
                            if (trailing != null) trailing,
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              if (_answered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _selected == q.correctIndex ? '정답이에요! 바로 다음으로 넘어가요' : '오답이에요. 정답은 ${q.options[q.correctIndex]}입니다',
                    style: TextStyle(
                      color: _selected == q.correctIndex ? const Color(0xFF22C55E) : kRed,
                      fontSize: 13,
                    ),
                  ),
                ),

              GestureDetector(
                onTap: _answered ? _proceed : null,
                child: Container(
                  height: 52, width: double.infinity,
                  decoration: BoxDecoration(
                    color: _answered ? kPrimary : kBorder,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    !_answered
                        ? '정답 확인'
                        : (_current < total - 1 ? '다음 문제 →' : '결과 확인하기 →'),
                    style: TextStyle(
                      color: _answered ? Colors.white : kMuted,
                      fontWeight: FontWeight.bold, fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}