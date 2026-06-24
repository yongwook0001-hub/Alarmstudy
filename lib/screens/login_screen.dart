import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
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
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimary, kPrimaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.alarm, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('AI학습 알람',
                        style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('퀴즈로 알람을 끄는 스마트 학습',
                        style: TextStyle(color: kMuted, fontSize: 13)),
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
                icon: Icons.email_outlined,
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
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('비밀번호 찾기',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
              ),
              const SizedBox(height: 28),

              // 로그인 버튼
              GestureDetector(
                onTap: () {},
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('로그인',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                label: '카카오톡으로 로그인',
              ),
              const SizedBox(height: 12),

              // 구글 로그인
              _socialButton(
                bg: Colors.white,
                fgColor: const Color(0xFF1F1F1F),
                iconText: 'G',
                iconBg: const Color(0xFF4285F4),
                iconFg: Colors.white,
                label: 'Google로 로그인',
              ),
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
                            color: kPrimaryLight, fontSize: 14, fontWeight: FontWeight.bold)),
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
    IconData? icon,
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
          prefixIcon: icon != null ? Icon(icon, color: kMuted, size: 20) : null,
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
  }) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
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
