import 'api_client.dart';

class StatsSummary {
  final int currentStreak;
  final int totalStudyDays;
  final int totalAttempts;
  final double correctRate;
  final int totalSets;
  final int activeAlarms;

  StatsSummary({
    required this.currentStreak,
    required this.totalStudyDays,
    required this.totalAttempts,
    required this.correctRate,
    required this.totalSets,
    required this.activeAlarms,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> json) => StatsSummary(
        currentStreak: json['current_streak'],
        totalStudyDays: json['total_study_days'],
        totalAttempts: json['total_attempts'],
        correctRate: (json['correct_rate'] as num).toDouble(),
        totalSets: json['total_sets'],
        activeAlarms: json['active_alarms'],
      );

  static StatsSummary empty() => StatsSummary(
        currentStreak: 0,
        totalStudyDays: 0,
        totalAttempts: 0,
        correctRate: 0,
        totalSets: 0,
        activeAlarms: 0,
      );
}

class WrongAnswerItem {
  final int id;
  final int materialId;
  final String content;
  final List<String> choices;
  final int correctAnswer;
  final String? explanation;
  final String topic;
  final int wrongCount;
  final DateTime lastWrongAt;

  WrongAnswerItem({
    required this.id,
    required this.materialId,
    required this.content,
    required this.choices,
    required this.correctAnswer,
    this.explanation,
    required this.topic,
    required this.wrongCount,
    required this.lastWrongAt,
  });

  factory WrongAnswerItem.fromJson(Map<String, dynamic> json) => WrongAnswerItem(
        id: json['id'],
        materialId: json['material_id'],
        content: json['content'],
        choices: List<String>.from(json['choices']),
        correctAnswer: json['correct_answer'],
        explanation: json['explanation'],
        topic: json['topic'],
        wrongCount: json['wrong_count'],
        lastWrongAt: DateTime.parse(json['last_wrong_at']),
      );
}

/// server/app/api/stats.py (/api/stats/summary, /api/wrong-answers, /api/sets/{id}/analysis) 호출 담당.
class StatsService {
  static Future<StatsSummary> summary() async {
    // 앱이 한국어 전용이라 타임존은 고정값으로 보낸다 (server/app/api/stats.py가
    // tz 쿼리 파라미터를 필수로 요구해서 - "오늘"의 기준이 서버 UTC가 아니라
    // 이 타임존 기준이 되도록 함).
    final data = await ApiClient.get('/api/stats/summary', query: {'tz': 'Asia/Seoul'});
    return StatsSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<WrongAnswerItem>> wrongAnswers({int? setId, String sort = 'recent'}) async {
    final data = await ApiClient.get('/api/wrong-answers', query: {
      if (setId != null) 'set_id': '$setId',
      'sort': sort,
    });
    final items = (data['items'] as List);
    return items.map((j) => WrongAnswerItem.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// weak_topics/comment - 해당 세트에 대한 분석이 아직 없으면 둘 다 null.
  static Future<Map<String, dynamic>> setAnalysis(int setId) async {
    final data = await ApiClient.get('/api/sets/$setId/analysis');
    return data as Map<String, dynamic>;
  }
}
