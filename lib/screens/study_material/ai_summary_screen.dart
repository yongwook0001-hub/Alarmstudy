import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/material_set.dart';
import '../../models/study_material.dart';
import '../../services/song_service.dart';
import '../../services/song_store.dart';
import '../../services/sets_service.dart';
import '../../services/stats_service.dart';

class AiSummaryScreen extends StatefulWidget {
  final StudyMaterial material;
  final MaterialSet set;
  final VoidCallback? onDelete;

  const AiSummaryScreen({super.key, required this.material, required this.set, this.onDelete});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  bool _generatingSong = false;
  String? _songError;
  final _player = AudioPlayer();
  bool _isPlaying = false;

  bool _refreshing = false;
  SetAnalysis? _analysis; // GET /api/sets/{id}/analysis 응답 (weak_topics/comment/세트 정답률)
  List<WrongAnswerItem> _wrongAnswers = [];

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    _loadAnalysis();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    try {
      final results = await Future.wait([
        StatsService.setAnalysis(widget.set.id),
        StatsService.wrongAnswers(setId: widget.set.id),
      ]);
      if (!mounted) return;
      setState(() {
        _analysis = results[0] as SetAnalysis;
        _wrongAnswers = (results[1] as List<WrongAnswerItem>)
            .where((w) => w.materialId == widget.material.id)
            .toList();
      });
    } catch (_) {
      // 통계 조회 실패는 화면 진입을 막지 않는다 - 카드가 "아직 없음" 상태로 남는다.
    }
  }

  /// PDF 분석(요약)이 아직 진행 중일 수 있어서 "새로고침"으로 상태를 다시 확인한다.
  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    try {
      final detail = await SetsService.detail(widget.set.id);
      final updated = detail.materials.where((m) => m.id == widget.material.id);
      if (updated.isNotEmpty && mounted) {
        setState(() {
          widget.material.uploadStatus = updated.first.uploadStatus;
          widget.material.summary = updated.first.summary;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('상태 확인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('삭제할까요?', style: TextStyle(color: kFg)),
        content: Text('"${widget.material.displayTitle}"을(를) 삭제하면 되돌릴 수 없어요.',
            style: TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete?.call();
  }

  /// AI 요약을 바탕으로 노래(가사+음원)를 생성해서 기기 로컬 파일로 저장하고
  /// material.songPath/songLyrics에 반영한다 (같은 StudyMaterial 인스턴스를
  /// FolderDetailScreen의 목록에서도 그대로 참조하고 있어서, 여기서 채워두면
  /// 알람 추가 화면(AlarmAddScreen)에서도 바로 선택 가능해진다).
  Future<void> _generateSong() async {
    setState(() {
      _generatingSong = true;
      _songError = null;
    });
    try {
      final song = await SongService.generate(
        subject: widget.set.title,
        summary: widget.material.summary ?? '',
        keyPoints: const [],
      );
      final dir = await getApplicationDocumentsDirectory();
      final ext = song.mimeType.contains('wav') ? 'wav' : 'mp3';
      final file = File('${dir.path}/song_material_${widget.material.id}.$ext');
      await file.writeAsBytes(song.audioBytes);

      // 기기 로컬에 "이 자료는 이미 노래가 있다"를 영구 저장 - 안 해두면 앱을 다시 시작할
      // 때마다(백엔드에 이 정보가 없어서) 매번 새로 만들어야 하는 것처럼 보인다.
      await SongStore.save(widget.material.id, songPath: file.path, lyrics: song.lyrics);

      setState(() {
        widget.material.songPath = file.path;
        widget.material.songLyrics = song.lyrics;
      });
    } catch (e) {
      setState(() => _songError = '노래 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _generatingSong = false);
    }
  }

  Future<void> _togglePlay() async {
    final path = widget.material.songPath;
    if (path == null) return;
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(path));
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: kFg, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Row(children: [
                  IconButton(
                    icon: _refreshing
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kMuted))
                        : Icon(Icons.refresh, color: kMuted),
                    onPressed: _refreshing ? null : _refreshStatus,
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: kMuted),
                      onPressed: () => _confirmDelete(context),
                    ),
                ]),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(widget.set.title, style: TextStyle(color: kPrimaryLight, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            Text(material.displayTitle,
                style: TextStyle(color: kFg, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            if (!material.isReady) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (material.isFailed ? kRed : kMuted).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (material.isFailed ? kRed : kMuted).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(material.isFailed ? Icons.error_outline : Icons.hourglass_top,
                      color: material.isFailed ? kRed : kMuted, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      material.isFailed
                          ? 'AI 분석에 실패했어요. 새로고침해도 안 되면 파일을 다시 올려주세요.'
                          : 'AI가 아직 분석 중이에요. 잠시 후 새로고침(우측 상단)해보세요.',
                      style: TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // AI 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: kPrimary, size: 16),
                  SizedBox(width: 8),
                  Text('AI가 핵심 내용을 자동 요약했습니다', style: TextStyle(color: kPrimaryLight, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),

              _card(
                title: '요약',
                child: Text(material.summary ?? '',
                    style: TextStyle(color: kFg, fontSize: 14, height: 1.7)),
              ),
              const SizedBox(height: 12),
            ],

            // AI 학습송 - 요약을 바탕으로 노래(가사+음원) 생성 (요약이 준비된 뒤에만 가능)
            _card(
              title: 'AI 학습송',
              child: !material.isReady
                  ? Text('요약이 완료된 뒤에 노래를 만들 수 있어요.', style: TextStyle(color: kMuted, fontSize: 13))
                  : material.songPath == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이 자료의 요약을 노래로 만들어서 알람음으로 쓸 수 있어요.',
                          style: TextStyle(color: kMuted, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _generatingSong ? null : _generateSong,
                          child: Container(
                            height: 44,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _generatingSong ? kPrimary.withOpacity(0.5) : kPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: _generatingSong
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.music_note, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('학습자료로 노래 만들기',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                        if (_songError != null) ...[
                          const SizedBox(height: 10),
                          Text(_songError!, style: TextStyle(color: kRed, fontSize: 12, height: 1.4)),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.check_circle, color: kGreen, size: 18),
                          const SizedBox(width: 8),
                          Text('노래가 만들어졌어요', style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                        if (material.songLyrics != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            material.songLyrics!,
                            style: TextStyle(color: kMuted, fontSize: 13, height: 1.6),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: kPrimary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(_isPlaying ? '정지' : '미리듣기',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _generatingSong ? null : _generateSong,
                            child: Text(
                              _generatingSong ? '다시 만드는 중...' : '다시 만들기',
                              style: TextStyle(color: kMuted, fontSize: 13),
                            ),
                          ),
                        ]),
                        Text(
                          '알람 추가 화면의 "알람음"에서 이 노래를 선택할 수 있어요.',
                          style: TextStyle(color: kMuted, fontSize: 11.5, height: 1.4),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // 세트 정답률 - total_attempts/correct_count/overall_accuracy. weak_topics/comment와
            // 달리 분석 row 존재 여부와 무관하게 서버가 항상 실시간 계산해서 채워준다.
            _card(
              title: '이 세트의 정답률',
              child: _analysis == null
                  ? Text('불러오지 못했어요.', style: TextStyle(color: kMuted, fontSize: 13))
                  : _analysis!.totalAttempts == 0
                      ? Text('아직 푼 문제가 없어요. 알람 퀴즈를 풀면 여기에 정답률이 쌓여요.',
                          style: TextStyle(color: kMuted, fontSize: 13, height: 1.5))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${_analysis!.overallAccuracy.toStringAsFixed(1)}%',
                                style: TextStyle(color: kPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Text('${_analysis!.correctCount} / ${_analysis!.totalAttempts}문제 정답',
                                style: TextStyle(color: kMuted, fontSize: 13)),
                          ],
                        ),
            ),
            const SizedBox(height: 12),

            // 주제별 정답률 - weak_topics를 정답률 낮은 순(가장 취약한 주제가 위로)으로 표시
            _card(
              title: '주제별 정답률',
              child: (_analysis?.weakTopics == null || _analysis!.weakTopics!.isEmpty)
                  ? Text('아직 주제별 데이터가 없어요.', style: TextStyle(color: kMuted, fontSize: 13))
                  : Column(
                      children: (List<WeakTopicStat>.of(_analysis!.weakTopics!)
                            ..sort((a, b) => a.accuracy.compareTo(b.accuracy)))
                          .map((t) => _topicRow(t))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 12),

            // 세트(폴더) 단위 약점 분석 코멘트 - server/app/api/stats.py GET /api/sets/{id}/analysis
            _card(
              title: 'AI 약점 분석',
              child: _analysis == null || _analysis!.analyzedAt == null
                  ? Text('아직 분석 결과가 없어요. 알람 퀴즈를 몇 번 풀면 여기에 쌓여요.',
                      style: TextStyle(color: kMuted, fontSize: 13, height: 1.5))
                  : Text(_analysis!.comment ?? '분석 결과가 있어요.',
                      style: TextStyle(color: kFg, fontSize: 13, height: 1.5)),
            ),

            if (_wrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _card(
                title: '이 자료의 오답노트 (${_wrongAnswers.length})',
                child: Column(
                  children: _wrongAnswers.take(5).map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.content, style: TextStyle(color: kFg, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('정답: ${w.choices[w.correctAnswer]} · ${w.wrongCount}번 틀림',
                            style: TextStyle(color: kMuted, fontSize: 11.5)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _topicRow(WeakTopicStat topic) {
    final pct = topic.accuracy.clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(topic.topic, style: TextStyle(color: kFg, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('$pct%', style: TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: kBorder,
              color: pct < 50 ? kRed : kPrimary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
