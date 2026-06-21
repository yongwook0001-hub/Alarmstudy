class AlarmModel {
  final int id;
  final String time;
  final String label;
  bool active;
  final List<String> days;
  final String quizSubject;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.active,
    required this.days,
    required this.quizSubject,
  });
}