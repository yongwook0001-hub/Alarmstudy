import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// 학습자료 요약 → 알람용 노래(가사+음원) 생성 결과.
class GeneratedSong {
  final String lyrics;
  final Uint8List audioBytes;
  final String mimeType;

  GeneratedSong({required this.lyrics, required this.audioBytes, required this.mimeType});
}

/// server/app/api/song.py의 POST /api/songs/generate 호출 담당.
///
/// TODO(연동 마무리): 지금은 호출 함수만 준비된 상태.
/// 실제로 쓰려면: 1) 학습자료 화면/알람 추가 화면에 "AI 노래 만들기" 버튼을 추가하고
/// 2) 여기서 받은 audioBytes를 로컬 파일로 저장한 뒤 3) 그 파일 경로를 알람의
/// "알람음"으로 지정하는 기능(AlarmModel에 커스텀 사운드 경로 필드 추가 필요)까지 이어줘야 함.
class SongService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static Future<GeneratedSong> generate({
    required String subject,
    required String summary,
    List<String> keyPoints = const [],
    String? mood,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/songs/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subject': subject,
        'summary': summary,
        'key_points': keyPoints,
        if (mood != null) 'mood': mood,
      }),
    );

    if (response.statusCode != 200) {
      String message = '(코드 ${response.statusCode})';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map) message = body['message']?.toString() ?? message;
      } catch (_) {}
      throw Exception('노래 생성 실패: $message');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return GeneratedSong(
      lyrics: data['lyrics'] as String,
      audioBytes: base64Decode(data['audio_base64'] as String),
      mimeType: data['mime_type'] as String,
    );
  }
}
