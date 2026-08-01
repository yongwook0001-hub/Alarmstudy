/// 알람 해제용 퀴즈 문제 하나.
/// topic은 "주제별 정답률" 통계를 위해 추가된 필드 - Gemini가 문제 생성 시 함께 태깅한다.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String topic; // 예: "이진트리", "그래프", "순회" 등 세부 주제

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.topic = '기타',
  });
}