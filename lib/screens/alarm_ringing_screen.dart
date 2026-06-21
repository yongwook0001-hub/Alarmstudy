import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';

class AlarmRingingScreen extends StatefulWidget {
  final AlarmModel alarm;
  const AlarmRingingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 벨 애니메이션
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

            // 퀴즈 안내
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
                  Text('${widget.alarm.quizSubject} 퀴즈 · 1/5문제',
                      style: const TextStyle(color: kMuted, fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // 퀴즈 풀고 알람 끄기 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {},
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
            const SizedBox(height: 16),
            const Text('5분 뒤 다시 알림', style: TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}