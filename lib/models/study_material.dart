import 'quiz_question.dart';

/// 학습 자료 한 건 (PDF 한 개 또는 직접 입력한 텍스트 한 개에 대응).
/// "폴더"는 별도 모델이 아니라, 같은 subject를 가진 StudyMaterial들을
/// 화면에서 그룹핑해서 보여주는 방식으로 구현한다 (폴더 화면 쪽 로직 참고).
class StudyMaterial {
  final int id;
  final String subject; // 폴더 이름 역할도 겸함
  final String title;
  final String date;
  final String summary;
  final List<String> keyPoints;
  final int quizCount;
  final List<QuizQuestion> quizQuestions;

  // PDF 페이지 수 - 지금은 Gemini 응답에 없어서 null 기본값.
  // 나중에 pdf 페이지 카운트 라이브러리(예: syncfusion_flutter_pdf)를 붙이면 채울 수 있음.
  final int? pages;

  // 퀴즈 풀이 누적 통계 - 알람 퀴즈 화면(AlarmRingingScreen)에서 정답 제출할 때마다 갱신됨
  int correctCount;
  int wrongCount;

  // 주제별 통계 - key는 QuizQuestion.topic
  Map<String, int> topicCorrect;
  Map<String, int> topicWrong;

  StudyMaterial({
    required this.id,
    required this.subject,
    required this.title,
    required this.date,
    required this.summary,
    required this.keyPoints,
    required this.quizCount,
    required this.quizQuestions,
    this.pages,
    this.correctCount = 0,
    this.wrongCount = 0,
    Map<String, int>? topicCorrect,
    Map<String, int>? topicWrong,
  })  : topicCorrect = topicCorrect ?? {},
        topicWrong = topicWrong ?? {};

  /// 전체 정답률 (0~100). 아직 한 번도 안 풀었으면 null.
  double? get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return null;
    return correctCount / total * 100;
  }

  /// 퀴즈 하나를 풀었을 때 호출 - 전체 통계와 주제별 통계를 함께 갱신한다.
  /// alarm_ringing_screen.dart(퀴즈 채점하는 화면)에서
  /// 사용자가 답을 제출하는 시점에 이 메서드를 호출해줘야 통계가 쌓인다.
  void recordAnswer({required bool isCorrect, required String topic}) {
    if (isCorrect) {
      correctCount++;
      topicCorrect[topic] = (topicCorrect[topic] ?? 0) + 1;
    } else {
      wrongCount++;
      topicWrong[topic] = (topicWrong[topic] ?? 0) + 1;
    }
  }

  /// 주제별 정답률 맵 (시도한 주제만 포함, 정답률 내림차순 아님 - 화면에서 정렬)
  Map<String, double> get topicAccuracy {
    final topics = {...topicCorrect.keys, ...topicWrong.keys};
    final result = <String, double>{};
    for (final t in topics) {
      final correct = topicCorrect[t] ?? 0;
      final wrong = topicWrong[t] ?? 0;
      final total = correct + wrong;
      if (total > 0) result[t] = correct / total * 100;
    }
    return result;
  }

  /// 정답률이 가장 낮은 주제 (약점 피드백용). 시도한 주제가 없으면 null.
  String? get weakestTopic {
    final acc = topicAccuracy;
    if (acc.isEmpty) return null;
    return acc.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }
}