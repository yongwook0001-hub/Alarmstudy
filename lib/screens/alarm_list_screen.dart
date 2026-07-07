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
                      const Text('알람설정',
                          style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('예정된 알람 $activeCount개',
                          style: const TextStyle(color: kMuted, fontSize: 13)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alarm.time,
                    style: TextStyle(color: fg, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(_quizLabel(alarm),
                    style: TextStyle(color: fg.withOpacity(isOn ? 1 : 0.7), fontSize: 13)),
                const SizedBox(height: 4),
                Text(alarm.days.join(' '),
                    style: TextStyle(color: kMuted.withOpacity(isOn ? 1 : 0.6), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: alarm.active,
            activeColor: kPrimary,
            onChanged: (v) => setState(() => alarm.active = v),
          ),
        ],
      ),
    );
  }
}