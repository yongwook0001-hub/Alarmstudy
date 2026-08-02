import '../models/material_set.dart';
import 'api_client.dart';

/// server/app/api/sets.py (POST/GET/PATCH/DELETE /api/sets) 호출 담당.
/// "세트"는 화면에서는 "폴더"로 표시된다 (study_material_screen.dart 참고).
class SetsService {
  static Future<List<MaterialSet>> list() async {
    final data = await ApiClient.get('/api/sets') as List;
    return data.map((j) => MaterialSet.fromListJson(j as Map<String, dynamic>)).toList();
  }

  static Future<MaterialSet> create(String title) async {
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
    final data = await ApiClient.get('/api/sets/$setId');
    return MaterialSet.fromDetailJson(data as Map<String, dynamic>);
  }

  static Future<void> rename(int setId, String title) => ApiClient.patch('/api/sets/$setId', body: {'title': title});

  static Future<void> delete(int setId) => ApiClient.delete('/api/sets/$setId');
}
