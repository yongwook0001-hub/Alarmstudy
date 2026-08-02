import '../models/quiz_session.dart';
import 'api_client.dart';

/// server/app/api/sessions.py 호출 담당 - 알람 해제 퀴즈의 실제 출제/채점/해제.
class SessionsService {
  static Future<QuizSession> start(int alarmId) async {
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
  static Future<void> dismiss(int sessionId, {required String dismissMethod}) =>
      ApiClient.post('/api/sessions/$sessionId/dismiss', body: {'dismiss_method': dismissMethod});
}
