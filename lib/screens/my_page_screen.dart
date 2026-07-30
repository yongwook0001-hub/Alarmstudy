import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class MyPageScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final int streakDays;

  const MyPageScreen({
    super.key,
    this.userName = '진유하',
    this.userEmail = 'yuha@univ.ac.kr',
    this.streakDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 파란 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(userName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(userEmail,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 스트릭 카드 (배너와 살짝 겹치게 위로 올림)
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$streakDays일',
                                      style: const TextStyle(
                                          color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const Text('연속 미라클 모닝',
                                      style: TextStyle(color: kMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('1주 달성!',
                                  style: TextStyle(
                                      color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    _sectionTitle('학습 설정'),
                    const SizedBox(height: 8),
                    _settingsGroup([
                      _menuItem('알림 설정', onTap: () {}),
                      _menuItem('다크 모드', onTap: () {}),
                      _menuItem('미션 유형 설정', onTap: () {}),
                    ]),
                    const SizedBox(height: 20),

                    _sectionTitle('계정'),
                    const SizedBox(height: 8),
                    _settingsGroup([
                      _menuItem('계정 정보', onTap: () {}),
                      _menuItem('로그아웃', onTap: () async {
                        // 저장된 access/refresh token 삭제 + 서버에도 로그아웃 통보
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }),
                      _menuItem('회원 탈퇴', color: kRed, onTap: () {}),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold));
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

  Widget _menuItem(String label, {Color color = kFg, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: kMuted, size: 18),
          ],
        ),
      ),
    );
  }
}