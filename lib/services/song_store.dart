import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// AI로 만든 노래(가사+음원 파일 경로)를 기기에 영구 저장한다.
///
/// 오디오 파일 자체는 이미 AiSummaryScreen이 로컬 파일로 저장해두지만, "이 자료(material_id)는
/// 이미 노래가 있다"는 연결 정보는 지금까지 메모리(StudyMaterial.songPath 필드)에만 있었다 -
/// 백엔드 study_materials 테이블에는 이 필드가 아예 없어서(서버가 모르는 로컬 전용 값), 앱을
/// 완전히 재시작(hot restart 포함)하면 그 연결이 사라져서 매번 새로 만들어야 하는 것처럼
/// 보였다. 이 파일이 그 연결 정보를 기기 로컬 JSON 파일로 남겨서 앱 재시작 후에도
/// AppData.loadAll()이 다시 읽어와 복원할 수 있게 한다.
class SongStore {
  static Future<File> _indexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/song_index.json');
  }

  static Future<Map<String, dynamic>> _readIndex() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeIndex(Map<String, dynamic> index) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(index));
  }

  /// material_id에 대해 새로 만든 노래 정보(파일 경로/가사)를 저장.
  static Future<void> save(int materialId, {required String songPath, required String lyrics}) async {
    final index = await _readIndex();
    index['$materialId'] = {'path': songPath, 'lyrics': lyrics};
    await _writeIndex(index);
  }

  /// material_id에 저장된 노래 정보를 가져온다. 파일이 실제로 없어졌으면(기기 저장공간 정리 등)
  /// null을 돌려준다 - 그래야 "노래 있다고 나오는데 재생은 안 되는" 상황을 막는다.
  static Future<({String path, String lyrics})?> get(int materialId) async {
    final index = await _readIndex();
    final entry = index['$materialId'];
    if (entry == null) return null;
    final path = entry['path'] as String?;
    if (path == null || !await File(path).exists()) return null;
    return (path: path, lyrics: (entry['lyrics'] as String?) ?? '');
  }

  static Future<void> remove(int materialId) async {
    final index = await _readIndex();
    if (index.remove('$materialId') != null) {
      await _writeIndex(index);
    }
  }
}
