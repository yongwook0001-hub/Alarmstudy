/// 앱에 기본으로 내장된 알람음 목록.
///
/// 실제 파일은 assets/sounds/<id>.wav (pubspec.yaml에 assets/sounds/ 폴더 통째로 등록됨).
/// alarm_add_screen.dart(선택 UI)와 나중에 만들 실제 알람 재생 로직에서
/// 이 목록을 공통으로 참조하면 된다.
class AlarmSound {
  final String id;
  final String label;
  final String assetPath;

  const AlarmSound({required this.id, required this.label, required this.assetPath});
}

const List<AlarmSound> kDefaultAlarmSounds = [
  AlarmSound(id: 'default', label: '기본 알람음', assetPath: 'assets/sounds/default.wav'),
  AlarmSound(id: 'chime', label: '차임벨', assetPath: 'assets/sounds/chime.wav'),
  AlarmSound(id: 'classic', label: '클래식', assetPath: 'assets/sounds/classic.wav'),
  AlarmSound(id: 'pulse', label: '펄스', assetPath: 'assets/sounds/pulse.wav'),
];

/// soundId로 기본 알람음 찾기 (없으면 첫 번째 = 기본 알람음).
AlarmSound findAlarmSound(String id) {
  return kDefaultAlarmSounds.firstWhere(
    (s) => s.id == id,
    orElse: () => kDefaultAlarmSounds.first,
  );
}

/// AI가 학습자료로 만들어준 노래를 선택했을 때 쓰는 soundId 값.
const String kCustomSongSoundId = 'custom_song';
