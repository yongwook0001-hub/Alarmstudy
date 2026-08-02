import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// server/app/api/materials.py 호출 담당 - PDF 업로드는 서버를 거치지 않고
/// presigned URL로 S3에 직접 PUT한다 (server/app/services/s3.py 참고):
///   1) POST /api/sets/{set_id}/materials/presigned-url → {material_id, upload_url, s3_key}
///   2) upload_url에 PDF 바이트를 그대로 PUT (Content-Type 헤더 없이 - s3.py의 주석 참고,
///      presigned 서명에 Content-Type을 포함하지 않았으므로 헤더를 붙이면 오히려 서명이 안 맞음)
///   3) POST /api/materials/{material_id}/upload-complete → 서버가 백그라운드로 파싱 시작
class MaterialsService {
  /// 전체 업로드 플로우를 한 번에 수행한다. 반환값은 새로 생긴 material_id.
  static Future<int> uploadPdf({
    required int setId,
    required String fileName,
    required Uint8List bytes,
    bool isMain = false,
  }) async {
    final presign = await ApiClient.post(
      '/api/sets/$setId/materials/presigned-url',
      body: {'file_name': fileName, 'file_size_bytes': bytes.length, 'is_main': isMain},
    );

    final materialId = presign['material_id'] as int;
    final uploadUrl = presign['upload_url'] as String;

    final putResponse = await http.put(Uri.parse(uploadUrl), body: bytes);
    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw Exception('S3 업로드 실패 (코드 ${putResponse.statusCode})');
    }

    await ApiClient.post('/api/materials/$materialId/upload-complete');
    return materialId;
  }

  static Future<void> delete(int materialId) => ApiClient.delete('/api/materials/$materialId');
}
