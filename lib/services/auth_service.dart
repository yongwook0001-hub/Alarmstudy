import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../models/auth_user.dart';

/// 구글/카카오 로그인 + 백엔드 인증(JWT) 담당 서비스.
///
/// 백엔드는 팀원이 만든 app/api/auth.py 기준 (server/app/api/auth.py 참고):
///   POST /api/auth/login   {provider, oauth_token, device_info?} → {access_token, refresh_token, user, is_new_user}
///   POST /api/auth/refresh {refresh_token} → {access_token}  (refresh_token은 새로 안 내려줌 — 기존 걸 계속 씀)
///   POST /api/auth/logout  {refresh_token} + Authorization: Bearer <access_token> 필요
///   GET  /api/users/me     + Authorization: Bearer <access_token> 필요
/// 에러 응답 형식은 {"error_code": "...", "message": "..."} (팀원 쪽 AppError 규약).
class AuthService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  // ── 구글 로그인 ──────────────────────────────────────────────
  // GoogleSignIn 7.x부터는 GoogleSignIn.instance 싱글턴 + initialize() 필요.
  // serverClientId는 "웹 클라이언트 ID"여야 idToken이 채워진다 (안드로이드 클라이언트 ID 아님).
  static Future<AuthUser> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );

    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('구글 ID 토큰을 받아오지 못했습니다. serverClientId 설정을 확인하세요.');
    }

    return _login(provider: 'google', oauthToken: idToken);
  }

  // ── 카카오 로그인 ────────────────────────────────────────────
  // 카카오톡 앱이 설치돼 있으면 그걸로, 아니면 카카오계정(웹) 로그인으로 대체.
  static Future<AuthUser> signInWithKakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        debugPrint('[AuthService] 카카오톡 로그인 실패, 카카오계정으로 재시도: $e');
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }

    return _login(provider: 'kakao', oauthToken: token.accessToken);
  }

  // ── 공통: 백엔드 로그인 요청 → JWT 발급받고 저장 ───────────────
  // device_info는 지금은 안 보냄(null) — 기기별 토큰 회수 기능을 쓰려면
  // 나중에 device_info_plus 같은 패키지로 기기 식별자를 넣어주면 된다.
  static Future<AuthUser> _login({
    required String provider,
    required String oauthToken,
    String? deviceInfo,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'oauth_token': oauthToken,
        'device_info': deviceInfo,
      }),
    );

    if (response.statusCode != 200) {
      throw _toReadableException(response);
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    await _storage.write(key: _kAccessToken, value: data['access_token']);
    await _storage.write(key: _kRefreshToken, value: data['refresh_token']);
    return AuthUser.fromLoginJson(data['user'], provider: provider);
  }

  // ── 저장된 access token 꺼내오기 (다른 API 호출 시 Authorization 헤더용) ──
  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  // ── access token 갱신 (refresh_token은 그대로 유지, 새로 안 내려옴) ──
  static Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) {
      throw Exception('저장된 refresh token이 없습니다. 다시 로그인해주세요.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode != 200) {
      throw _toReadableException(response);
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final newAccessToken = data['access_token'] as String;
    await _storage.write(key: _kAccessToken, value: newAccessToken);
    return newAccessToken;
  }

  // ── 내 정보 조회 (Bearer 인증 필요) ─────────────────────────────
  static Future<AuthUser> getMe() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('로그인이 필요합니다.');

    final response = await http.get(
      Uri.parse('$_baseUrl/api/users/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toReadableException(response);
    }
    return AuthUser.fromMeJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  // ── 로그아웃 (Bearer 인증 필요) ──────────────────────────────
  static Future<void> logout() async {
    final accessToken = await getAccessToken();
    final refreshToken = await _storage.read(key: _kRefreshToken);

    if (accessToken != null && refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      } catch (e) {
        debugPrint('[AuthService] 로그아웃 요청 실패(무시): $e');
      }
    }
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  // ── 공통: 에러 응답({error_code, message}) → 읽기 쉬운 예외로 변환 ──
  static Exception _toReadableException(http.Response response) {
    String message = '(코드 ${response.statusCode})';
    String? errorCode;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        errorCode = body['error_code']?.toString();
        message = body['message']?.toString() ?? message;
      }
    } catch (_) {
      // 본문이 JSON이 아니면 무시하고 상태코드만 사용
    }
    debugPrint('[AuthService] 오류(${response.statusCode}, $errorCode): $message');

    switch (response.statusCode) {
      case 401:
        return Exception('로그인이 만료되었거나 유효하지 않습니다. 다시 로그인해주세요. ($message)');
      case 400:
        return Exception('잘못된 요청입니다. ($message)');
      default:
        return Exception('서버 오류가 발생했습니다. ($message)');
    }
  }
}
