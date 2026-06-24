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
  WidgetsFlutterBinding.ensureInitialized();  // ← 추가
  await dotenv.load(fileName: '.env');         // ← 추가

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

  Widget _buildScreen(BuildContext context) {
    switch (_tab) {
      case 0:
        return HomeScreen(onTabChange: (i) {
          if (i == 5) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => AlarmRingingScreen(alarm: sampleAlarms[0]),
            ));
          } else {
            setState(() => _tab = i.clamp(0, 3));
          }
        });
      case 1:
        return AlarmListScreen(
          alarms: sampleAlarms,
          onAdd: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AlarmAddScreen(),
          )),
        );
      case 2:
        return StudyMaterialScreen(
          materials: sampleMaterials,
          onSummary: (m) => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AiSummaryScreen(material: m),
          )),
        );
      case 3:
        return const MyPageScreen();
      default:
        return HomeScreen(onTabChange: (_) {});
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