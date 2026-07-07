/// 퀴즈 문제 하나를 풀었을 때의 결과. 오늘의 리포트 화면에서 문제 리뷰에 사용된다.
class QuizAnswerResult {
  final String question;
  final String correctAnswerText;
  final bool isCorrect;

  QuizAnswerResult({
    required this.question,
    required this.correctAnswerText,
    required this.isCorrect,
  });
}