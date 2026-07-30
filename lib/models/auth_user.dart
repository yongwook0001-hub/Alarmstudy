/// 로그인 성공 시 백엔드가 내려주는 사용자 정보.
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

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'],
    provider: json['provider'],
    email: json['email'],
    nickname: json['nickname'],
    profileImageUrl: json['profile_image_url'],
  );
}