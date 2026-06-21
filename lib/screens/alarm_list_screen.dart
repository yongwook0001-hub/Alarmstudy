import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';

class AlarmListScreen extends StatefulWidget {
  final List<AlarmModel> alarms;
  final VoidCallback onAdd;
  const AlarmListScreen({super.key, required this.alarms, required this.onAdd});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  final _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('알람 목록'),
        actions: [
          GestureDetector(
            onTap: widget.onAdd,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.alarms.map((alarm) => _alarmCard(alarm)),
          const SizedBox(height: 12),
          // 새 알람 추가 점선 카드
          GestureDetector(
            onTap: widget.onAdd,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kMuted.withOpacity(0.4), style: BorderStyle.solid, width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: kMuted, size: 28),
                  SizedBox(height: 4),
                  Text('새 알람 추가', style: TextStyle(color: kMuted, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alarmCard(AlarmModel alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
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