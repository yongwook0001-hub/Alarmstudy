/// 요일 순서(일~토) - 백엔드 repeat_days 비트마스크 <-> Dart의 List<String> days 변환에
/// 공통으로 쓰는 순서. 백엔드는 repeat_days를 "그대로 저장하는 정수"로만 다루고
/// (server/app/models/alarm.py, server/tests/test_alarms.py 참고 - 서버는 비트 의미를
/// 검증/해석하지 않는 순수 passthrough) 어떤 비트가 어느 요일인지 정해두지 않았으므로,
/// 이 앱이 직접 규칙을 정한다: bit i(0-indexed) == kWeekdayOrder[i].
/// (alarm_list_screen.dart의 _weekdays 표시 순서와 동일하게 맞춤)
const List<String> kWeekdayOrder = ['일', '월', '화', '수', '목', '금', '토'];

int daysToBitmask(List<String> days) {
  var mask = 0;
  for (var i = 0; i < kWeekdayOrder.length; i++) {
    if (days.contains(kWeekdayOrder[i])) mask |= (1 << i);
  }
  return mask;
}

List<String> daysFromBitmask(int mask) {
  return [for (var i = 0; i < kWeekdayOrder.length; i++) if (mask & (1 << i) != 0) kWeekdayOrder[i]];
}

class AlarmModel {
  final int id;
  final String time;
  final String label;
  bool active;
  final List<String> days;

  // 연결된 학습자료 "세트" id (없으면 퀴즈 없이 알람 끄기 가능). 백엔드 alarms.set_id에 대응.
  int? setId;

  // 알람음 - 기본 제공 사운드는 soundId로 식별 (assets/sounds/<id>.wav) - 백엔드 alarms.sound 컬럼에
  // 그대로 저장된다. AI가 학습자료로 만들어준 노래를 선택하면 customSoundPath에 로컬 파일 경로가
  // 들어가고 soundId는 'custom_song'이 된다. customSoundPath는 기기 로컬 값이라 서버에는
  // 저장되지 않는다 - 재설치/기기변경 시 커스텀 알람음 연결은 끊긴다 (알려진 한계).
  String soundId;
  String? customSoundPath;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.active,
    required this.days,
    this.setId,
    this.soundId = 'default',
    this.customSoundPath,
  });

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'],
      time: json['alarm_time'],
      label: (json['label'] as String?)?.isNotEmpty == true ? json['label'] : '알람',
      active: json['is_enabled'] ?? true,
      days: daysFromBitmask(json['repeat_days'] ?? 0),
      setId: json['set_id'],
      soundId: json['sound'] ?? 'default',
    );
  }

  /// POST /api/alarms 요청 본문. volume/is_vibration은 아직 UI가 없어 서버 기본값을 명시적으로 보낸다.
  Map<String, dynamic> toCreateJson() => {
        'alarm_time': time,
        'set_id': setId,
        'repeat_days': daysToBitmask(days),
        'is_enabled': active,
        'label': label,
        'sound': soundId,
        'volume': 80,
        'is_vibration': true,
      };

  /// PATCH /api/alarms/{id} 요청 본문 - 현재 상태 전체를 매번 보낸다 (서버가 exclude_unset이라
  /// 부분 갱신도 지원하지만, 클라이언트가 항상 전체 상태를 알고 있으므로 굳이 diff할 필요는 없다).
  Map<String, dynamic> toPatchJson() => toCreateJson();
}
