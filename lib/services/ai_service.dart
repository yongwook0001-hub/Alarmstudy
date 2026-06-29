import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/study_material.dart';
import '../models/quiz_question.dart';

/// Gemini API 호출을 담당하는 서비스.
/// 요약과 퀴즈를 단일 호출로 합쳐 API 사용량을 최소화한다.
class AiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static GenerativeModel _model() => GenerativeModel(
    model: 'gemini-2.0-flash',
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
    // 입력 텍스트가 너무 길면 앞 1500자만 사용 (토큰 절약)
    final trimmed = text.length > 1500 ? text.substring(0, 1500) : text;

    final prompt = '학습자료:\n$trimmed\n\n$_responseFormat';
    final response = await _model().generateContent([Content.text(prompt)]);
    return _parse(response.text ?? '', subject);
  }

  // ── PDF 입력 → 요약+퀴즈 (1회 호출) ─────────────────────────
  /// PDF 바이트를 Gemini에 직접 전송 (멀티모달).
  /// 토큰 소모가 크므로 파일 크기를 10MB 이하로 제한.
  static Future<StudyMaterial> summarizePdf({
    required Uint8List pdfBytes,
    required String subject,
  }) async {
    final response = await _model().generateContent([
      Content.multi([
        DataPart('application/pdf', pdfBytes),
        TextPart('이 PDF를 분석해.\n$_responseFormat'),
      ]),
    ]);
    return _parse(response.text ?? '', subject);
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
