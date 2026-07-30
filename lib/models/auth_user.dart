/// 로그인 성공 시 백엔드가 내려주는 사용자 정보.
///
/// 주의: 백엔드의 POST /api/auth/login 응답(UserOut)에는 provider가 안 들어있다
/// (팀원 쪽 스키마 확인 결과). 그래서 provider는 응답 JSON이 아니라 로그인을
/// 호출한 쪽(AuthService.signInWithGoogle/signInWithKakao)에서 직접 넘겨준다.
/// 반면 GET /api/users/me 응답(UserMeResponse)에는 provider가 포함되어 있다.
class AuthUser {
  final int id;
  final String provider; // 'google' | 'kakao'
  final String? email;
  final String nickname;
  final String? profileImageUrl;

  AuthUser({
    required this.id,
    required this.provider,
    required this.email,
    required this.nickname,
    required this.profileImageUrl,
  });

  /// POST /api/auth/login, /api/auth/refresh 등 응답용 — provider는 호출부에서 주입.
  factory AuthUser.fromLoginJson(Map<String, dynamic> json, {required String provider}) =>
      AuthUser(
        id: json['id'],
        provider: provider,
        email: json['email'],
        nickname: json['nickname'],
        profileImageUrl: json['profile_image_url'],
      );

  /// GET /api/users/me 응답용 — provider가 JSON 안에 이미 들어있음.
  factory AuthUser.fromMeJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'],
    provider: json['provider'],
    email: json['email'],
    nickname: json['nickname'],
    profileImageUrl: json['profile_image_url'],
  );
}