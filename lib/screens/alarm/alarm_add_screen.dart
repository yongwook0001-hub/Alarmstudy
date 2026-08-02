import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/alarm_model.dart';
import '../../models/alarm_sound.dart';
import '../../models/material_set.dart';
import '../../models/study_material.dart';
import '../../widgets/primary_button.dart';

class AlarmAddScreen extends StatefulWidget {
  final List<MaterialSet> sets;
  const AlarmAddScreen({super.key, required this.sets});

  @override
  State<AlarmAddScreen> createState() => _AlarmAddScreenState();
}

/// 알람음 선택 바텀시트에서 고른 결과 (기본 알람음 또는 AI 생성 노래).
class _SoundChoice {
  final String soundId;
  final String? customPath;
  final String label;
  const _SoundChoice({required this.soundId, required this.customPath, required this.label});
}

class _AlarmAddScreenState extends State<AlarmAddScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  final _labelController = TextEditingController();
  final _days = ['일', '월', '화', '수', '목', '금', '토'];
  final Set<String> _selectedDays = {'월', '화', '수', '목', '금'};
  MaterialSet? _selectedSet;

  String _soundId = 'default';
  String? _customSoundPath;
  String _soundLabel = kDefaultAlarmSounds.first.label;

  final _previewPlayer = AudioPlayer();

  @override
  void dispose() {
    _labelController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  void _save() {
    final alarm = AlarmModel(
      id: 0, // 서버가 실제 id를 발급 - AppData.addAlarm이 응답으로 교체한다.
      time: '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      label: _labelController.text.trim().isEmpty ? '알람' : _labelController.text.trim(),
      active: true,
      days: _selectedDays.toList(),
      setId: _selectedSet?.id,
      soundId: _soundId,
      customSoundPath: _customSoundPath,
    );
    Navigator.pop(context, alarm);
  }

  /// 세트 선택이 바뀌면, 이전에 골라둔 "AI 생성 노래" 알람음이 다른 세트 것일 수
  /// 있으니 기본 알람음으로 되돌린다 (세트 자체를 선택 해제한 경우도 동일하게 처리).
  void _onSetSelected(MaterialSet? set) {
    setState(() {
      _selectedSet = set;
      if (_soundId == kCustomSongSoundId) {
        _soundId = 'default';
        _customSoundPath = null;
        _soundLabel = kDefaultAlarmSounds.first.label;
      }
    });
  }

  Future<void> _pickSound() async {
    final songMaterials = _selectedSet?.materialsWithSong ?? const <StudyMaterial>[];
    String? playingId;

    final result = await showModalBottomSheet<_SoundChoice>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> preview(String id, {String? assetPath, String? filePath}) async {
            if (playingId == id) {
              await _previewPlayer.stop();
              setSheetState(() => playingId = null);
              return;
            }
            await _previewPlayer.stop();
            if (assetPath != null) {
              await _previewPlayer.play(AssetSource(assetPath.replaceFirst('assets/', '')));
            } else if (filePath != null) {
              await _previewPlayer.play(DeviceFileSource(filePath));
            }
            setSheetState(() => playingId = id);
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('알람음 선택', style: TextStyle(color: kMuted, fontSize: 13)),
                ),
                ...kDefaultAlarmSounds.map((s) => ListTile(
                      leading: IconButton(
                        icon: Icon(
                          playingId == s.id ? Icons.stop_circle : Icons.play_circle_outline,
                          color: kPrimary,
                        ),
                        onPressed: () => preview(s.id, assetPath: s.assetPath),
                      ),
                      title: Text(s.label, style: TextStyle(color: kFg)),
                      trailing: _soundId == s.id ? Icon(Icons.check, color: kPrimary) : null,
                      onTap: () => Navigator.pop(
                        sheetContext,
                        _SoundChoice(soundId: s.id, customPath: null, label: s.label),
                      ),
                    )),
                for (final m in songMaterials)
                  ListTile(
                    leading: IconButton(
                      icon: Icon(
                        playingId == 'song_${m.id}' ? Icons.stop_circle : Icons.play_circle_outline,
                        color: kPrimary,
                      ),
                      onPressed: () => preview('song_${m.id}', filePath: m.songPath!),
                    ),
                    title: Text('🎵 ${m.displayTitle} 노래 (AI 생성)', style: TextStyle(color: kFg)),
                    trailing: _soundId == kCustomSongSoundId && _customSoundPath == m.songPath
                        ? Icon(Icons.check, color: kPrimary)
                        : null,
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _SoundChoice(
                        soundId: kCustomSongSoundId,
                        customPath: m.songPath,
                        label: '${m.displayTitle} 노래',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    await _previewPlayer.stop();

    if (result != null) {
      setState(() {
        _soundId = result.soundId;
        _customSoundPath = result.customPath;
        _soundLabel = result.label;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 (X 닫기 버튼 + 제목)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: kFg),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text('알람 추가',
                      style: TextStyle(color: kFg, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 시간 선택 - 박스형
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _time);
                        if (t != null) setState(() => _time = t);
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _timeBox(_time.hour.toString().padLeft(2, '0')),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(':',
                                  style: TextStyle(
                                      color: kFg, fontSize: 40, fontWeight: FontWeight.bold)),
                            ),
                            _timeBox(_time.minute.toString().padLeft(2, '0')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 알람 이름
                    Text('알람 이름', style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: TextField(
                        controller: _labelController,
                        style: TextStyle(color: kFg),
                        decoration: InputDecoration(
                          hintText: '예: 아침 공부',
                          hintStyle: TextStyle(color: kMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 반복요일
                    Text('반복요일', style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.map((d) {
                        final on = _selectedDays.contains(d);
                        return GestureDetector(
                          onTap: () => setState(() =>
                          on ? _selectedDays.remove(d) : _selectedDays.add(d)),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: on ? kPrimary : kCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: on ? kPrimary : kBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(d,
                                style: TextStyle(
                                    color: on ? Colors.white : kMuted, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // 연결할 학습 자료 (세트/폴더 단위)
                    Text('연결할 학습 자료',
                        style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (widget.sets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: kMuted, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('저장된 학습자료 폴더가 없습니다.\nAI학습 탭에서 먼저 추가해주세요.',
                                style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
                          ),
                        ]),
                      )
                    else ...[
                      _setTile(null),
                      const SizedBox(height: 8),
                      ...widget.sets.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _setTile(s),
                      )),
                    ],
                    const SizedBox(height: 24),

                    // 알람음
                    GestureDetector(
                      onTap: _pickSound,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('알람음', style: TextStyle(color: kFg, fontSize: 14)),
                            Row(
                              children: [
                                Text(_soundLabel, style: TextStyle(color: kMuted, fontSize: 14)),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, color: kMuted, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 저장하기 버튼
                    PrimaryButton(label: '저장하기', onTap: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox(String value) {
    return Container(
      width: 90,
      height: 72,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      alignment: Alignment.center,
      child: Text(value,
          style: TextStyle(color: kFg, fontSize: 36, fontWeight: FontWeight.bold)),
    );
  }

  Widget _setTile(MaterialSet? set) {
    final isSelected = _selectedSet?.id == set?.id && (_selectedSet == null) == (set == null);

    return GestureDetector(
      onTap: () => _onSetSelected(set),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary.withOpacity(0.08) : kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimary : kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: set == null
            ? Row(children: [
          Icon(Icons.not_interested, color: isSelected ? kPrimary : kMuted, size: 18),
          const SizedBox(width: 10),
          Text('퀴즈 없이 알람 끄기',
              style: TextStyle(
                color: isSelected ? kPrimary : kMuted,
                fontSize: 14,
              )),
        ])
            : Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.folder_outlined, color: kPrimary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(set.title,
                  style: TextStyle(
                    color: isSelected ? kFg : kFg.withOpacity(0.8),
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis),
              Text('PDF ${set.materialCount}개',
                  style: TextStyle(color: kMuted, fontSize: 11)),
            ]),
          ),
          if (isSelected)
            Icon(Icons.check_circle, color: kPrimary, size: 18),
        ]),
      ),
    );
  }
}
