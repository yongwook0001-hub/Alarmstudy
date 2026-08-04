import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/alarm_model.dart';
import '../../models/material_set.dart';
import '../../models/quiz_session.dart';
import '../../models/quiz_answer_result.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/sessions_service.dart';
import '../../services/api_client.dart';
import 'motion_mission_screen.dart';
import 'today_report_screen.dart';

enum _Phase { ringing, loadingQuiz, quiz, quizError }

/// 알람이 울릴 때 표시되는 화면 (1단계: 울림, 2단계: 퀴즈).
///
/// 퀴즈 문제는 이제 로컬에 미리 들고 있던 게 아니라 알람이 울리는 시점에 서버
/// (POST /api/sessions)에서 받아온다. 서버는 정답이 빠진 문제만 내려주고, 한 문제씩
/// 제출해야(POST .../attempts) 정답 여부/정답/해설을 알려준다. 세션에 내려온 문제를
/// 전부 맞혀야만 dismiss_method="quiz"로 바로 해제되고(POST .../dismiss, 하나라도 틀리면
/// 서버가 409 QUIZ_NOT_COMPLETED로 거부 - server/app/api/sessions.py 설계), 하나라도
/// 틀리면 앱은 quiz dismiss를 시도하지 않고 곧장 동작 미션 화면으로 보내 미션 완료 후
/// dismiss_method="mission"으로 해제한다.
class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;
  final MaterialSet? set;
  final int? streakDays; // 오늘의 리포트에 표시할 연속 기상 일수. null = 서버 조회 실패
  final bool practiceMode; // true면 알람 울림 단계 없이 바로 퀴즈로 시작 (가상 문제풀이용)

  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.set,
    this.streakDays,
    this.practiceMode = false,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  _Phase _phase = _Phase.ringing;
  QuizSession? _session;
  int _current = 0;
  int? _selected;
  bool _answered = false;
  AttemptResult? _lastResult;
  String? _quizError;

  final List<QuizAnswerResult> _results = [];
  final Map<String, int> _wrongTopicTally = {};
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (widget.practiceMode && widget.set != null) {
      _startQuiz();
    }
  }

  /// 실제로 울리던 네이티브 알람 소리를 멈추고, 반복 요일이 있으면 다음 회차를 재예약한다.
  /// (practiceMode - 홈 화면 데모 버튼으로 들어온 가상 풀이 - 에서는 실제 알람이 울리고
  /// 있는 게 아니므로 아무것도 하지 않음)
  Future<void> _stopAndReschedule() async {
    if (widget.practiceMode) return;
    await Alarm.stop(widget.alarm.id);
    await AlarmScheduler.schedule(widget.alarm);
  }

  void _stopAlarmAndClose() {
    _stopAndReschedule();
    Navigator.pop(context);
  }

  Future<void> _snooze() async {
    if (!widget.practiceMode) {
      await Alarm.stop(widget.alarm.id);
      await AlarmScheduler.snooze(widget.alarm);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startQuiz() async {
    if (widget.set == null) {
      if (!widget.practiceMode) _stopAlarmAndClose();
      return;
    }
    setState(() {
      _phase = _Phase.loadingQuiz;
      _quizError = null;
    });
    try {
      final session = await SessionsService.start(widget.alarm.id);
      if (!mounted) return;
      setState(() {
        _session = session;
        _current = 0;
        _selected = null;
        _answered = false;
        _lastResult = null;
        _phase = _Phase.quiz;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.errorCode == 'NO_QUESTIONS_AVAILABLE') {
        // 아직 AI가 문제를 하나도 못 만들어둔 상태 - 퀴즈 없이 그냥 끄기로 대체.
        if (widget.practiceMode) {
          Navigator.pop(context);
        } else {
          _stopAlarmAndClose();
        }
        return;
      }
      setState(() {
        _quizError = e.toString().replaceAll('Exception: ', '');
        _phase = _Phase.quizError;
      });
    }
  }

  Future<void> _selectOption(int index) async {
    if (_answered || _session == null) return;
    final q = _session!.questions[_current];

    setState(() => _selected = index); // 채점 대기 중임을 바로 보여줌 (버튼은 아래서 잠금)

    try {
      final result = await SessionsService.submitAttempt(
        sessionId: _session!.sessionId,
        questionId: q.questionId,
        source: q.source,
        selectedAnswer: index,
        timeTakenSeconds: _stopwatch.elapsed.inSeconds,
      );

      if (!result.isCorrect) {
        _wrongTopicTally[q.topic] = (_wrongTopicTally[q.topic] ?? 0) + 1;
      }
      _results.add(QuizAnswerResult(
        question: q.content,
        correctAnswerText: q.choices[result.correctAnswer],
        isCorrect: result.isCorrect,
      ));

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _answered = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _selected = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채점 실패: $e')),
      );
    }
  }

  void _proceed() {
    if (_current < _session!.questions.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
        _lastResult = null;
      });
      return;
    }
    _finishRound();
  }

  /// 한 라운드(현재 세션의 문제들)를 다 풀고 난 뒤 통과 여부를 이 앱이 직접 판정한다.
  /// 세션에 내려온 문제를 전부 맞혀야만(서버 required_count 전량 충족) 'quiz' 방식으로
  /// 바로 해제한다. 하나라도 틀리면 예외 없이 실제 동작 미션 화면으로 보내고, 미션을
  /// 완료해야만 'mission' 방식으로 해제한다 (server/app/api/sessions.py 주석
  /// "모션 판정은 앱 로컬 책임" 참고 - quiz 미달 상태로는 quiz dismiss를 아예 시도하지 않는다).
  void _finishRound() {
    final total = _session!.questions.length;
    final correctCount = _results.where((r) => r.isCorrect).length;
    final allCorrect = total > 0 && correctCount == total;

    if (allCorrect) {
      _dismissAndFinish(dismissMethod: 'quiz');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MotionMissionScreen(
            wrongCount: total - correctCount,
            onComplete: () => _dismissAndFinish(dismissMethod: 'mission'),
          ),
        ),
      );
    }
  }

  Future<void> _dismissAndFinish({required String dismissMethod}) async {
    try {
      await SessionsService.dismiss(_session!.sessionId, dismissMethod: dismissMethod);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('알람 해제 실패: $e')));
      }
      return;
    }
    _finishQuiz();
  }

  void _finishQuiz() {
    _stopAndReschedule(); // 알람 해제가 실제로 승인됐으니 알람 소리 정지 + 다음 회차 예약
    _stopwatch.stop();
    _goToReport();
  }

  String? get _weakestTopic {
    if (_wrongTopicTally.isEmpty) return null;
    return _wrongTopicTally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _goToReport() {
    if (widget.practiceMode) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayReportScreen(
          alarmTime: widget.alarm.time,
          elapsed: _stopwatch.elapsed,
          results: _results,
          streakDays: widget.streakDays,
          weakestTopic: _weakestTopic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.ringing:
        return _buildRingingView();
      case _Phase.loadingQuiz:
        return _buildLoadingView();
      case _Phase.quiz:
        return _buildQuizView();
      case _Phase.quizError:
        return _buildErrorView();
    }
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
              onTap: _snooze,
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
                onTap: widget.set != null ? _startQuiz : _stopAlarmAndClose,
                child: Container(
                  height: 56, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.set != null ? '문제 풀고 알람 끄기' : '알람 끄기',
                          style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (widget.set != null) ...[
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

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('문제를 불러오고 있어요...', style: TextStyle(color: kMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('문제를 불러오지 못했어요.\n$_quizError',
                  textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _startQuiz,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(14)),
                  child: Text('다시 시도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.practiceMode ? () => Navigator.pop(context) : _stopAlarmAndClose,
                child: Text('그냥 끄기', style: TextStyle(color: kMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2단계: 퀴즈 화면 ──────────────────────────────────────
  Widget _buildQuizView() {
    final q = _session!.questions[_current];
    final total = _session!.questions.length;

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
                    onPressed: widget.practiceMode ? () => Navigator.pop(context) : _stopAlarmAndClose,
                  ),
                  Text('문제 ${_current + 1} / $total',
                      style: TextStyle(color: kFg, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 48), // 균형용 (X버튼과 대칭)
                ],
              ),
              Text(q.topic,
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
                child: Text(q.content, style: TextStyle(color: kFg, fontSize: 17, height: 1.5)),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: List.generate(q.choices.length, (i) {
                    final letter = String.fromCharCode(65 + i); // A, B, C, D

                    Color border = kBorder;
                    Color bg = kCard;
                    Color circleColor = kMuted;
                    Widget? trailing;

                    if (_answered && _lastResult != null) {
                      if (i == _lastResult!.correctAnswer) {
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
                            Expanded(child: Text(q.choices[i], style: TextStyle(color: kFg, fontSize: 15))),
                            if (trailing != null) trailing,
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              if (_answered && _lastResult != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _lastResult!.isCorrect
                        ? '정답이에요! 바로 다음으로 넘어가요'
                        : '오답이에요. 정답은 ${q.choices[_lastResult!.correctAnswer]}입니다'
                            '${_lastResult!.explanation != null ? '\n${_lastResult!.explanation}' : ''}',
                    style: TextStyle(
                      color: _lastResult!.isCorrect ? const Color(0xFF22C55E) : kRed,
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
                        ? (_selected != null ? '채점 중...' : '보기를 선택하세요')
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
