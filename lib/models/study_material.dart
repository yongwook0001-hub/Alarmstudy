import 'quiz_question.dart';

class StudyMaterial {
  final int id;
  final String subject;
  final String title;
  final String date;
  final String summary;
  final List<String> keyPoints;
  final int quizCount;
  final List<QuizQuestion> quizQuestions; // 업로드 시 미리 생성해둔 퀴즈

  StudyMaterial({
    required this.id,
    required this.subject,
    required this.title,
    required this.date,
    required this.summary,
    required this.keyPoints,
    required this.quizCount,
    this.quizQuestions = const [],
  });
}
