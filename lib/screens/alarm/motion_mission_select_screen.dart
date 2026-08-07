import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'motion_mission_screen.dart';

/// 동작 미션 진입 전: 스쿼트 / 눈 깜빡임 중 하나를 고른다.
class MotionMissionSelectScreen extends StatelessWidget {
  final int wrongCount;
  final VoidCallback onComplete;

  const MotionMissionSelectScreen({
    super.key,
    required this.wrongCount,
    required this.onComplete,
  });

  void _start(BuildContext context, MotionMissionType type) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MotionMissionScreen(
          wrongCount: wrongCount,
          missionType: type,
          onComplete: onComplete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$wrongCount문제를 틀렸어요',
                  style: TextStyle(color: kFg, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('알람을 끄려면 동작 미션을 완료해야 해요.\n원하는 미션을 선택해 주세요.',
                  style: TextStyle(color: kMuted, fontSize: 14, height: 1.4)),
              const SizedBox(height: 28),
              _MissionCard(
                icon: Icons.fitness_center,
                title: '스쿼트',
                subtitle: '${MotionMissionScreen.requiredSquats}회 완료하면 알람 해제',
                onTap: () => _start(context, MotionMissionType.squat),
              ),
              const SizedBox(height: 12),
              _MissionCard(
                icon: Icons.remove_red_eye_outlined,
                title: '눈 깜빡임',
                subtitle: '${MotionMissionScreen.requiredBlinks}회 완료하면 알람 해제',
                onTap: () => _start(context, MotionMissionType.blink),
              ),
              const Spacer(),
              Text('선택한 미션만 카운트됩니다.',
                  style: TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(color: kFg, fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: kMuted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}
