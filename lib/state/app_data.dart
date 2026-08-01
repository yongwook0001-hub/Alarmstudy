import '../data/sample_data.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';
import '../services/alarm_scheduler.dart';

/// 알람/학습자료 목록 + 그에 딸린 사이드이펙트(실제 기기 알람 예약 등)를 한 곳에서 관리.
///
/// UI를 언제 다시 그릴지는 여전히 이 클래스를 쓰는 쪽(main.dart의 _MainShellState)의
/// setState가 책임진다 — 이 클래스는 "무엇이 바뀌는지"만 담당하고 리빌드 시점은
/// 신경 쓰지 않는다 (그래서 ChangeNotifier가 아닌 평범한 클래스로 뒀다).
///
/// 주의: alarms/materials 리스트는 절대 복사해서 쓰면 안 됨 — AlarmListScreen의
/// Switch(alarm.active 직접 변경), AiSummaryScreen의 노래 생성(material.songPath 직접
/// 변경)처럼 자식 화면들이 리스트 안의 객체를 직접 mutate하기 때문에, 같은 참조를
/// 계속 들고 있어야 그 변경이 다른 화면에도 그대로 반영된다.
class AppData {
  final List<AlarmModel> alarms = List.from(initialAlarms);
  final List<StudyMaterial> materials = List.from(initialMaterials);

  /// 앱 시작 시 활성 알람 전부를 "다음 발생 시각" 기준으로 재예약.
  /// (기기 재부팅/장시간 미실행 후에도 스케줄이 최신 상태를 유지하도록)
  Future<void> rescheduleAll() => AlarmScheduler.rescheduleAll(alarms);

  void addAlarm(AlarmModel alarm) {
    alarms.add(alarm);
    AlarmScheduler.schedule(alarm);
  }

  // 학습자료가 추가될 때 목록 앞에 삽입
  void addMaterial(StudyMaterial material) {
    materials.insert(0, material);
  }

  // 학습자료 삭제 (AiSummaryScreen에서 휴지통 아이콘 눌렀을 때 호출됨)
  void deleteMaterial(int id) {
    materials.removeWhere((m) => m.id == id);
  }

  AlarmModel? findAlarm(int id) {
    for (final a in alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  StudyMaterial? findMaterial(int? id) {
    if (id == null) return null;
    for (final m in materials) {
      if (m.id == id) return m;
    }
    return null;
  }
}
