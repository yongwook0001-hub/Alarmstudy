import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/study_material.dart';

class AiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<StudyMaterial> summarize({
    required String text,
    required String subject,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',   // 무료 모델
      apiKey: _apiKey,
    );

    final prompt = '''
다음 학습 자료를 분석해서 아래 JSON 형식으로만 응답해. JSON 외 다른 텍스트는 절대 쓰지 마.

학습 자료:
$text

응답 형식:
{
  "title": "학습 자료 제목 (한 줄)",
  "summary": "3~4문장 요약",
  "keyPoints": ["핵심 포인트1", "핵심 포인트2", "핵심 포인트3", "핵심 포인트4"],
  "quizCount": 5
}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text ?? '';

    // JSON 파싱 (```json 블록 제거)
    final cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final json = jsonDecode(cleaned);

    return StudyMaterial(
      id: DateTime.now().millisecondsSinceEpoch,
      subject: subject,
      title: json['title'],
      date: DateTime.now().toString().substring(0, 10),
      summary: json['summary'],
      keyPoints: List<String>.from(json['keyPoints']),
      quizCount: json['quizCount'],
    );
  }
}