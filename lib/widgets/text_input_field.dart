import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 로그인/회원가입 화면에서 쓰이는 공통 텍스트 입력 필드.
/// login_screen.dart와 signup_screen.dart에 완전히 동일한 코드로 복붙돼 있던
/// _inputField() 헬퍼를 하나로 모은 것 — 시각적으로 동일함.
class TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;

  const TextInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
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
        style: TextStyle(color: kFg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: kMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
