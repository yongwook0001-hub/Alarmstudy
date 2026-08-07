import '../models/material_set.dart';
import '../models/study_material.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// server/app/api/sets.py (POST/GET/PATCH/DELETE /api/sets) 호출 담당.
/// "세트"는 화면에서는 "폴더"로 표시된다 (study_material_screen.dart 참고).
/// 테스트 모드에서는 인메모리 목록으로 대체한다.
class SetsService {
  static final List<MaterialSet> _testSets = [];
  static int _nextId = 1;
  static int _nextMaterialId = 1;

  static Future<List<MaterialSet>> list() async {
    if (AuthService.isTestModeEnabled) {
      return _testSets.map(_cloneListItem).toList();
    }
    final data = await ApiClient.get('/api/sets') as List;
    return data.map((j) => MaterialSet.fromListJson(j as Map<String, dynamic>)).toList();
  }

  static Future<MaterialSet> create(String title) async {
    if (AuthService.isTestModeEnabled) {
      final now = DateTime.now();
      final created = MaterialSet(
        id: _nextId++,
        title: title,
        materialCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      _testSets.insert(0, created);
      return _cloneDetail(created);
    }
    final data = await ApiClient.post('/api/sets', body: {'title': title});
    return MaterialSet(
      id: data['id'],
      title: data['title'],
      materialCount: 0,
      createdAt: DateTime.parse(data['created_at']),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }

  static Future<MaterialSet> detail(int setId) async {
    if (AuthService.isTestModeEnabled) {
      final idx = _testSets.indexWhere((s) => s.id == setId);
      if (idx == -1) throw Exception('테스트 세트를 찾을 수 없습니다.');
      return _cloneDetail(_testSets[idx]);
    }
    final data = await ApiClient.get('/api/sets/$setId');
    return MaterialSet.fromDetailJson(data as Map<String, dynamic>);
  }

  static Future<void> rename(int setId, String title) async {
    if (AuthService.isTestModeEnabled) {
      final idx = _testSets.indexWhere((s) => s.id == setId);
      if (idx == -1) throw Exception('테스트 세트를 찾을 수 없습니다.');
      _testSets[idx].title = title;
      _testSets[idx].updatedAt = DateTime.now();
      return;
    }
    await ApiClient.patch('/api/sets/$setId', body: {'title': title});
  }

  static Future<void> delete(int setId) async {
    if (AuthService.isTestModeEnabled) {
      _testSets.removeWhere((s) => s.id == setId);
      return;
    }
    await ApiClient.delete('/api/sets/$setId');
  }

  /// 테스트 모드 전용: 서버/S3 없이 PDF 자료를 세트에 바로 붙인다.
  static int addTestMaterial({
    required int setId,
    required String fileName,
    required int fileSizeBytes,
    bool isMain = false,
  }) {
    final idx = _testSets.indexWhere((s) => s.id == setId);
    if (idx == -1) throw Exception('테스트 세트를 찾을 수 없습니다. 먼저 폴더를 만들어주세요.');

    final set = _testSets[idx];
    final material = StudyMaterial(
      id: _nextMaterialId++,
      setId: setId,
      isMain: isMain || set.materials.isEmpty,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      uploadStatus: 'ready',
      pageCount: 1,
      summary: '테스트 모드 요약입니다. "$fileName" 업로드를 로컬에서만 시뮬레이션했습니다.\n'
          '실제 서버 파싱/Gemini 요약은 USE_TEST_MODE=false 후 로그인해서 확인하세요.',
      createdAt: DateTime.now(),
    );
    set.materials.add(material);
    set.materialCount = set.materials.length;
    set.updatedAt = DateTime.now();
    return material.id;
  }

  /// 테스트 모드 전용: 세트에서 자료 제거.
  static void removeTestMaterial(int materialId) {
    for (final set in _testSets) {
      final before = set.materials.length;
      set.materials.removeWhere((m) => m.id == materialId);
      if (set.materials.length != before) {
        set.materialCount = set.materials.length;
        set.updatedAt = DateTime.now();
        return;
      }
    }
  }

  static MaterialSet _cloneListItem(MaterialSet s) => MaterialSet(
        id: s.id,
        title: s.title,
        materialCount: s.materialCount,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static MaterialSet _cloneDetail(MaterialSet s) => MaterialSet(
        id: s.id,
        title: s.title,
        materialCount: s.materialCount,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
        materials: List.of(s.materials),
      );
}
