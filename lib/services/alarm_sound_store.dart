import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 알람의 커스텀 알람음(AI 노래) 파일 경로를 기기에 영구 저장한다.
///
/// customSoundPath는 서버 alarms 테이블에 저장되는 필드가 아니라 순수 로컬 값이라,
/// AlarmModel.fromJson(서버 응답 파싱)에는 애초에 이 값이 들어있지 않다. 그래서
/// POST/PATCH /api/alarms 응답으로 받은 AlarmModel을 그대로 로컬 상태에 반영하면
/// customSoundPath가 null로 덮어써져서 "노래를 선택했는데 알람이 울릴 땐 기본음이
/// 나오는" 문제가 생긴다 (soundId는 'custom_song'으로 남아있지만 경로가 없어서
/// AlarmScheduler._resolveSoundPath가 기본 알람음으로 폴백함).
///
/// 이 저장소가 alarm_id -> customSoundPath 매핑을 기기 로컬 JSON으로 들고 있다가,
/// 서버 응답을 받은 직후(AppData.addAlarm/updateAlarm) 및 앱 재시작 시(loadAll)
/// 이 값을 다시 채워 넣는다.
class AlarmSoundStore {
  static Future<File> _indexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/alarm_sound_index.json');
  }

  static Future<Map<String, dynamic>> _readIndex() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeIndex(Map<String, dynamic> index) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(index));
  }

  /// alarmId에 커스텀 알람음(로컬 파일 경로)을 저장.
  static Future<void> save(int alarmId, String path) async {
    final index = await _readIndex();
    index['$alarmId'] = path;
    await _writeIndex(index);
  }

  /// alarmId에 저장된 커스텀 알람음 경로를 가져온다. 파일이 실제로 없어졌으면 null.
  static Future<String?> get(int alarmId) async {
    final index = await _readIndex();
    final path = index['$alarmId'] as String?;
    if (path == null || !await File(path).exists()) return null;
    return path;
  }

  static Future<void> remove(int alarmId) async {
    final index = await _readIndex();
    if (index.remove('$alarmId') != null) {
      await _writeIndex(index);
    }
  }
}
