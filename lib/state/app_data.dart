import '../models/alarm_model.dart';
import '../models/alarm_sound.dart';
import '../models/material_set.dart';
import '../models/study_material.dart';
import '../services/alarm_scheduler.dart';
import '../services/alarm_sound_store.dart';
import '../services/alarms_service.dart';
import '../services/sets_service.dart';
import '../services/song_store.dart';

/// 알람/학습자료(세트) 목록 + 그에 딸린 사이드이펙트(서버 동기화, 실제 기기 알람 예약)를
/// 한 곳에서 관리.
///
/// UI를 언제 다시 그릴지는 여전히 이 클래스를 쓰는 쪽(main.dart의 _MainShellState)의
/// setState가 책임진다 — 이 클래스는 "무엇이 바뀌는지"만 담당하고 리빌드 시점은
/// 신경 쓰지 않는다 (그래서 ChangeNotifier가 아닌 평범한 클래스로 뒀다).
///
/// 주의: alarms/sets 리스트와 그 안의 객체들은 절대 복사해서 쓰면 안 됨 — 자식 화면들이
/// 리스트 안의 객체를 직접 mutate하기 때문에, 같은 참조를 계속 들고 있어야 그 변경이
/// 다른 화면에도 그대로 반영된다.
///
/// 로그인이 필요한 API만 호출하므로 이 클래스의 메서드는 로그인 이후에만 호출돼야 한다
/// (main.dart의 AuthGate 참고).
class AppData {
  List<AlarmModel> alarms = [];
  List<MaterialSet> sets = [];

  bool isLoading = false;
  String? loadError;

  /// 앱 시작(로그인 직후) 시 서버에서 알람/세트 목록을 전부 불러오고,
  /// 활성 알람을 전부 "다음 발생 시각" 기준으로 재예약한다.
  Future<void> loadAll() async {
    isLoading = true;
    loadError = null;
    try {
      final loadedAlarms = await AlarmsService.list();
      // customSoundPath는 서버에 없는 로컬 전용 값이라 AlarmModel.fromJson에는
      // 안 들어있다 - AlarmSoundStore(기기 로컬)에서 복원해야 재시작 후에도
      // AI 노래 알람음 연결이 유지된다.
      for (final a in loadedAlarms) {
        if (a.soundId == kCustomSongSoundId) {
          a.customSoundPath = await AlarmSoundStore.get(a.id);
        }
      }
      final setList = await SetsService.list();
      // 목록 API(GET /api/sets)는 자료 개수만 알려주고 내용은 안 주므로, 폴더 카드/알람 추가
      // 화면의 자료 목록/알람음 선택을 위해 세트별 상세를 미리 다 불러온다.
      final detailedSets = await Future.wait(setList.map((s) => SetsService.detail(s.id)));
      // 노래(songPath/songLyrics)는 서버에 없는 로컬 전용 값이라, 기기에 저장해둔
      // song_index.json(SongStore)에서 복원한다 - 안 하면 앱을 재시작할 때마다
      // "노래 만들기" 버튼이 다시 나타나서 매번 새로 만들어야 하는 것처럼 보인다.
      for (final set in detailedSets) {
        for (final m in set.materials) {
          await _hydrateSong(m);
        }
      }
      alarms = loadedAlarms;
      sets = detailedSets;
    } catch (e) {
      loadError = e.toString();
    } finally {
      isLoading = false;
    }
    await rescheduleAll();
  }

  Future<void> rescheduleAll() => AlarmScheduler.rescheduleAll(alarms);

  // ── 알람 ──────────────────────────────────────────────────────
  Future<void> addAlarm(AlarmModel draft) async {
    final created = await AlarmsService.create(draft);
    // 서버 응답(created)에는 customSoundPath가 없으므로(로컬 전용 값) 방금 사용자가
    // 고른 값을 그대로 옮겨 붙이고, 기기 로컬에도 저장해서 재시작 후에도 복원되게 한다.
    created.customSoundPath = draft.customSoundPath;
    await _persistCustomSound(created);
    alarms.insert(0, created);
    await AlarmScheduler.schedule(created);
  }

  Future<void> updateAlarm(AlarmModel alarm) async {
    final updated = await AlarmsService.update(alarm);
    updated.customSoundPath = alarm.customSoundPath; // 위 addAlarm과 동일한 이유
    await _persistCustomSound(updated);
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx != -1) alarms[idx] = updated;
    await AlarmScheduler.schedule(updated);
  }

  Future<void> deleteAlarm(int id) async {
    await AlarmsService.delete(id);
    alarms.removeWhere((a) => a.id == id);
    await AlarmScheduler.cancel(id);
    await AlarmSoundStore.remove(id);
  }

  /// 알람의 커스텀 알람음(AI 노래) 경로를 AlarmSoundStore에 저장/삭제한다.
  Future<void> _persistCustomSound(AlarmModel alarm) async {
    if (alarm.soundId == kCustomSongSoundId && alarm.customSoundPath != null) {
      await AlarmSoundStore.save(alarm.id, alarm.customSoundPath!);
    } else {
      await AlarmSoundStore.remove(alarm.id);
    }
  }

  // ── 세트(폴더) ─────────────────────────────────────────────────
  Future<MaterialSet> addSet(String title) async {
    final created = await SetsService.create(title);
    sets.insert(0, created);
    return created;
  }

  Future<void> deleteSet(int id) async {
    await SetsService.delete(id);
    sets.removeWhere((s) => s.id == id);
    // 서버에서 alarms.set_id는 FK SET NULL로 강등되므로 로컬 상태도 맞춰준다.
    for (final a in alarms) {
      if (a.setId == id) a.setId = null;
    }
  }

  /// 세트에 자료를 새로 올리거나 삭제한 뒤 그 세트의 상세(materials 목록/요약 상태)를
  /// 서버에서 다시 불러와 갱신한다.
  ///
  /// 주의(중요): 기존 MaterialSet "객체 자체"를 새 객체로 바꿔치기하면 안 된다 — 이미
  /// FolderDetailScreen/AlarmAddScreen 등 다른 화면이 지금 이 객체(참조)를 들고 있는데,
  /// 통째로 교체해버리면 그 화면들은 여전히 옛날(끊어진) 객체를 보게 된다. 그래서
  /// 기존 객체의 필드(특히 materials 리스트)만 갱신하고, 노래(songPath/songLyrics - 서버에
  /// 없는 로컬 전용 값)는 기존 자료 객체에서 새로 받아온 자료 객체로 옮겨 붙인다.
  Future<void> refreshSetDetail(int setId) async {
    final detail = await SetsService.detail(setId);
    final idx = sets.indexWhere((s) => s.id == setId);

    if (idx == -1) {
      sets.insert(0, detail);
      return;
    }

    final existing = sets[idx];
    for (final m in detail.materials) {
      final prevMatches = existing.materials.where((p) => p.id == m.id);
      if (prevMatches.isNotEmpty && prevMatches.first.songPath != null) {
        m.songPath = prevMatches.first.songPath;
        m.songLyrics = prevMatches.first.songLyrics;
      } else {
        await _hydrateSong(m);
      }
    }
    existing.title = detail.title;
    existing.materialCount = detail.materialCount;
    existing.updatedAt = detail.updatedAt;
    existing.materials = detail.materials; // existing(=MaterialSet) 객체 자체의 참조는 유지한 채 내용만 교체
  }

  /// 기기에 저장해둔 노래 정보(SongStore)를 자료 객체에 복원한다. 이미 만든 노래가 없으면 아무것도 안 함.
  Future<void> _hydrateSong(StudyMaterial m) async {
    final saved = await SongStore.get(m.id);
    if (saved != null) {
      m.songPath = saved.path;
      m.songLyrics = saved.lyrics;
    }
  }

  AlarmModel? findAlarm(int id) {
    for (final a in alarms) {
      if (a.id == id) return a;
    }
    return null;
  }

  MaterialSet? findSet(int? id) {
    if (id == null) return null;
    for (final s in sets) {
      if (s.id == id) return s;
    }
    return null;
  }
}
