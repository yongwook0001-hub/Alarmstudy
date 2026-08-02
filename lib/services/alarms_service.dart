import '../models/alarm_model.dart';
import 'api_client.dart';

/// server/app/api/alarms.py (POST/GET/PATCH/DELETE /api/alarms) 호출 담당.
class AlarmsService {
  static Future<List<AlarmModel>> list() async {
    final data = await ApiClient.get('/api/alarms') as List;
    return data.map((j) => AlarmModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<AlarmModel> create(AlarmModel alarm) async {
    final data = await ApiClient.post('/api/alarms', body: alarm.toCreateJson());
    return AlarmModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<AlarmModel> update(AlarmModel alarm) async {
    final data = await ApiClient.patch('/api/alarms/${alarm.id}', body: alarm.toPatchJson());
    return AlarmModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(int alarmId) => ApiClient.delete('/api/alarms/$alarmId');
}
