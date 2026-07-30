import 'package:flutter/foundation.dart';

/// 앱 전체 라이트/다크 모드를 관리하는 전역 컨트롤러.
///
/// 별도 상태관리 패키지(Provider/Riverpod) 없이 ValueNotifier로 단순하게 구현.
/// main.dart의 AlarmStudyApp이 이 notifier를 ValueListenableBuilder로 구독해서
/// 값이 바뀔 때마다 MaterialApp 전체를 다시 그리고, app_theme.dart의 색상 getter들이
/// 그 시점의 모드에 맞는 값을 새로 반환한다.
class ThemeController {
  ThemeController._();

  /// true = 다크 모드(기본값), false = 라이트 모드
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);

  static void toggle() => isDark.value = !isDark.value;
}
