import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/study_material.dart';

class AiService {
  // 10.0.2.2는 안드로이드 에뮬레이터에서 로컬 호스트(PC)에 접속하기 위한 IP입니다.
  // 실제 기기라면 PC의 IP 주소(예: 192.168.0.10)로 바꿔야 합니다.
  static const String _baseUrl = 'http://0.0.0.0:8000';

  static Future<StudyMaterial> summarize({
    required String text,
    required String subject,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/summarize'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'subject': subject,
        }),
      );

      if (response.statusCode == 200) {
        // 한글이 깨지지 않도록 utf8.decode 처리
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        return StudyMaterial(
          id: DateTime.now().millisecondsSinceEpoch, // 임시 ID
          subject: subject,
          title: data['title'] ?? '제목 없음',
          date: DateTime.now().toString().substring(0, 10), // 오늘 날짜
          summary: data['summary'] ?? '',
          keyPoints: List<String>.from(data['keyPoints'] ?? []),
          quizCount: data['quizCount'] ?? 0,
        );
      } else {
        throw Exception('서버 응답 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('AI 서비스 오류: $e');
      throw Exception('AI 요약을 가져오는 데 실패했습니다: $e');
    }
  }
}