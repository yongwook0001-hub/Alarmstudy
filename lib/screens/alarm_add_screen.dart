import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/alarm_model.dart';
import '../models/study_material.dart';

class AlarmAddScreen extends StatefulWidget {
  final List<StudyMaterial> materials;
  const AlarmAddScreen({super.key, required this.materials});

  @override
  State<AlarmAddScreen> createState() => _AlarmAddScreenState();
}

class _AlarmAddScreenState extends State<AlarmAddScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 30);
  final _labelController = TextEditingController();
  final _days = ['월', '화', '수', '목', '금', '토', '일'];
  final Set<String> _selectedDays = {'월', '화', '수', '목', '금'};
  StudyMaterial? _selectedMaterial; // null = 퀴즈 없이 알람 끄기

  String get _ampm => _time.hour < 12 ? '오전' : '오후';
  String get _timeStr {
    final h = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final m = _time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _save() {
    final alarm = AlarmModel(
      id: DateTime.now().millisecondsSinceEpoch,
      time: '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      label: _labelController.text.trim().isEmpty ? '알람' : _labelController.text.trim(),
      active: true,
      days: _selectedDays.toList(),
      quizSubject: _selectedMaterial?.subject ?? '없음',
      materialId: _selectedMaterial?.id,
    );
    Navigator.pop(context, alarm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('새 알람 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // 시간 선택
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            child: _section(
              child: Center(
                child: Text(
                  '$_ampm   $_timeStr',
                  style: const TextStyle(
                    color: kPrimary, fontSize: 48, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 알람 이름
          _section(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('알람 이름', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _labelController,
                style: const TextStyle(color: kFg),
                decoration: const InputDecoration(
                  hintText: '예: 아침 공부',
                  hintStyle: TextStyle(color: kMuted),
                  border: InputBorder.none,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // 반복 요일
          _section(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('반복 요일', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _days.map((d) {
                  final on = _selectedDays.contains(d);
                  return GestureDetector(
                    onTap: () => setState(() =>
                        on ? _selectedDays.remove(d) : _selectedDays.add(d)),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: on ? kPrimary : kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: on ? kPrimary : kMuted.withOpacity(0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text(d, style: TextStyle(
                        color: on ? Colors.white : kMuted, fontSize: 13,
                      )),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // 학습자료 선택
          _section(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('알람 해제 퀴즈 (학습자료 선택)', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 12),

              if (widget.materials.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: kMuted, size: 16),
                    SizedBox(width: 8),
                    Text('저장된 학습자료가 없습니다.\nAI학습 탭에서 먼저 추가해주세요.',
                        style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
                  ]),
                )
              else ...[
                // 퀴즈 없음 옵션
                _materialTile(null),
                const SizedBox(height: 8),
                ...widget.materials.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _materialTile(m),
                )),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // 저장 버튼
          GestureDetector(
            onTap: _save,
            child: Container(
              height: 52, width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('알람 저장',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _materialTile(StudyMaterial? material) {
    final isSelected = _selectedMaterial?.id == material?.id &&
        (_selectedMaterial == null) == (material == null);

    return GestureDetector(
      onTap: () => setState(() => _selectedMaterial = material),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary.withOpacity(0.12) : kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimary : kBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: material == null
            ? Row(children: [
                Icon(Icons.not_interested, color: isSelected ? kPrimary : kMuted, size: 18),
                const SizedBox(width: 10),
                Text('퀴즈 없이 알람 끄기',
                    style: TextStyle(
                      color: isSelected ? kPrimaryLight : kMuted,
                      fontSize: 14,
                    )),
              ])
            : Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimary.withOpacity(0.25) : kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(material.subject,
                      style: TextStyle(
                        color: isSelected ? kPrimaryLight : kMuted,
                        fontSize: 11, fontWeight: FontWeight.bold,
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(material.title,
                        style: TextStyle(
                          color: isSelected ? kFg : kFg.withOpacity(0.8),
                          fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis),
                    Text('퀴즈 ${material.quizCount}문제 · ${material.date}',
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                  ]),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: kPrimary, size: 18),
              ]),
      ),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}
