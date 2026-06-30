class AlarmModel {
  final int id;
  final String time;
  final String label;
  bool active;
  final List<String> days;
  final String quizSubject;
  final int? materialId; // 연결된 학습자료 id (없으면 퀴즈 없이 알람 끄기 가능)

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.active,
    required this.days,
    required this.quizSubject,
    this.materialId,
  });
}
