import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';

/// 로그인한 사용자 정보를 앱 전역에서 들고 있는 세션 저장소.
///
/// - 로그인 성공 시(login_screen.dart) [current]에 값을 채운다.
/// - 로그아웃 시(my_page_screen.dart) [current]를 null로 비운다.
/// - HomeScreen/MyPageScreen 등은 이 값을 구독해서 이름/이메일을 표시한다.
///   값이 없을 때(아직 로그인 안 한 상태 — 지금 앱은 홈 화면으로 바로 시작해서
///   실제로는 로그인 없이도 쓸 수 있음)는 기존 목업 이름을 그대로 보여준다.
///
/// TODO(실서버 연동): 지금은 로그인 응답(oauth 로그인 결과)만 반영한다.
/// 나중에 앱 시작 시 저장된 access_token으로 AuthService.getMe()를 호출해서
/// 앱을 새로 켰을 때도 로그인 상태/사용자 정보가 유지되도록 채워주면 된다.
class UserSession {
  UserSession._();

  static final ValueNotifier<AuthUser?> current = ValueNotifier<AuthUser?>(null);

  static void set(AuthUser user) => current.value = user;
  static void clear() => current.value = null;
}
