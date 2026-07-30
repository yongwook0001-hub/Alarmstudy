import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();

  // 로그인 요청 진행 중이면 버튼 중복 탭 방지 + 로딩 표시용
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  // 구글/카카오 공통 처리: AuthService 호출 → 성공하면 메인 화면으로 이동,
  // 실패하면 화면 아래 SnackBar로 에러 메시지 표시.
  Future<void> _handleSocialLogin(Future<dynamic> Function() signIn) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await signIn();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // 로고
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: kLogoBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('S.O.S',
                        style: TextStyle(
                            color: kFg, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('SOLVE TO STOP',
                        style: TextStyle(
                            color: kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // 이메일
              const Text('이메일',
                  style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _inputField(
                controller: _emailController,
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // 비밀번호
              const Text('비밀번호',
                  style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _inputField(
                controller: _pwController,
                hint: '비밀번호를 입력하세요',
                obscure: true,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('비밀번호를 잊으셨나요?',
                    style: TextStyle(color: kMuted, fontSize: 13)),
              ),
              const SizedBox(height: 28),

              // 로그인 버튼 (단색)
              GestureDetector(
                onTap: () {},
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('로그인',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              const Row(children: [
                Expanded(child: Divider(color: kBorder)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('또는', style: TextStyle(color: kMuted, fontSize: 13)),
                ),
                Expanded(child: Divider(color: kBorder)),
              ]),
              const SizedBox(height: 24),

              // 카카오 로그인
              _socialButton(
                bg: const Color(0xFFFEE500),
                fgColor: const Color(0xFF3C1E1E),
                iconText: 'K',
                iconBg: const Color(0xFF3C1E1E),
                iconFg: const Color(0xFFFEE500),
                label: '카카오로 계속하기',
                onTap: () => _handleSocialLogin(AuthService.signInWithKakao),
              ),
              const SizedBox(height: 12),

              // 구글 로그인 (테두리 추가 - 흰 배경 위 흰 버튼이라 구분 필요)
              _socialButton(
                bg: Colors.white,
                fgColor: const Color(0xFF1F1F1F),
                iconText: 'G',
                iconBg: const Color(0xFF4285F4),
                iconFg: Colors.white,
                label: 'Google로 계속하기',
                border: kBorder,
                onTap: () => _handleSocialLogin(AuthService.signInWithGoogle),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 40),

              // 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('계정이 없으신가요? ',
                      style: TextStyle(color: kMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text('회원가입',
                        style: TextStyle(
                            color: kPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: kFg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _socialButton({
    required Color bg,
    required Color fgColor,
    required String iconText,
    required Color iconBg,
    required Color iconFg,
    required String label,
    required VoidCallback onTap,
    Color? border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(iconText,
                  style: TextStyle(color: iconFg, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(color: fgColor, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}