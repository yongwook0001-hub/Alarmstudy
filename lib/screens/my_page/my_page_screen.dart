import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../services/auth_service.dart';
import '../../services/user_session.dart';
import '../auth/login_screen.dart';
import 'notification_settings_screen.dart';
import 'account_info_screen.dart';
import '../../widgets/section_title.dart';
import '../../widgets/settings_group.dart';

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
              // 상단 배너 — 로그인된 사용자가 있으면 그 이름/이메일, 없으면 목업 기본값
              ValueListenableBuilder(
                valueListenable: UserSession.current,
                builder: (context, user, _) {
                  final displayName = user?.nickname ?? userName;
                  final displayEmail = user?.email ?? userEmail;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
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
                        Text(displayName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(displayEmail,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      ],
                    ),
                  );
                },
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
                                      style: TextStyle(
                                          color: kFg, fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('연속 미라클 모닝',
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
                              child: Text('1주 달성!',
                                  style: TextStyle(
                                      color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    const SectionTitle('학습 설정'),
                    const SizedBox(height: 8),
                    SettingsGroup(items: [
                      _menuItem('알림 설정', onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                        );
                      }),
                      _menuItem(
                        '다크 모드',
                        onTap: ThemeController.toggle,
                        trailing: ValueListenableBuilder<bool>(
                          valueListenable: ThemeController.isDark,
                          builder: (context, isDark, _) => Switch(
                            value: isDark,
                            activeColor: kPrimary,
                            onChanged: (_) => ThemeController.toggle(),
                          ),
                        ),
                      ),
                      _menuItem('미션 유형 설정', onTap: () {}),
                    ]),
                    const SizedBox(height: 20),

                    const SectionTitle('계정'),
                    const SizedBox(height: 8),
                    SettingsGroup(items: [
                      _menuItem('계정 정보', onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
                        );
                      }),
                      _menuItem('로그아웃', onTap: () async {
                        // 저장된 access/refresh token 삭제 + 서버에도 로그아웃 통보
                        await AuthService.logout();
                        UserSession.clear();
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

  Widget _menuItem(String label, {Color? color, required VoidCallback onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: color ?? kFg, fontSize: 15)),
            const Spacer(),
            trailing ?? Icon(Icons.chevron_right, color: kMuted, size: 18),
          ],
        ),
      ),
    );
  }
}