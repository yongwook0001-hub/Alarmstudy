import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

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
                onTap: () => onTabChange(5),
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
                            Text('퀴즈를 풀어야 알람이 꺼집니다',
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