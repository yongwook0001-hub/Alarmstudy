/// 세트(MaterialSet) 안에 들어있는 PDF 파일 한 건.
/// 백엔드 GET /api/sets/{id} 응답의 MaterialNested를 그대로 반영한다.
///
/// 주의: 백엔드에는 "제목/핵심포인트/퀴즈미리보기/정답률" 같은 필드가 없다 -
/// 퀴즈는 이 자료에 즉시 딸려있는 게 아니라 서버가 백그라운드에서 만들어
/// 세트 단위 버퍼에 쌓아두고, 알람이 울릴 때(POST /api/sessions)만 꺼내준다.
/// 그래서 이 모델은 "업로드 상태 + 요약"까지만 표현한다 (기존의 즉석 요약+퀴즈
/// 미리보기 필드들은 실제 백엔드 계약에 없어서 제거했다).
class StudyMaterial {
  final int id;
  final int setId;
  final bool isMain;
  final String fileName;
  final int fileSizeBytes;

  /// pending(업로드 URL만 발급됨) → uploaded(S3 업로드 완료, 파싱 대기)
  /// → ready(요약 완료) | parse_failed(파싱 실패)
  String uploadStatus;
  final int? pageCount;
  String? summary;
  final DateTime createdAt;

  // AI가 이 자료의 요약으로 만들어준 노래 - 없으면 아직 생성 안 한 것.
  // 기기 로컬 파일 경로라서 서버에는 저장되지 않는다(재설치/기기변경 시 유실됨) - 알려진 한계.
  String? songPath;
  String? songLyrics;

  StudyMaterial({
    required this.id,
    required this.setId,
    required this.isMain,
    required this.fileName,
    required this.fileSizeBytes,
    required this.uploadStatus,
    this.pageCount,
    this.summary,
    required this.createdAt,
    this.songPath,
    this.songLyrics,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json, {required int setId}) {
    return StudyMaterial(
      id: json['id'],
      setId: setId,
      isMain: json['is_main'] ?? false,
      fileName: json['file_name'] ?? '',
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      uploadStatus: json['upload_status'] ?? 'pending',
      pageCount: json['page_count'],
      summary: json['summary'],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// 확장자를 뗀 파일명 - 화면 제목으로 사용.
  String get displayTitle {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  String get dateLabel => createdAt.toString().substring(0, 10);

  bool get isReady => uploadStatus == 'ready';
  bool get isFailed => uploadStatus == 'parse_failed';
  bool get isProcessing => uploadStatus == 'pending' || uploadStatus == 'uploaded';

  String get statusLabel {
    switch (uploadStatus) {
      case 'ready':
        return '요약 완료';
      case 'parse_failed':
        return '분석 실패';
      default:
        return '분석 중';
    }
  }
}
