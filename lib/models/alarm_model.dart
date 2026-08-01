class AlarmModel {
  final int id;
  final String time;
  final String label;
  bool active;
  final List<String> days;
  final String quizSubject;
  final int? materialId; // 연결된 학습자료 id (없으면 퀴즈 없이 알람 끄기 가능)

  // 알람음 - 기본 제공 사운드는 soundId로 식별 (assets/sounds/<id>.wav),
  // AI가 학습자료로 만들어준 노래를 선택하면 customSoundPath에 로컬 파일 경로가 들어가고
  // soundId는 'custom_song'이 된다. (alarm_add_screen.dart의 _pickSound 참고)
  final String soundId;
  final String? customSoundPath;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.active,
    required this.days,
    required this.quizSubject,
    this.materialId,
    this.soundId = 'default',
    this.customSoundPath,
  });
}
