import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final List<AlarmModel> alarms;
  final List<StudyMaterial> materials;
  final Function(AlarmModel, StudyMaterial?) onDemoAlarm;
  final String userName;
  final int streakDays;
  final int weeklyAccuracy;

  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.alarms,
    required this.materials,
    required this.onDemoAlarm,
    this.userName = '용욱',
    this.streakDays = 0,
    this.weeklyAccuracy = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _weekdayKr = ['월', '화', '수', '목', '금', '토', '일'];
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  AlarmModel? _nextAlarm;

  @override
  void initState() {
    super.initState();
    _recalculate();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recalculate());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _recalculate() {
    final result = _findNextAlarm();
    if (!mounted) return;
    setState(() {
      _nextAlarm = result?.$1;
      _remaining = result?.$2 ?? Duration.zero;
    });
  }

  (AlarmModel, Duration)? _findNextAlarm() {
    final now = DateTime.now();
    AlarmModel? best;
    DateTime? bestDt;

    for (final alarm in widget.alarms) {
      if (!alarm.active) continue;
      final parts = alarm.time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      // 오늘부터 최대 7일 안에서 이 알람이 다음으로 울릴 시점을 찾는다.
      for (int i = 0; i < 8; i++) {
        final candidateDate = now.add(Duration(days: i));
        final weekdayLabel = _weekdayKr[candidateDate.weekday - 1];
        if (alarm.days.isNotEmpty && !alarm.days.contains(weekdayLabel)) continue;

        final candidate = DateTime(
          candidateDate.year, candidateDate.month, candidateDate.day, hour, minute,
        );
        if (candidate.isBefore(now)) continue;

        if (bestDt == null || candidate.isBefore(bestDt)) {
          bestDt = candidate;
          best = alarm;
        }
        break;
      }
    }

    if (best == null || bestDt == null) return null;
    return (best, bestDt.difference(now));
  }

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.year}년 ${now.month}월 ${now.day}일 ${_weekdayKr[now.weekday - 1]}요일';
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  StudyMaterial? _materialFor(AlarmModel alarm) {
    if (alarm.materialId == null) return null;
    try {
      return widget.materials.firstWhere((m) => m.id == alarm.materialId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = _nextAlarm != null ? _materialFor(_nextAlarm!) : null;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 인사
              Text('좋은 아침이에요, ${widget.userName}님 👋',
                  style: const TextStyle(color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_todayLabel, style: const TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 20),

              // 다음 알람 카운트다운 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('다음 알람까지',
                            style: TextStyle(color: kMuted, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: _nextAlarm != null ? kPrimary : kMuted.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_nextAlarm != null ? 'ON' : 'OFF',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nextAlarm != null ? _fmt(_remaining) : '--:--:--',
                      style: const TextStyle(
                          color: kFg, fontSize: 44, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (_nextAlarm != null)
                      Row(
                        children: [
                          const Text('🔔 ', style: TextStyle(fontSize: 13)),
                          Text(_nextAlarm!.time,
                              style: const TextStyle(color: kMuted, fontSize: 13)),
                          const Text('  ·  ', style: TextStyle(color: kMuted, fontSize: 13)),
                          Expanded(
                            child: Text(
                              material != null ? '${material.subject} ${material.title}' : _nextAlarm!.label,
                              style: const TextStyle(color: kMuted, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('설정된 알람이 없어요', style: TextStyle(color: kMuted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 연속 기상 스트릭 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8D6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🔥', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${widget.streakDays}일 연속 기상 성공',
                              style: const TextStyle(
                                  color: kFg, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('이번 주 평균 정답률 ${widget.weeklyAccuracy}%',
                              style: const TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${widget.streakDays}',
                        style: const TextStyle(
                            color: kPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 최근 학습 자료
              const Text('최근 학습 자료',
                  style: TextStyle(color: kFg, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (widget.materials.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Text('아직 등록된 학습 자료가 없어요',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                )
              else
                ...widget.materials.take(4).map((m) => _materialRow(m)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _materialRow(StudyMaterial material) {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.description_outlined, color: kPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title,
                    style: const TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text('마지막 퀴즈: ${material.date}',
                    style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kMuted, size: 20),
        ],
      ),
    );
  }
}