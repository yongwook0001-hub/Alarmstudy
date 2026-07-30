import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../models/auth_user.dart';

/// 구글/카카오 로그인 + 백엔드 인증(JWT) 담당 서비스.
/// 백엔드의 /auth/google, /auth/kakao, /auth/refresh, /auth/logout과 짝을 이룬다.
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

    return _loginToBackend('/auth/google', {'id_token': idToken});
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

    return _loginToBackend('/auth/kakao', {'access_token': token.accessToken});
  }

  // ── 공통: 백엔드에 토큰 검증 요청 → JWT 발급받고 저장 ─────────
  static Future<AuthUser> _loginToBackend(String path, Map<String, String> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('로그인 실패 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    await _storage.write(key: _kAccessToken, value: data['access_token']);
    await _storage.write(key: _kRefreshToken, value: data['refresh_token']);
    return AuthUser.fromJson(data['user']);
  }

  // ── 저장된 access token 꺼내오기 (API 호출 시 Authorization 헤더용) ──
  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  // ── 로그아웃 ─────────────────────────────────────────────────
  static Future<void> logout() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      } catch (e) {
        debugPrint('[AuthService] 로그아웃 요청 실패(무시): $e');
      }
    }
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}