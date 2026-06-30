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
import 'screens/my_page_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AlarmStudyApp());
}

// ── 초기 샘플 알람 ──────────────────────────────────────────
final _initialAlarms = [
  AlarmModel(
    id: 1, time: '06:30', label: '출근 준비',
    active: true, days: ['월', '화', '수', '목', '금'],
    quizSubject: '한국사', materialId: 1,
  ),
  AlarmModel(
    id: 2, time: '08:00', label: '주말 공부',
    active: false, days: ['토', '일'],
    quizSubject: '영어', materialId: 2,
  ),
];

// ── 초기 샘플 학습자료 (퀴즈 포함) ────────────────────────────
final _initialMaterials = [
  StudyMaterial(
    id: 1, subject: '한국사', title: '조선시대 붕당정치',
    date: '2026-06-20',
    summary: '붕당정치는 16세기 중반 사림파 집권 이후 동인·서인으로 분열되었고, 이후 노론·소론·남인·북인으로 세분화되었습니다.',
    keyPoints: ['동인·서인 분열 (1575)', '예송논쟁으로 남인·서인 대립', '환국정치 - 숙종 시기 권력 교체'],
    quizCount: 3,
    quizQuestions: [
      QuizQuestion(
        question: '1575년 동인과 서인 분열의 직접적 원인은?',
        options: ['이조전랑 임명 문제', '임진왜란 발발', '예송논쟁', '인조반정'],
        correctIndex: 0,
      ),
      QuizQuestion(
        question: '예송논쟁에서 대립한 두 붕당은?',
        options: ['동인 vs 서인', '남인 vs 서인', '노론 vs 소론', '북인 vs 남인'],
        correctIndex: 1,
      ),
      QuizQuestion(
        question: '숙종 시기 권력이 붕당 간에 급격히 교체된 정치 형태를?',
        options: ['탕평책', '환국정치', '세도정치', '훈구정치'],
        correctIndex: 1,
      ),
    ],
  ),
  StudyMaterial(
    id: 2, subject: '영어', title: '관계대명사 완전정복',
    date: '2026-06-19',
    summary: '관계대명사는 두 문장을 연결하며 명사를 수식하는 절을 만든다. who·which·whose·that이 대표적이다.',
    keyPoints: ['who/whom - 사람', 'which - 사물', 'whose - 소유격'],
    quizCount: 3,
    quizQuestions: [
      QuizQuestion(
        question: '사람을 선행사로 받는 관계대명사는?',
        options: ['which', 'whose', 'who', 'that만 가능'],
        correctIndex: 2,
      ),
      QuizQuestion(
        question: '소유격 관계대명사는?',
        options: ['who', 'whom', 'which', 'whose'],
        correctIndex: 3,
      ),
      QuizQuestion(
        question: '사람과 사물 모두에 쓸 수 있는 관계대명사는?',
        options: ['who', 'which', 'whose', 'that'],
        correctIndex: 3,
      ),
    ],
  ),
];

// QuizQuestion은 더 이상 샘플로 사용하지 않음 — Gemini가 실시간 생성
final sampleQuiz = QuizQuestion(
  question: '(데모용) 이 문제는 사용되지 않습니다.',
  options: ['', '', '', ''],
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
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.light(
          surface: kBg,
          primary: kPrimary,
          secondary: kPrimaryLight,
          onSurface: kFg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          elevation: 0,
          iconTheme: IconThemeData(color: kFg),
          titleTextStyle: TextStyle(
            color: kFg, fontSize: 20, fontWeight: FontWeight.bold,
          ),
        ),
        dividerColor: kBorder,
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: kMuted),
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

  // 학습자료 목록 — AI 요약 결과가 여기에 추가됨
  final List<StudyMaterial> _materials = List.from(_initialMaterials);

  // 알람 목록
  final List<AlarmModel> _alarms = List.from(_initialAlarms);

  // 학습자료가 추가될 때 목록 앞에 삽입
  void _onMaterialAdded(StudyMaterial material) {
    setState(() => _materials.insert(0, material));
  }

  Widget _buildScreen(BuildContext context) {
    switch (_tab) {
      case 0:
        return HomeScreen(
          onTabChange: (i) => setState(() => _tab = i.clamp(0, 3)),
          alarms: _alarms,
          materials: _materials,
          onDemoAlarm: (alarm, material) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlarmRingingScreen(alarm: alarm, material: material),
            ),
          ),
        );

      case 1:
        return AlarmListScreen(
          alarms: _alarms,
          materials: _materials,
          onAdd: () async {
            final alarm = await Navigator.push<AlarmModel>(
              context,
              MaterialPageRoute(
                builder: (_) => AlarmAddScreen(materials: _materials),
              ),
            );
            if (alarm != null) setState(() => _alarms.add(alarm));
          },
        );

      case 2:
        return StudyMaterialScreen(
          materials: _materials,
          onSummary: (m) => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AiSummaryScreen(material: m),
          )),
          onMaterialAdded: _onMaterialAdded, // AI 요약 완료 시 목록에 추가
        );

      case 3:
        return const MyPageScreen();

      default:
        return HomeScreen(
          onTabChange: (_) {},
          alarms: _alarms,
          materials: _materials,
          onDemoAlarm: (_, __) {},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(context),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: kCard,
          selectedItemColor: kPrimary,
          unselectedItemColor: kMuted,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_outlined),
              activeIcon: Icon(Icons.alarm),
              label: '알람 설정',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'AI학습',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '마이페이지',
            ),
          ],
        ),
      ),
    );
  }
}
