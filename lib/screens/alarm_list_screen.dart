import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';

class AlarmListScreen extends StatefulWidget {
  final List<AlarmModel> alarms;
  final List<StudyMaterial> materials;
  final VoidCallback onAdd;
  const AlarmListScreen({
    super.key,
    required this.alarms,
    required this.materials,
    required this.onAdd,
  });

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
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
    if (alarm.materialId == null) return '퀴즈 없음';
    try {
      final m = widget.materials.firstWhere((m) => m.id == alarm.materialId);
      return '${m.subject} ${m.title}';
    } catch (_) {
      return '학습자료 없음';
    }
  }

  Widget _alarmCard(AlarmModel alarm) {
    final isOn = alarm.active;
    final fg = isOn ? kFg : kMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
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
                onChanged: (v) => setState(() => alarm.active = v),
              ),
            ],
          ),
          Text(alarm.label, style: const TextStyle(color: kMuted, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: _days.map((d) {
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
          const Divider(color: kBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.psychology, color: kPrimary, size: 16),
                const SizedBox(width: 6),
                Text('퀴즈 과목: ', style: const TextStyle(color: kMuted, fontSize: 13)),
                Text(alarm.quizSubject, style: const TextStyle(color: kPrimaryLight, fontSize: 13)),
              ]),
              const Icon(Icons.delete_outline, color: kMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}