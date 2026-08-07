import '../models/quiz_session.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// server/app/api/sessions.py 호출 담당 - 알람 해제 퀴즈의 실제 출제/채점/해제.
/// 테스트 모드에서는 서버 인증 없이도 바로 퀴즈/미션 흐름을 검증할 수 있게
/// 로컬 목업 세션으로 대체한다.
class SessionsService {
  static List<SessionQuestion> _mockQuestions(int alarmId) => [
        SessionQuestion(
          questionId: 1000 + alarmId,
          source: 'buffer',
          content: '테스트 문제 1: 알람을 끄려면 먼저 정답을 고르세요.',
          choices: ['정답', '오답 1', '오답 2', '오답 3'],
          topic: '테스트',
        ),
        SessionQuestion(
          questionId: 2000 + alarmId,
          source: 'buffer',
          content: '테스트 문제 2: 1번을 선택하면 정답입니다.',
          choices: ['정답', '오답 1', '오답 2', '오답 3'],
          topic: '테스트',
        ),
        SessionQuestion(
          questionId: 3000 + alarmId,
          source: 'buffer',
          content: '테스트 문제 3: 2번 이상 틀리면 미션이 시작됩니다.',
          choices: ['정답', '오답 1', '오답 2', '오답 3'],
          topic: '테스트',
        ),
      ];

  static Future<QuizSession> start(int alarmId) async {
    if (AuthService.isTestModeEnabled) {
      return QuizSession(
        sessionId: 9000 + alarmId,
        requiredCount: 2,
        questions: _mockQuestions(alarmId),
      );
    }

    final data = await ApiClient.post('/api/sessions', body: {'alarm_id': alarmId});
    return QuizSession.fromJson(data as Map<String, dynamic>);
  }

  static Future<AttemptResult> submitAttempt({
    required int sessionId,
    required int questionId,
    required String source,
    int? selectedAnswer,
    int? timeTakenSeconds,
  }) async {
    if (AuthService.isTestModeEnabled) {
      final isCorrect = selectedAnswer == 0;
      return AttemptResult(
        isCorrect: isCorrect,
        correctAnswer: 0,
        explanation: isCorrect ? '테스트 정답입니다.' : '테스트 오답입니다.',
      );
    }

    final data = await ApiClient.post(
      '/api/sessions/$sessionId/attempts',
      body: {
        'question_id': questionId,
        'source': source,
        'selected_answer': selectedAnswer,
        'time_taken_seconds': timeTakenSeconds,
      },
    );
    return AttemptResult.fromJson(data as Map<String, dynamic>);
  }

  /// dismissMethod: 'quiz' | 'mission'. 필요한 정답 수를 못 채웠으면
  /// ApiException(errorCode: 'QUIZ_NOT_COMPLETED')을 던진다 - 호출부가 새 세션을 다시 시작해야 함.
  static Future<void> dismiss(int sessionId, {required String dismissMethod}) async {
    if (AuthService.isTestModeEnabled) return;
    await ApiClient.post('/api/sessions/$sessionId/dismiss', body: {'dismiss_method': dismissMethod});
  }
}
