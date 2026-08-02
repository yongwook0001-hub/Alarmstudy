import 'dart:async';
import 'package:alarm/alarm.dart';
// AlarmSet은 alarm.dart 배럴 파일에서 재수출되지 않아서 따로 import 필요
// (패키지 소스 기준 lib/utils/alarm_set.dart에 정의돼 있음).
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'models/alarm_model.dart';
import 'models/material_set.dart';
import 'screens/home/home_screen.dart';
import 'screens/alarm/alarm_list_screen.dart';
import 'screens/alarm/alarm_add_screen.dart';
import 'screens/study_material/study_material_screen.dart';
import 'screens/alarm/alarm_ringing_screen.dart';
import 'screens/my_page/my_page_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/alarm_scheduler.dart';
import 'services/auth_service.dart';
import 'services/user_session.dart';
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
          home: const AuthGate(),
        );
      },
    );
  }
}

/// 앱 시작 시 저장된 로그인 토큰이 아직 유효한지 확인해서, 유효하면 바로 MainShell로,
/// 아니면 로그인 화면으로 보낸다. 백엔드 대부분의 API가 로그인(Bearer 토큰)을 요구하기
/// 때문에 — 목업 데이터로 로그인 없이 둘러볼 수 있던 예전과 달리 — 이제 로그인이 필수다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _GateState { checking, loggedIn, loggedOut }

class _AuthGateState extends State<AuthGate> {
  _GateState _state = _GateState.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      setState(() => _state = _GateState.loggedOut);
      return;
    }
    try {
      final user = await AuthService.getMe();
      UserSession.set(user);
      if (mounted) setState(() => _state = _GateState.loggedIn);
    } catch (_) {
      // 토큰 만료/무효 - 다시 로그인해야 함.
      if (mounted) setState(() => _state = _GateState.loggedOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.checking:
        return Scaffold(
          backgroundColor: kBg,
          body: const Center(child: CircularProgressIndicator()),
        );
      case _GateState.loggedIn:
        return const MainShell();
      case _GateState.loggedOut:
        return const LoginScreen();
    }
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  bool _loading = true;
  String? _loadError;

  // 알람/세트 목록 + 서버 동기화 + 실제 기기 알람 예약 로직은 AppData 하나에 모아둠
  // (state/app_data.dart 참고). 여기서는 언제 다시 그릴지(setState)만 신경 쓴다.
  final _appData = AppData();

  StreamSubscription<AlarmSet>? _ringSub;

  @override
  void initState() {
    super.initState();
    _init();
    // 실제로 알람이 울리는 시점(앱이 켜져있는 동안 포함)을 감지해서
    // AlarmRingingScreen(퀴즈 풀어야 꺼지는 화면)으로 이동시킴.
    _ringSub = Alarm.ringing.listen(_onAlarmRinging);
  }

  Future<void> _init() async {
    // 앱 시작 시: 정확한 알람 권한 요청 + 서버에서 알람/세트 로드 + 재예약까지 한 번에.
    await AlarmScheduler.requestExactAlarmPermission();
    await _appData.loadAll();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadError = _appData.loadError;
    });
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

      final set = _appData.findSet(alarm.setId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlarmRingingScreen(alarm: alarm, set: set, streakDays: 7),
        ),
      );
    }
  }

  void _retryInit() {
    setState(() => _loading = true);
    _init();
  }

  Future<void> _reloadSet(int setId) async {
    await _appData.refreshSetDetail(setId);
    if (mounted) setState(() {});
  }

  Future<void> _createFolder(String title) async {
    await _appData.addSet(title);
    if (mounted) setState(() {});
  }

  Future<void> _deleteFolder(int setId) async {
    await _appData.deleteSet(setId);
    if (mounted) setState(() {});
  }

  Widget _buildScreen(BuildContext context) {
    switch (_tab) {
      case 0:
        return HomeScreen(
          onTabChange: (i) => setState(() => _tab = i.clamp(0, 3)),
          alarms: _appData.alarms,
          sets: _appData.sets,
        );

      case 1:
        return AlarmListScreen(
          alarms: _appData.alarms,
          sets: _appData.sets,
          onAdd: () async {
            final alarm = await Navigator.push<AlarmModel>(
              context,
              MaterialPageRoute(
                builder: (_) => AlarmAddScreen(sets: _appData.sets),
              ),
            );
            if (alarm != null) {
              await _appData.addAlarm(alarm);
              if (mounted) setState(() {});
            }
          },
          onToggle: (alarm) async {
            await _appData.updateAlarm(alarm);
            if (mounted) setState(() {});
          },
          onDelete: (alarm) async {
            await _appData.deleteAlarm(alarm.id);
            if (mounted) setState(() {});
          },
        );

      case 2:
        return StudyMaterialScreen(
          sets: _appData.sets,
          onCreateFolder: _createFolder,
          onDeleteFolder: _deleteFolder,
          onSetChanged: _reloadSet,
        );

      case 3:
        return const MyPageScreen();

      default:
        return HomeScreen(
          onTabChange: (_) {},
          alarms: _appData.alarms,
          sets: _appData.sets,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('데이터를 불러오지 못했어요.\n$_loadError',
                    textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryInit,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
