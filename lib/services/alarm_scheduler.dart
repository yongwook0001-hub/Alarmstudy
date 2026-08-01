import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/alarm_model.dart';
import '../models/alarm_sound.dart';

/// AlarmModel(요일 반복 정보를 가진 앱 내부 모델)을 실제 기기 알람(alarm 패키지)으로
/// 변환/예약하는 역할.
///
/// alarm 패키지는 "반복 알람"을 직접 지원하지 않고 1회성 알람만 예약할 수 있어서
/// (공식 FAQ 권장 방식), 매번 "다음으로 가장 가까운 발생 시각" 1건만 예약하고,
/// 그 알람이 울린 뒤(main.dart의 Alarm.ringing 리스너 → AlarmRingingScreen 종료 시점)
/// 또는 앱이 새로 시작될 때 다시 schedule()을 호출해서 그다음 회차를 이어서 예약한다.
class AlarmScheduler {
  AlarmScheduler._();

  static Future<void> init() async {
    await Alarm.init();
  }

  /// Android 12+ 에서는 "정확한 알람" 권한을 사용자가 따로 허용해야
  /// 설정한 시간에 정확히 울릴 수 있음.
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// alarm.days(한글 요일 목록)와 alarm.time("HH:mm")을 바탕으로
  /// 지금(now) 이후 가장 가까운 미래의 발생 시각을 계산한다.
  /// days가 비어있으면 "매일 반복"으로 취급한다.
  static DateTime nextOccurrence(AlarmModel alarm, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final parts = alarm.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // DateTime.weekday: 1=월요일 ... 7=일요일
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    for (int addDays = 0; addDays < 8; addDays++) {
      final date = now.add(Duration(days: addDays));
      final label = weekdayLabels[date.weekday - 1];
      if (alarm.days.isNotEmpty && !alarm.days.contains(label)) continue;

      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (candidate.isAfter(now)) return candidate;
    }
    // 이론상 도달 안 함 (days가 비어있지 않은 채로 8일 안에 못 찾는 경우는 없음) -
    // 방어적으로 내일 같은 시간을 반환.
    final fallback = now.add(const Duration(days: 1));
    return DateTime(fallback.year, fallback.month, fallback.day, hour, minute);
  }

  /// soundId/customSoundPath로부터 alarm 패키지에 넘길 오디오 경로를 결정.
  /// - 기본 알람음: pubspec에 등록된 에셋 경로 그대로 (예: 'assets/sounds/default.wav')
  /// - AI 생성 노래: 기기에 저장된 로컬 파일의 절대경로
  static String _resolveSoundPath(AlarmModel alarm) {
    if (alarm.soundId == kCustomSongSoundId && alarm.customSoundPath != null) {
      return alarm.customSoundPath!;
    }
    return findAlarmSound(alarm.soundId).assetPath;
  }

  /// 알람 하나를 실제로 예약(또는, active가 false면 예약 취소)한다.
  static Future<void> schedule(AlarmModel alarm) async {
    if (!alarm.active) {
      await Alarm.stop(alarm.id);
      return;
    }

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarm.id,
        dateTime: nextOccurrence(alarm),
        assetAudioPath: _resolveSoundPath(alarm),
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 5),
        ),
        notificationSettings: NotificationSettings(
          title: alarm.label,
          body: '퀴즈를 풀어야 알람이 꺼져요',
          stopButton: '앱 열기',
        ),
      ),
    );
  }

  /// 앱 시작 시 활성화된 알람들을 전부 다시 예약 (기기가 재부팅됐거나
  /// 앱이 오래 꺼져 있었어도 다음 발생 시각 기준으로 최신화하기 위함).
  static Future<void> rescheduleAll(List<AlarmModel> alarms) async {
    for (final alarm in alarms) {
      await schedule(alarm);
    }
  }

  /// "5분 후 다시 알림" 스누즈 - 반복 스케줄과 별개로 지정된 시간 뒤에 1회만 울림.
  static Future<void> snooze(AlarmModel alarm, {Duration duration = const Duration(minutes: 5)}) async {
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarm.id,
        dateTime: DateTime.now().add(duration),
        assetAudioPath: _resolveSoundPath(alarm),
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 5),
        ),
        notificationSettings: NotificationSettings(
          title: alarm.label,
          body: '5분 후 다시 알림',
          stopButton: '앱 열기',
        ),
      ),
    );
  }

  static Future<void> cancel(int alarmId) => Alarm.stop(alarmId);
}
