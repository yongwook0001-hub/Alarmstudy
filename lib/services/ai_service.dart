import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/study_material.dart';
import '../models/quiz_question.dart';

/// AlarmStudy 백엔드(FastAPI) 서버를 호출해 요약+퀴즈를 받아오는 서비스.
///
/// front/back 브랜치에서 각자 Gemini API를 클라이언트에서 직접 호출하던 로직과
/// docker 브랜치의 FastAPI 서버 골격을 하나로 합쳤다.
/// 실제 Gemini 호출·응답 파싱(요약+퀴즈 3문제, PDF 지원, 503 재시도, 세부주제 태깅)은
/// 전부 서버(Alarmstudy_Server/backend)에서 담당하고, 클라이언트는 HTTP 요청만 보낸다.
class AiService {
  /// 백엔드 서버 주소. .env의 API_BASE_URL로 오버라이드 가능.
  /// 10.0.2.2는 안드로이드 에뮬레이터에서 로컬 호스트(PC)에 접속하기 위한 IP.
  /// 실제 기기에서 테스트할 땐 PC의 IP 주소(예: 192.168.0.10)로 바꿔야 한다.
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  // ── 텍스트 입력 → 요약+퀴즈 ──────────────────────────────────
  static Future<StudyMaterial> summarizeText({
    required String text,
    required String subject,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'subject': subject}),
      );
      return _handleResponse(response, subject);
    } on http.ClientException catch (e) {
      throw _toReadableException(e.message);
    }
  }

  // ── PDF 입력 → 요약+퀴즈 (서버에서 503 시 1회 재시도) ──────────
  static Future<StudyMaterial> summarizePdf({
    required Uint8List pdfBytes,
    required String subject,
  }) async {
    final sizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);
    debugPrint('[AiService] PDF 전송 시작 — ${sizeKb}KB');

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/summarize/pdf'),
      )
        ..fields['subject'] = subject
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            pdfBytes,
            filename: 'material.pdf',
          ),
        );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      debugPrint('[AiService] PDF 응답 수신 — ${response.statusCode}');
      return _handleResponse(response, subject);
    } on http.ClientException catch (e) {
      throw _toReadableException(e.message);
    }
  }

  // ── 공통: 응답 상태코드 처리 + 파싱 ─────────────────────────────
  static StudyMaterial _handleResponse(http.Response response, String subject) {
    if (response.statusCode != 200) {
      final detail = _extractDetail(response) ?? '(코드 ${response.statusCode})';
      throw _toReadableException(detail, statusCode: response.statusCode);
    }
    return _parse(utf8.decode(response.bodyBytes), subject);
  }

  static String? _extractDetail(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {
      // 본문이 JSON이 아니면 무시
    }
    return null;
  }

  static Exception _toReadableException(String msg, {int? statusCode}) {
    debugPrint('[AiService] 오류($statusCode): $msg');
    if (statusCode == 503 || msg.contains('503') || msg.toLowerCase().contains('unavailable')) {
      return Exception('서버 과부하 (503). 잠시 후 다시 시도해주세요.\n원문: $msg');
    } else if (statusCode == 429 || msg.contains('429') || msg.toLowerCase().contains('quota')) {
      return Exception('API 할당량 초과 (429). 잠시 후 다시 시도해주세요.\n원문: $msg');
    } else if (statusCode == 400 || msg.contains('400')) {
      return Exception('잘못된 요청 (400). 파일이 손상됐거나 지원되지 않는 형식일 수 있습니다.\n원문: $msg');
    } else if (statusCode == 403 || msg.contains('403')) {
      return Exception('API 키 권한 오류 (403).\n원문: $msg');
    } else if (statusCode == null) {
      return Exception('서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인해주세요.\n원문: $msg');
    } else {
      return Exception('서버 오류: $msg');
    }
  }

  // ── 서버 응답(JSON) → StudyMaterial 파싱 ────────────────────────
  // 서버가 이미 quiz를 {question, options, correctIndex, topic} 형태로 정리해서 내려준다.
  static StudyMaterial _parse(String rawBody, String subject) {
    final json = jsonDecode(rawBody);

    final quizList = (json['quiz'] as List).map((q) => QuizQuestion(
      question: q['question'],
      options: List<String>.from(q['options']),
      correctIndex: q['correctIndex'],
      topic: (q['topic'] as String?)?.trim().isNotEmpty == true ? q['topic'] : subject,
    )).toList();

    return StudyMaterial(
      id: DateTime.now().millisecondsSinceEpoch,
      subject: subject,
      title: json['title'],
      date: DateTime.now().toString().substring(0, 10),
      summary: json['summary'],
      keyPoints: List<String>.from(json['keyPoints']),
      quizCount: quizList.length,
      quizQuestions: quizList,
    );
  }
}
