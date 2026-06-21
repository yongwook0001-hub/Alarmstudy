import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/study_material.dart';

class AiService {
  static const _url = 'https://api.anthropic.com/v1/messages';

  static String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  // 학습 자료 요약 + 퀴즈 생성
  static Future<StudyMaterial> summarize({
    required String text,
    required String subject,
  }) async {
    final prompt = '''
다음 학습 자료를 분석해서 아래 JSON 형식으로만 응답해줘. JSON 외 다른 텍스트는 절대 쓰지 마.

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

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-6',
        'max_tokens': 1024,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API 오류: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final content = body['content'][0]['text'] as String;
    final json = jsonDecode(content);

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