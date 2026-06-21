class StudyMaterial {
  final int id;
  final String subject;
  final String title;
  final String date;
  final String summary;
  final List<String> keyPoints;
  final int quizCount;

  StudyMaterial({
    required this.id,
    required this.subject,
    required this.title,
    required this.date,
    required this.summary,
    required this.keyPoints,
    required this.quizCount,
  });
}