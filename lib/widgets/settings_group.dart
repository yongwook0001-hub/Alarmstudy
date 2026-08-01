import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 항목들을 구분선으로 나눠서 하나의 카드 안에 묶어 보여주는 공통 위젯.
/// my_page_screen(_settingsGroup), notification_settings_screen(_group),
/// account_info_screen(_infoGroup)에 완전히 동일한 코드로 3번 복붙돼 있던 걸 통합함
/// — 시각적으로 동일함 (kCard 배경 + kBorder 테두리, radius 16, 항목 사이 Divider).
class SettingsGroup extends StatelessWidget {
  final List<Widget> items;
  const SettingsGroup({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
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
              Divider(height: 1, color: kBorder, indent: 16, endIndent: 16),
          ],
        )),
      ),
    );
  }
}
