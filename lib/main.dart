import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'models/alarm_model.dart';
import 'models/study_material.dart';
import 'screens/home/home_screen.dart';
import 'screens/alarm/alarm_list_screen.dart';
import 'screens/alarm/alarm_add_screen.dart';
import 'screens/study_material/study_material_screen.dart';
import 'screens/alarm/alarm_ringing_screen.dart';
import 'screens/my_page/my_page_screen.dart';
import 'services/alarm_scheduler.dart';
import 'state/app_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // 카카오 SDK 초기화 — .env의 KAKAO_NATIVE_APP_KEY 사용
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']);

  // 실제 기기 알람(백그라운드/종료 상태에서도 설정 시간에 울림) 초기화
  await AlarmScheduler.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AlarmStudyApp());
}

class AlarmStudyApp extends StatelessWidget {
  const AlarmStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeController.isDark가 바뀔 때마다 MaterialApp 전체를 새로 그려서
    // app_theme.dart의 kBg/kFg 등 getter들이 새 모드 값을 반영하도록 한다.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDark,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'AI학습 알람',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: kBg,
            colorScheme: ColorScheme(
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: kBg,
              primary: kPrimary,
              secondary: kPrimaryLight,
              onSurface: kFg,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              error: kRed,
              onError: Colors.white,
            ),
            appBarTheme: AppBarTheme(
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
      },
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

  // 알람/학습자료 목록 + 실제 기기 알람 예약 로직은 AppData 하나에 모아둠
  // (state/app_data.dart 참고). 여기서는 언제 다시 그릴지(setState)만 신경 쓴다.
  final _appData = AppData();

  StreamSubscription<AlarmSet>? _ringSub;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시: 정확한 알람 권한 요청 + 활성 알람 전부 "다음 발생 시각" 기준으로 재예약.
    // (기기 재부팅/장시간 미실행 후에도 스케줄이 최신 상태를 유지하도록)
    AlarmScheduler.requestExactAlarmPermission();
    _appData.rescheduleAll();

    // 실제로 알람이 울리는 시점(앱이 켜져있는 동안 포함)을 감지해서
    // AlarmRingingScreen(퀴즈 풀어야 꺼지는 화면)으로 이동시킴.
    _ringSub = Alarm.ringing.listen(_onAlarmRinging);
  }

  @override
  void dispose() {
    _ringSub?.cancel();
    super.dispose();
  }

  void _onAlarmRinging(AlarmSet alarmSet) {
    for (final settings in alarmSet.alarms) {
      final alarm = _appData.findAlarm(settings.id);
      if (alarm == null) continue;

      final material = _appData.findMaterial(alarm.materialId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlarmRingingScreen(alarm: alarm, material: material, streakDays: 7),
        ),
      );
    }
  }

  // 학습자료가 추가될 때 목록 앞에 삽입
  void _onMaterialAdded(StudyMaterial material) {
    setState(() => _appData.addMaterial(material));
  }

  // 학습자료 삭제 (AiSummaryScreen에서 휴지통 아이콘 눌렀을 때 호출됨)
  void _onMaterialDeleted(int id) {
    setState(() => _appData.deleteMaterial(id));
  }

  Widget _buildScreen(BuildContext context) {
    switch (_tab) {
      case 0:
        return HomeScreen(
          onTabChange: (i) => setState(() => _tab = i.clamp(0, 3)),
          alarms: _appData.alarms,
          materials: _appData.materials,
          onDemoAlarm: (alarm, material) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlarmRingingScreen(alarm: alarm, material: material, streakDays: 7),
            ),
          ),
        );

      case 1:
        return AlarmListScreen(
          alarms: _appData.alarms,
          materials: _appData.materials,
          onAdd: () async {
            final alarm = await Navigator.push<AlarmModel>(
              context,
              MaterialPageRoute(
                builder: (_) => AlarmAddScreen(materials: _appData.materials),
              ),
            );
            if (alarm != null) setState(() => _appData.addAlarm(alarm));
          },
          onToggle: (alarm) => AlarmScheduler.schedule(alarm),
        );

      case 2:
        return StudyMaterialScreen(
          materials: _appData.materials,
          onMaterialAdded: _onMaterialAdded,
          onMaterialDeleted: _onMaterialDeleted,
        );


      case 3:
        return const MyPageScreen();

      default:
        return HomeScreen(
          onTabChange: (_) {},
          alarms: _appData.alarms,
          materials: _appData.materials,
          onDemoAlarm: (_, __) {},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
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
