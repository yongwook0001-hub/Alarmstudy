import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

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
              const Text('마이페이지',
                  style: TextStyle(color: kFg, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: kPrimary.withOpacity(0.3),
                      child: const Text('용',
                          style: TextStyle(color: kPrimaryLight, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('용욱님',
                              style: TextStyle(color: kFg, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('yongwook0001@gmail.com',
                              style: TextStyle(color: kMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('7일 연속 학습 중 🔥',
                                style: TextStyle(color: kPrimaryLight, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _statCard('32', '총 학습일'),
                  const SizedBox(width: 12),
                  _statCard('158', '총 퀴즈'),
                  const SizedBox(width: 12),
                  _statCard('94%', '정답률'),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('학습 설정'),
              const SizedBox(height: 8),
              _settingsGroup([
                _menuItem(Icons.notifications_outlined, '알림 설정'),
                _menuItem(Icons.timer_outlined, '퀴즈 시간 제한'),
                _menuItem(Icons.bar_chart_outlined, '학습 통계'),
              ]),
              const SizedBox(height: 16),

              _sectionTitle('앱 설정'),
              const SizedBox(height: 8),
              _settingsGroup([
                _menuItem(Icons.palette_outlined, '테마'),
                _menuItem(Icons.language_outlined, '언어'),
                _menuItem(Icons.help_outline, '도움말'),
                _menuItem(Icons.info_outline, '앱 정보'),
              ]),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kRed.withOpacity(0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('로그아웃',
                      style: TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.bold));
  }

  Widget _settingsGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: List.generate(items.length, (i) => Column(
          children: [
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, color: kBorder, indent: 16, endIndent: 16),
          ],
        )),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: kPrimary, size: 20),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: kFg, fontSize: 14)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: kMuted, size: 18),
        ],
      ),
    );
  }
}
