import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';
import '../models/quiz_question.dart';

/// 알람이 울릴 때 표시되는 화면.
///
/// [전체 흐름]
///   1. 알람 울리는 뷰 표시 → "퀴즈 풀고 알람 끄기" 버튼 탭
///   2. Gemini가 연결된 학습자료(material)로 퀴즈 5문제 실시간 생성
///   3. 퀴즈 뷰로 전환 → 문제를 하나씩 풀기
///   4. 결과 뷰: 60% 이상 맞추면 알람 해제, 미달이면 다시 풀기
///
/// [material이 null인 경우]
///   해당 알람 과목의 학습자료가 없으므로 퀴즈 없이 바로 끄기 가능
class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;
  final StudyMaterial? material; // 연결된 학습자료 (없으면 퀴즈 없이 끄기 가능)

  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.material,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  // 퀴즈 상태
  List<QuizQuestion>? _questions;
  String? _error;
  bool _quizMode = false; // 퀴즈 화면으로 전환됐는지

  int _current = 0;      // 현재 문제 인덱스
  int? _selected;        // 선택한 보기
  bool _answered = false; // 이번 문제 답했는지
  int _correctCount = 0;
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[now.weekday - 1];
    return '${wd}요일, ${now.year}년 ${now.month}월 ${now.day}일';
  }

  /// 업로드 시 미리 생성된 퀴즈를 바로 사용 — API 추가 호출 없음
  void _startQuiz() {
    if (widget.material == null) {
      Navigator.pop(context);
      return;
    }

    final questions = widget.material!.quizQuestions;
    if (questions.isEmpty) {
      setState(() => _error = '저장된 퀴즈가 없어요. 학습자료를 다시 업로드해주세요.');
      return;
    }

    setState(() {
      _questions = questions;
      _quizMode = true;
      _current = 0;
      _selected = null;
      _answered = false;
      _correctCount = 0;
      _allDone = false;
      _error = null;
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
      if (index == _questions![_current].correctIndex) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_current < _questions!.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    } else {
      setState(() => _allDone = true);
    }
  }

  void _dismissAlarm() {
    Navigator.pop(context);
  }

  // ── 알람 울리는 화면 ──────────────────────────────────────
  Widget _buildRingingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              color: kRed.withOpacity(0.2), shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
              child: const Icon(Icons.notifications, color: Colors.white, size: 48),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(widget.alarm.time,
            style: const TextStyle(color: kFg, fontSize: 56, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.alarm.label,
            style: const TextStyle(color: kMuted, fontSize: 16)),
        Text(_today(), style: const TextStyle(color: kMuted, fontSize: 14)),
        const SizedBox(height: 32),

        if (widget.material != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kRed.withOpacity(0.4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.psychology, color: kRed, size: 16),
                  SizedBox(width: 6),
                  Text('알람을 끄려면 퀴즈를 풀어야 해요!',
                      style: TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Text('${widget.alarm.quizSubject} 퀴즈 · 5문제',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _startQuiz,
              child: Container(
                height: 56, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kRed, kAccent]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('퀴즈 풀고 알람 끄기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
            ),
          ],
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _dismissAlarm,
              child: Container(
                height: 56, width: double.infinity,
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                alignment: Alignment.center,
                child: const Text('알람 끄기',
                    style: TextStyle(color: kFg, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('5분 뒤 다시 알림', style: TextStyle(color: kMuted, fontSize: 13)),
      ],
    );
  }

  // ── 퀴즈 진행 화면 ───────────────────────────────────────
  Widget _buildQuizView() {
    if (_allDone) return _buildResultView();

    final q = _questions![_current];
    final total = _questions!.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 진행바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${widget.alarm.quizSubject} 퀴즈',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
              Text('${_current + 1} / $total',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
            ]),
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
          ]),
        ),
        const SizedBox(height: 32),

        // 문제
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Text(q.question,
                style: const TextStyle(color: kFg, fontSize: 16, height: 1.6)),
          ),
        ),
        const SizedBox(height: 20),

        // 보기
        ...List.generate(q.options.length, (i) {
          Color borderColor = kBorder;
          Color bgColor = kCard;
          Color textColor = kFg;

          if (_answered) {
            if (i == q.correctIndex) {
              borderColor = kPrimary;
              bgColor = kPrimary.withOpacity(0.15);
              textColor = kPrimaryLight;
            } else if (i == _selected && i != q.correctIndex) {
              borderColor = kRed;
              bgColor = kRed.withOpacity(0.1);
              textColor = kRed;
            }
          } else if (_selected == i) {
            borderColor = kPrimary;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: GestureDetector(
              onTap: () => _selectOption(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: borderColor.withOpacity(0.2),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(q.options[i],
                        style: TextStyle(color: textColor, fontSize: 14)),
                  ),
                  if (_answered && i == q.correctIndex)
                    const Icon(Icons.check_circle, color: kPrimary, size: 20),
                  if (_answered && i == _selected && i != q.correctIndex)
                    const Icon(Icons.cancel, color: kRed, size: 20),
                ]),
              ),
            ),
          );
        }),

        if (_answered) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _nextQuestion,
              child: Container(
                height: 52, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _current < _questions!.length - 1 ? '다음 문제' : '결과 보기',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── 결과 화면 ─────────────────────────────────────────────
  Widget _buildResultView() {
    final total = _questions!.length;
    final passed = _correctCount >= (total * 0.6).ceil(); // 60% 이상 맞추면 알람 해제

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: (passed ? kPrimary : kRed).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            passed ? Icons.check_circle : Icons.refresh,
            color: passed ? kPrimary : kRed,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          passed ? '알람 해제 완료!' : '다시 도전해보세요',
          style: TextStyle(
            color: passed ? kPrimary : kRed,
            fontSize: 26, fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$total문제 중 $_correctCount문제 정답',
          style: const TextStyle(color: kMuted, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          passed ? '잘 하셨어요! 오늘도 공부 화이팅!' : '60% 이상 맞춰야 알람이 꺼져요',
          style: const TextStyle(color: kMuted, fontSize: 13),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: passed
              ? GestureDetector(
                  onTap: _dismissAlarm,
                  child: Container(
                    height: 56, width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('알람 끄기',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              : GestureDetector(
                  onTap: _startQuiz,
                  child: Container(
                    height: 56, width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kRed, kAccent]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('다시 풀기',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: _quizMode ? _buildQuizView() : _buildRingingView(),
        ),
      ),
    );
  }
}
