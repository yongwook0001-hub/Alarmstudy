import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// 서버가 {error_code, message} 형식(AppError)으로 내려주는 에러를 감싸는 예외.
/// statusCode 401 + errorCode == 'ACCESS_TOKEN_EXPIRED'인 경우 [ApiClient]가
/// 자동으로 토큰을 갱신하고 한 번 재시도하므로, 화면단에서 이 예외를 볼 때는
/// 보통 "그래도 실패한" 진짜 에러다.
class ApiException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;

  ApiException({required this.statusCode, this.errorCode, required this.message});

  @override
  String toString() => message;
}

/// server/app/api/* 전체가 공유하는 Bearer 인증 + AppError({error_code,message}) 규약을
/// 한 곳에서 처리하는 공용 HTTP 헬퍼.
///
/// - 모든 요청에 저장된 access_token을 Authorization: Bearer로 자동으로 붙인다.
/// - 401 ACCESS_TOKEN_EXPIRED를 받으면 AuthService.refreshAccessToken()으로 한 번만
///   갱신을 시도하고, 성공하면 원래 요청을 그대로 재시도한다 (무한루프 방지).
class ApiClient {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  static Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);

  static Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  static Future<dynamic> delete(String path) => _send('DELETE', path);

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool isRetry = false,
  }) async {
    final token = await AuthService.getAccessToken();
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
    }

    if (response.statusCode == 401 && !isRetry) {
      final errorCode = _tryExtractErrorCode(response);
      if (errorCode == 'ACCESS_TOKEN_EXPIRED') {
        try {
          await AuthService.refreshAccessToken();
          return _send(method, path, query: query, body: body, isRetry: true);
        } catch (_) {
          // 갱신 실패 - 아래에서 원래 401을 그대로 던진다 (로그인 화면으로 보내야 함).
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toApiException(response);
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static String? _tryExtractErrorCode(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) return body['error_code']?.toString();
    } catch (_) {}
    return null;
  }

  static ApiException _toApiException(http.Response response) {
    String message = '(코드 ${response.statusCode})';
    String? errorCode;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        errorCode = body['error_code']?.toString();
        message = body['message']?.toString() ?? body['detail']?.toString() ?? message;
      }
    } catch (_) {
      // 본문이 JSON이 아니면 무시하고 상태코드만 사용
    }
    return ApiException(statusCode: response.statusCode, errorCode: errorCode, message: message);
  }
}
