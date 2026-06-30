import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/study_material.dart';
import '../models/quiz_question.dart';

/// Gemini API 호출을 담당하는 서비스.
/// 요약과 퀴즈를 단일 호출로 합쳐 API 사용량을 최소화한다.
class AiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static GenerativeModel _model() => GenerativeModel(
    model: 'gemini-2.5-flash-lite',
    apiKey: _apiKey,
  );

  // 요약+퀴즈 3문제를 한 번에 요청하는 프롬프트
  // 토큰을 줄이기 위해 지시문을 최대한 짧게 유지
  static const _responseFormat = '''
JSON만 반환. 다른 텍스트 금지.
{
  "title": "제목",
  "summary": "2문장 요약",
  "keyPoints": ["포인트1","포인트2","포인트3"],
  "quiz": [
    {"q":"문제","o":["보기1","보기2","보기3","보기4"],"a":0}
  ]
}
quiz는 정확히 3개, a는 0~3 정수.''';

  // ── 텍스트 입력 → 요약+퀴즈 (1회 호출) ──────────────────────
  static Future<StudyMaterial> summarizeText({
    required String text,
    required String subject,
  }) async {
    final trimmed = text.length > 1500 ? text.substring(0, 1500) : text;
    final prompt = '학습자료:\n$trimmed\n\n$_responseFormat';
    try {
      final response = await _model().generateContent([Content.text(prompt)]);
      return _parse(response.text ?? '', subject);
    } on GenerativeAIException catch (e) {
      throw _toReadableException(e);
    }
  }

  // ── PDF 입력 → 요약+퀴즈 (503 시 1회 재시도) ────────────────
  static Future<StudyMaterial> summarizePdf({
    required Uint8List pdfBytes,
    required String subject,
  }) async {
    final sizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);
    debugPrint('[AiService] PDF 전송 시작 — ${sizeKb}KB');

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _model().generateContent([
          Content.multi([
            DataPart('application/pdf', pdfBytes),
            TextPart('이 PDF를 분석해.\n$_responseFormat'),
          ]),
        ]);
        debugPrint('[AiService] PDF 응답 수신 — ${response.text?.length ?? 0}chars');
        return _parse(response.text ?? '', subject);
      } on GenerativeAIException catch (e) {
        debugPrint('[AiService] 시도 $attempt 실패: ${e.message}');
        final msg = e.message;
        // 503은 서버 과부하 — 3초 대기 후 1회 재시도
        if (attempt == 1 && (msg.contains('503') || msg.toLowerCase().contains('unavailable'))) {
          debugPrint('[AiService] 503 감지 — 3초 후 재시도');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        throw _toReadableException(e);
      }
    }
    throw Exception('서버가 일시적으로 응답하지 않습니다 (503). 잠시 후 다시 시도해주세요.');
  }

  static Exception _toReadableException(GenerativeAIException e) {
    final msg = e.message;
    debugPrint('[AiService] GenerativeAIException: $msg');
    if (msg.contains('503') || msg.toLowerCase().contains('unavailable')) {
      return Exception('서버 과부하 (503). 잠시 후 다시 시도해주세요.\n원문: $msg');
    } else if (msg.contains('429') || msg.toLowerCase().contains('quota') || msg.toLowerCase().contains('resource exhausted')) {
      return Exception('API 할당량 초과 (429). 잠시 후 다시 시도해주세요.\n원문: $msg');
    } else if (msg.contains('400')) {
      return Exception('잘못된 요청 (400). 파일이 손상됐거나 지원되지 않는 형식일 수 있습니다.\n원문: $msg');
    } else if (msg.contains('403')) {
      return Exception('API 키 권한 오류 (403).\n원문: $msg');
    } else {
      return Exception('Gemini 오류: $msg');
    }
  }
  

  // ── 공통 파싱 ────────────────────────────────────────────────
  static StudyMaterial _parse(String raw, String subject) {
    final cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final json = jsonDecode(cleaned);

    // quiz 배열 → QuizQuestion 리스트로 변환
    final quizList = (json['quiz'] as List).map((q) => QuizQuestion(
      question: q['q'],
      options: List<String>.from(q['o']),
      correctIndex: q['a'],
    )).toList();

    return StudyMaterial(
      id: DateTime.now().millisecondsSinceEpoch,
      subject: subject,
      title: json['title'],
      date: DateTime.now().toString().substring(0, 10),
      summary: json['summary'],
      keyPoints: List<String>.from(json['keyPoints']),
      quizCount: quizList.length,
      quizQuestions: quizList, // 미리 생성된 퀴즈 저장
    );
  }
}
