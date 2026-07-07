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
  bool _agreedToTerms = false;

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
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('회원가입', style: TextStyle(color: kFg)),
        iconTheme: const IconThemeData(color: kFg),
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
              const Text('회원가입',
                  style: TextStyle(color: kFg, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('계정을 만들고\n나만의 학습 알람을 설정해보세요',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 32),

              _label('이름'),
              const SizedBox(height: 8),
              _inputField(
                controller: _nameController,
                hint: '홍길동',
              ),
              const SizedBox(height: 16),

              _label('이메일'),
              const SizedBox(height: 8),
              _inputField(
                controller: _emailController,
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _label('비밀번호'),
              const SizedBox(height: 8),
              _inputField(
                controller: _pwController,
                hint: '8자 이상 입력',
                obscure: true,
              ),
              const SizedBox(height: 16),

              _label('비밀번호 확인'),
              const SizedBox(height: 8),
              _inputField(
                controller: _pwConfirmController,
                hint: '비밀번호 재입력',
                obscure: true,
              ),
              const SizedBox(height: 20),

              // 약관 동의 체크박스
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() => _agreedToTerms = value ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('이용약관 및 개인정보 처리방침에 동의합니다',
                        style: TextStyle(color: kFg, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 가입하기 버튼
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
                  child: const Text('가입하기',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),

              // 로그인 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('이미 계정이 있으신가요? ',
                      style: TextStyle(color: kMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('로그인',
                        style: TextStyle(color: kPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
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
}