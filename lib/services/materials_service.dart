import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'sets_service.dart';

/// server/app/api/materials.py 호출 담당 - PDF 업로드는 서버를 거치지 않고
/// presigned URL로 S3에 직접 PUT한다 (server/app/services/s3.py 참고):
///   1) POST /api/sets/{set_id}/materials/presigned-url → {material_id, upload_url, s3_key}
///   2) upload_url에 PDF 바이트를 그대로 PUT (Content-Type 헤더 없이 - s3.py의 주석 참고,
///      presigned 서명에 Content-Type을 포함하지 않았으므로 헤더를 붙이면 오히려 서명이 안 맞음)
///   3) POST /api/materials/{material_id}/upload-complete → 서버가 백그라운드로 파싱 시작
///   4) GET /api/sets/{set_id} 폴링 - upload_status가 ready/parse_failed가 될 때까지 대기
class MaterialsService {
  static const _pollInterval = Duration(seconds: 2);
  static const _pollTimeout = Duration(seconds: 60);

  /// 전체 업로드 플로우를 한 번에 수행한다. 반환값은 새로 생긴 material_id.
  ///
  /// upload-complete 통보 후에는 서버가 BackgroundTasks로 파싱+요약을 진행하므로,
  /// 세트 상세를 폴링해서 upload_status가 'ready'/'parse_failed'로 바뀔 때까지 기다린 뒤
  /// 반환한다 (최대 60초 - 그래도 안 끝나면 '분석 중' 상태인 채로 반환하고, 화면의
  /// 새로고침 버튼(AiSummaryScreen._refreshStatus)으로 나중에 다시 확인할 수 있다).
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

    // S3 presigned URL은 인증 헤더가 있으면 서명 검증에 실패하므로 ApiClient가 아니라
    // 순수 http.put을 그대로 쓴다 (Authorization 헤더를 붙이지 않음).
    final putResponse = await http.put(Uri.parse(uploadUrl), body: bytes);
    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw Exception('S3 업로드 실패 (코드 ${putResponse.statusCode})');
    }

    await ApiClient.post('/api/materials/$materialId/upload-complete');
    await _waitUntilProcessed(setId: setId, materialId: materialId);
    return materialId;
  }

  static Future<void> _waitUntilProcessed({required int setId, required int materialId}) async {
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_pollInterval);
      final detail = await SetsService.detail(setId);
      final match = detail.materials.where((m) => m.id == materialId);
      if (match.isEmpty) continue;
      final status = match.first.uploadStatus;
      if (status == 'ready' || status == 'parse_failed') return;
    }
  }

  static Future<void> delete(int materialId) => ApiClient.delete('/api/materials/$materialId');
}
