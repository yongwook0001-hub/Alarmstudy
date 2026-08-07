import '../models/alarm_model.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// server/app/api/alarms.py (POST/GET/PATCH/DELETE /api/alarms) 호출 담당.
/// 테스트 모드에서는 가짜 JWT로 서버가 401을 내므로, 인메모리 목록으로 대체한다.
class AlarmsService {
  static final List<AlarmModel> _testAlarms = [];
  static int _nextId = 1;

  static Future<List<AlarmModel>> list() async {
    if (AuthService.isTestModeEnabled) {
      return _testAlarms.map(_clone).toList();
    }
    final data = await ApiClient.get('/api/alarms') as List;
    return data.map((j) => AlarmModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<AlarmModel> create(AlarmModel alarm) async {
    if (AuthService.isTestModeEnabled) {
      final created = AlarmModel(
        id: _nextId++,
        time: alarm.time,
        label: alarm.label,
        active: alarm.active,
        days: List<String>.from(alarm.days),
        setId: alarm.setId,
        soundId: alarm.soundId,
        customSoundPath: alarm.customSoundPath,
      );
      _testAlarms.insert(0, created);
      return _clone(created);
    }
    final data = await ApiClient.post('/api/alarms', body: alarm.toCreateJson());
    return AlarmModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<AlarmModel> update(AlarmModel alarm) async {
    if (AuthService.isTestModeEnabled) {
      final idx = _testAlarms.indexWhere((a) => a.id == alarm.id);
      if (idx == -1) throw Exception('테스트 알람을 찾을 수 없습니다.');
      final updated = _clone(alarm);
      _testAlarms[idx] = updated;
      return _clone(updated);
    }
    final data = await ApiClient.patch('/api/alarms/${alarm.id}', body: alarm.toPatchJson());
    return AlarmModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(int alarmId) async {
    if (AuthService.isTestModeEnabled) {
      _testAlarms.removeWhere((a) => a.id == alarmId);
      return;
    }
    await ApiClient.delete('/api/alarms/$alarmId');
  }

  static AlarmModel _clone(AlarmModel a) => AlarmModel(
        id: a.id,
        time: a.time,
        label: a.label,
        active: a.active,
        days: List<String>.from(a.days),
        setId: a.setId,
        soundId: a.soundId,
        customSoundPath: a.customSoundPath,
      );
}
