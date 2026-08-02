import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/alarm_model.dart';
import '../../models/material_set.dart';

class AlarmListScreen extends StatefulWidget {
  final List<AlarmModel> alarms;
  final List<MaterialSet> sets;
  final VoidCallback onAdd;
  final Future<void> Function(AlarmModel alarm)? onToggle;
  final Future<void> Function(AlarmModel alarm)? onDelete;
  const AlarmListScreen({
    super.key,
    required this.alarms,
    required this.sets,
    required this.onAdd,
    this.onToggle,
    this.onDelete,
  });

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  // 요일 원형 표시용 - 실제 반복요일(alarm.days)과 무관하게 항상 일~토 순서로 그린다.
  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.alarms.where((a) => a.active).length;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // 커스텀 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('알람설정',
                          style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('예정된 알람 $activeCount개',
                          style: TextStyle(color: kMuted, fontSize: 13)),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('알람 추가',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: widget.alarms.map((alarm) => _alarmCard(alarm)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _quizLabel(AlarmModel alarm) {
    if (alarm.setId == null) return '퀴즈 없음';
    try {
      final s = widget.sets.firstWhere((s) => s.id == alarm.setId);
      return s.title;
    } catch (_) {
      return '학습자료 없음';
    }
  }

  Future<void> _confirmDelete(AlarmModel alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('알람을 삭제할까요?', style: TextStyle(color: kFg)),
        content: Text('"${alarm.label}" (${alarm.time}) 알람을 삭제합니다.', style: TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.onDelete?.call(alarm);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Widget _alarmCard(AlarmModel alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Text(
                alarm.time,
                style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold,
                  color: alarm.active ? kFg : kMuted,
                ),
              ),
              Switch(
                value: alarm.active,
                activeColor: kPrimary,
                onChanged: (v) async {
                  setState(() => alarm.active = v);
                  try {
                    await widget.onToggle?.call(alarm);
                  } catch (e) {
                    if (mounted) {
                      setState(() => alarm.active = !v); // 실패하면 되돌림
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
                    }
                  }
                },
              ),
            ],
          ),
          Text(alarm.label, style: TextStyle(color: kMuted, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: _weekdays.map((d) {
              final isOn = alarm.days.contains(d);
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isOn ? kPrimary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: isOn ? kPrimary : kMuted.withOpacity(0.4)),
                ),
                alignment: Alignment.center,
                child: Text(d, style: TextStyle(
                  color: isOn ? Colors.white : kMuted, fontSize: 11,
                )),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Divider(color: kBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.psychology, color: kPrimary, size: 16),
                const SizedBox(width: 6),
                Text('퀴즈 과목: ', style: TextStyle(color: kMuted, fontSize: 13)),
                Text(_quizLabel(alarm), style: TextStyle(color: kPrimaryLight, fontSize: 13)),
              ]),
              GestureDetector(
                onTap: () => _confirmDelete(alarm),
                child: Icon(Icons.delete_outline, color: kMuted, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
