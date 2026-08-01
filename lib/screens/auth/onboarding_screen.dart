import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../../main.dart';

/// 회원가입 직후에만 보여주는 온보딩 3화면.
/// (기존 로그인 사용자는 이 화면을 거치지 않고 바로 MainShell로 이동함 — login_screen.dart 참고)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardData {
  final IconData icon;
  final Widget badge;
  final String title;
  final String description;

  const _OnboardData({
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static final _pages = <_OnboardData>[
    _OnboardData(
      icon: Icons.notifications,
      badge: _Badge(color: kBadgePurple, child: const Icon(Icons.check, size: 14, color: Colors.white)),
      title: '퀴즈를 풀어야\n알람이 꺼져요',
      description: '그냥 끄면 다시 울려요,\n작은 미션 하나로 완전히 잠을 깨워드려요',
    ),
    _OnboardData(
      icon: Icons.description_outlined,
      badge: _Badge(color: kBadgePurple, child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white)),
      title: 'PDF만 올리면\nAI가 퀴즈를 만들어요',
      description: '학습자료를 올리면 AI가 자동으로 요약하고\n맞춤 문제를 출제해줘요',
    ),
    _OnboardData(
      icon: Icons.local_fire_department,
      badge: _Badge(
        color: kBadgeOrange,
        child: const Text('7', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      title: '매일 아침\n스트릭을 쌓아보세요',
      description: '연속 기상 기록과 정답률로 성장을 확인하고\n뱃지를 모아보세요',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 건너뛰기 (마지막 페이지에서는 숨김)
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: isLast
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton(
                          onPressed: _finish,
                          child: Text('건너뛰기', style: TextStyle(color: kMuted, fontSize: 14)),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardPage(data: _pages[i]),
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? kPrimary : kBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(label: isLast ? '시작하기' : '다음', onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Badge({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: kBg, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final _OnboardData data;
  const _OnboardPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: kOnboardCard,
                  borderRadius: BorderRadius.circular(36),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 56, color: kPrimaryLight),
              ),
              Positioned(bottom: -4, right: -4, child: data.badge),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
