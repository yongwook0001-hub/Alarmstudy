/// 알람 해제 퀴즈 세션 - 백엔드 POST /api/sessions 응답을 그대로 반영한다.
///
/// 기존에는 학습자료를 만들 때 퀴즈 3문제를 통째로 받아 로컬에 들고 있었지만,
/// 실제 백엔드는 문제를 세트 단위 버퍼에 미리 쌓아두고 알람이 울릴 때(세션 시작 시)만
/// 정답이 빠진 형태로 내려준다. 정답 여부는 각 문제를 제출(POST .../attempts)해야만 알 수 있다.
class SessionQuestion {
  final int questionId;
  final String source; // 'buffer' | 'retry'
  final String content;
  final List<String> choices;
  final String topic;

  SessionQuestion({
    required this.questionId,
    required this.source,
    required this.content,
    required this.choices,
    required this.topic,
  });

  factory SessionQuestion.fromJson(Map<String, dynamic> json) => SessionQuestion(
        questionId: json['question_id'],
        source: json['source'],
        content: json['content'],
        choices: List<String>.from(json['choices']),
        topic: json['topic'],
      );
}

class QuizSession {
  final int sessionId;
  final int requiredCount;
  final List<SessionQuestion> questions;

  QuizSession({required this.sessionId, required this.requiredCount, required this.questions});

  factory QuizSession.fromJson(Map<String, dynamic> json) => QuizSession(
        sessionId: json['session_id'],
        requiredCount: json['required_count'],
        questions: (json['questions'] as List)
            .map((q) => SessionQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

/// 문제 하나 제출(POST /api/sessions/{id}/attempts) 결과.
class AttemptResult {
  final bool isCorrect;
  final int correctAnswer;
  final String? explanation;

  AttemptResult({required this.isCorrect, required this.correctAnswer, this.explanation});

  factory AttemptResult.fromJson(Map<String, dynamic> json) => AttemptResult(
        isCorrect: json['is_correct'],
        correctAnswer: json['correct_answer'],
        explanation: json['explanation'],
      );
}
