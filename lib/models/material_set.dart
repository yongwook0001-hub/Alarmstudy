import 'study_material.dart';

/// 학습자료 "폴더" 하나 = 백엔드의 세트(MaterialSet) 하나.
/// 폴더 안에 PDF(StudyMaterial)를 최대 5개까지 담을 수 있다 (서버 제약).
///
/// 목록 화면(GET /api/sets)에서는 materialCount만 알 수 있고 materials는 비어있다 -
/// 폴더를 열 때(GET /api/sets/{id}) [materials]를 채워 넣는다 (AppData.loadSetDetail 참고).
class MaterialSet {
  final int id;
  String title;
  int materialCount;
  final DateTime createdAt;
  DateTime updatedAt;
  List<StudyMaterial> materials;

  MaterialSet({
    required this.id,
    required this.title,
    required this.materialCount,
    required this.createdAt,
    required this.updatedAt,
    List<StudyMaterial>? materials,
  }) : materials = materials ?? [];

  factory MaterialSet.fromListJson(Map<String, dynamic> json) {
    return MaterialSet(
      id: json['id'],
      title: json['title'] ?? '',
      materialCount: json['material_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory MaterialSet.fromDetailJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final materialsJson = (json['materials'] as List? ?? []);
    return MaterialSet(
      id: id,
      title: json['title'] ?? '',
      materialCount: materialsJson.length,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      materials: materialsJson
          .map((m) => StudyMaterial.fromJson(m as Map<String, dynamic>, setId: id))
          .toList(),
    );
  }

  /// 이 세트 안에서 이미 노래가 만들어진 자료들 (알람 알람음 선택용).
  List<StudyMaterial> get materialsWithSong => materials.where((m) => m.songPath != null).toList();

  bool get hasReadyMaterial => materials.any((m) => m.isReady);
}
