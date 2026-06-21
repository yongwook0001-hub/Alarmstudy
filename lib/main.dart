import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/alarm_model.dart';
import 'models/study_material.dart';
import 'models/quiz_question.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_add_screen.dart';
import 'screens/study_material_screen.dart';
import 'screens/ai_summary_screen.dart';
import 'screens/alarm_ringing_screen.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AlarmStudyApp());
}

// 샘플 데이터
final sampleAlarms = [
  AlarmModel(
    id: 1, time: '06:30', label: '출근 준비',
    active: true, days: ['월', '화', '수', '목', '금'],
    quizSubject: '한국사',
  ),
  AlarmModel(
    id: 2, time: '08:00', label: '주말 공부',
    active: false, days: ['토', '일'],
    quizSubject: '영어',
  ),
];

final sampleMaterials = [
  StudyMaterial(
    id: 1, subject: '한국사', title: '조선시대 붕당정치',
    date: '2026-06-20',
    summary: '붕당정치는 16세기 중반 이후 사림파의 집권과 함께 형성된 정치 형태로, 동인·서인의 분열을 시작으로 남인·북인·노론·소론 등 다양한 당파가 형성되었습니다.',
    keyPoints: ['동인·서인 분열 (1575)', '예송논쟁으로 남인·서인 대립', '환국정치 - 숙종 시기 권력 교체', '노론·소론 분화'],
    quizCount: 5,
  ),
  StudyMaterial(
    id: 2, subject: '영어', title: '관계대명사 완전정복',
    date: '2026-06-19',
    summary: '관계대명사는 두 문장을 연결하면서 명사를 수식하는 절을 만드는 접속사 겸 대명사입니다. who, whom, whose, which, that이 있습니다.',
    keyPoints: ['who/whom - 사람', 'which - 사물', 'whose - 소유격', 'that - 사람/사물 모두'],
    quizCount: 5,
  ),
];

final sampleQuiz = QuizQuestion(
  question: '조선시대 붕당정치에서 1575년 동인과 서인의 분열 원인이 된 사건은?',
  options: ['이조전랑 임명 문제', '임진왜란 발발', '예송논쟁', '인조반정'],
  correctIndex: 0,
);

class AlarmStudyApp extends StatelessWidget {
  const AlarmStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI학습 알람',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          surface: kBg,
          primary: kPrimary,
          secondary: kPrimaryLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          elevation: 0,
          iconTheme: IconThemeData(color: kFg),
          titleTextStyle: TextStyle(
            color: kFg, fontSize: 20, fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  final _labels = ['홈', '알람 목록', '학습 자료', 'AI 요약', '알람 울림'];

  Widget _buildScreen() {
    switch (_tab) {
      case 0: return HomeScreen(onTabChange: (i) => setState(() => _tab = i));
      case 1: return AlarmListScreen(alarms: sampleAlarms, onAdd: () => setState(() => _tab = 2));
      case 2: return const AlarmAddScreen();
      case 3: return StudyMaterialScreen(materials: sampleMaterials, onSummary: (m) => setState(() => _tab = 4));
      case 4: return AiSummaryScreen(material: sampleMaterials[0]);
      case 5: return AlarmRingingScreen(alarm: sampleAlarms[0]);
      default: return HomeScreen(onTabChange: (i) => setState(() => _tab = i));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: Container(
        color: kBg,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_labels.length, (i) {
              final isSelected = _tab == i;
              return GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimary : kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? kPrimary : kBorder),
                  ),
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color: isSelected ? Colors.white : kMuted,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}