import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onTabChange;
  final List<AlarmModel> alarms;
  final List<StudyMaterial> materials;
  final Function(AlarmModel, StudyMaterial?) onDemoAlarm;

  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.alarms,
    required this.materials,
    required this.onDemoAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 인사
              const Text('좋은 아침이에요, 용욱님 ☀️',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('오늘의 학습 알람',
                  style: TextStyle(color: kFg, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 다음 알람 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('다음 알람까지',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        const Text('06 : 30',
                            style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('출근 준비 · 한국사 퀴즈',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _chip('5문제 필요'),
                            const SizedBox(width: 8),
                            _chip('월~금'),
                          ],
                        ),
                      ],
                    ),
                    const Positioned(
                      right: 0, top: 0,
                      child: Icon(Icons.alarm, size: 80, color: Colors.white24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 통계 3개
              Row(
                children: [
                  _statCard(Icons.alarm, '2개', '알람'),
                  const SizedBox(width: 12),
                  _statCard(Icons.menu_book, '2건', '학습 자료'),
                  const SizedBox(width: 12),
                  _statCard(Icons.bolt, '7일', '연속 정답'),
                ],
              ),
              const SizedBox(height: 20),

              // 빠른 메뉴
              _menuCard(Icons.alarm, '알람 관리', '2개의 알람이 설정됨', () => onTabChange(1)),
              const SizedBox(height: 12),
              _menuCard(Icons.psychology, '학습 자료 입력', 'AI가 자동으로 요약해드려요', () => onTabChange(2)),
              const SizedBox(height: 12),

              // 알람 울리는 중 데모
              GestureDetector(
                onTap: () => _showDemoPicker(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kRed.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kRed, borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('알람 울리는 중 (데모)',
                                style: TextStyle(color: kFg, fontWeight: FontWeight.bold)),
                            Text('알람을 선택해서 퀴즈를 체험해보세요',
                                style: TextStyle(color: kMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: kMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDemoPicker(BuildContext context) {
    if (alarms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정된 알람이 없습니다. 먼저 알람을 추가해주세요.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('데모할 알람 선택',
                style: TextStyle(color: kFg, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('해당 알람에 연결된 학습자료로 퀴즈가 실행됩니다',
                style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 16),
            ...alarms.map((alarm) {
              final material = _findMaterial(alarm);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onDemoAlarm(alarm, material);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.alarm, color: kRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(alarm.time,
                              style: const TextStyle(color: kFg, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Text(alarm.label,
                              style: const TextStyle(color: kMuted, fontSize: 13)),
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          material != null
                              ? '${material.subject} · ${material.title}'
                              : '퀴즈 없음',
                          style: TextStyle(
                            color: material != null ? kPrimaryLight : kMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                    const Icon(Icons.play_circle_outline, color: kRed, size: 22),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  StudyMaterial? _findMaterial(AlarmModel alarm) {
    if (alarm.materialId == null) return null;
    try {
      return materials.firstWhere((m) => m.id == alarm.materialId);
    } catch (_) {
      return null;
    }
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: kPrimary, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(IconData icon, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.2), borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: kFg, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: kMuted),
          ],
        ),
      ),
    );
  }
}