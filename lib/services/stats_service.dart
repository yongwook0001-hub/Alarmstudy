import 'api_client.dart';
import 'auth_service.dart';

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

/// GET /api/wrong-answers의 페이지 하나 (items + 페이지네이션 메타).
class WrongAnswerPage {
  final List<WrongAnswerItem> items;
  final int total;
  final int page;
  final int size;

  WrongAnswerPage({required this.items, required this.total, required this.page, required this.size});
}

class WeakTopicStat {
  final String topic;
  final int accuracy;

  WeakTopicStat({required this.topic, required this.accuracy});

  factory WeakTopicStat.fromJson(Map<String, dynamic> json) => WeakTopicStat(
        topic: json['topic'] as String,
        accuracy: (json['accuracy'] as num).round(),
      );
}

/// GET /api/sets/{id}/analysis 응답. weak_topics/comment/analyzed_at은 아직 분석이 없으면
/// 셋 다 null이지만, total_attempts/correct_count/overall_accuracy는 분석 존재 여부와
/// 무관하게 서버가 항상 실시간 계산해서 채워준다 (문제 0건이면 0으로 안전 반환).
class SetAnalysis {
  final int setId;
  final List<WeakTopicStat>? weakTopics;
  final String? comment;
  final DateTime? analyzedAt;
  final int totalAttempts;
  final int correctCount;
  final double overallAccuracy;

  SetAnalysis({
    required this.setId,
    required this.weakTopics,
    required this.comment,
    required this.analyzedAt,
    required this.totalAttempts,
    required this.correctCount,
    required this.overallAccuracy,
  });

  factory SetAnalysis.fromJson(Map<String, dynamic> json) => SetAnalysis(
        setId: json['set_id'],
        weakTopics: (json['weak_topics'] as List?)
            ?.map((e) => WeakTopicStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        comment: json['comment'],
        analyzedAt: json['analyzed_at'] != null ? DateTime.parse(json['analyzed_at']) : null,
        totalAttempts: json['total_attempts'],
        correctCount: json['correct_count'],
        overallAccuracy: (json['overall_accuracy'] as num).toDouble(),
      );
}

/// server/app/api/stats.py (/api/stats/summary, /api/wrong-answers, /api/sets/{id}/analysis) 호출 담당.
class StatsService {
  static Future<StatsSummary> summary() async {
    if (AuthService.isTestModeEnabled) return StatsSummary.empty();

    // 앱이 한국어 전용이라 타임존은 고정값으로 보낸다 (server/app/api/stats.py가
    // tz 쿼리 파라미터를 필수로 요구해서 - "오늘"의 기준이 서버 UTC가 아니라
    // 이 타임존 기준이 되도록 함).
    final data = await ApiClient.get('/api/stats/summary', query: {'tz': 'Asia/Seoul'});
    return StatsSummary.fromJson(data as Map<String, dynamic>);
  }

  /// 자료 상세(AiSummaryScreen) 카드용 - 첫 페이지만 필요해서 total/page는 버린다.
  static Future<List<WrongAnswerItem>> wrongAnswers({int? setId, String sort = 'recent'}) async {
    final page = await wrongAnswersPage(setId: setId, sort: sort);
    return page.items;
  }

  /// 오답노트 화면(무한스크롤)용 - total까지 받아야 "더 불러올 페이지가 남았는지" 판단 가능.
  static Future<WrongAnswerPage> wrongAnswersPage({
    int? setId,
    String sort = 'recent',
    int page = 1,
    int size = 20,
  }) async {
    final data = await ApiClient.get('/api/wrong-answers', query: {
      if (setId != null) 'set_id': '$setId',
      'sort': sort,
      'page': '$page',
      'size': '$size',
    });
    final items = (data['items'] as List)
        .map((j) => WrongAnswerItem.fromJson(j as Map<String, dynamic>))
        .toList();
    return WrongAnswerPage(items: items, total: data['total'], page: data['page'], size: data['size']);
  }

  /// weak_topics/comment - 해당 세트에 대한 분석이 아직 없으면 둘 다 null.
  static Future<SetAnalysis> setAnalysis(int setId) async {
    final data = await ApiClient.get('/api/sets/$setId/analysis');
    return SetAnalysis.fromJson(data as Map<String, dynamic>);
  }
}
