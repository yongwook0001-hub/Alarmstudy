import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 설정류 화면(마이페이지/알림 설정 등)에서 반복되던 섹션 제목 텍스트.
/// my_page_screen.dart와 notification_settings_screen.dart에 각각
/// 똑같이 복붙돼 있던 _sectionTitle() 헬퍼를 하나로 모은 것 — 시각적으로 동일함.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.bold));
  }
}
