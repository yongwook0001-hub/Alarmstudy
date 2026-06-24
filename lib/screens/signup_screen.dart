import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시작해볼까요? 👋',
                  style: TextStyle(color: kFg, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('정보를 입력하고 AI학습 알람을 시작하세요',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 32),

              _label('이름'),
              const SizedBox(height: 8),
              _inputField(
                controller: _nameController,
                hint: '홍길동',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              _label('이메일'),
              const SizedBox(height: 8),
              _inputField(
                controller: _emailController,
                hint: 'example@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _label('비밀번호'),
              const SizedBox(height: 8),
              _inputField(
                controller: _pwController,
                hint: '8자 이상 입력',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 16),

              _label('비밀번호 확인'),
              const SizedBox(height: 8),
              _inputField(
                controller: _pwConfirmController,
                hint: '비밀번호 재입력',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 32),

              // 회원가입 버튼
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
                  child: const Text('회원가입',
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

              _socialButton(
                bg: const Color(0xFFFEE500),
                fgColor: const Color(0xFF3C1E1E),
                iconText: 'K',
                iconBg: const Color(0xFF3C1E1E),
                iconFg: const Color(0xFFFEE500),
                label: '카카오톡으로 시작',
              ),
              const SizedBox(height: 12),
              _socialButton(
                bg: Colors.white,
                fgColor: const Color(0xFF1F1F1F),
                iconText: 'G',
                iconBg: const Color(0xFF4285F4),
                iconFg: Colors.white,
                label: 'Google로 시작',
              ),
              const SizedBox(height: 32),

              // 로그인 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('이미 계정이 있으신가요? ',
                      style: TextStyle(color: kMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('로그인',
                        style: TextStyle(color: kPrimaryLight, fontSize: 14, fontWeight: FontWeight.bold)),
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

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600));
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
