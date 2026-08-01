import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 화면 너비를 꽉 채우는 둥근 CTA 버튼 - alarm_add/login/signup/onboarding/
/// motion_mission/today_report 화면에 거의 동일한 형태로 복붙돼 있던 것을 통합.
///
/// 각 화면에서 쓰던 값(height/backgroundColor/textColor 등) 그대로 파라미터
/// 기본값을 맞춰서, 적용해도 시각적으로 달라지지 않도록 했다.
/// (kPrimary/kBorder/kMuted 등은 const가 아닌 getter라 기본값으로 못 써서
/// backgroundColor/textColor는 nullable로 두고 build()에서 ?? 로 채움)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final double fontSize;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.borderRadius = 16,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor ?? kPrimary,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
