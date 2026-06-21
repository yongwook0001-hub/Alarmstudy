import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AlarmAddScreen extends StatefulWidget {
  const AlarmAddScreen({super.key});

  @override
  State<AlarmAddScreen> createState() => _AlarmAddScreenState();
}

class _AlarmAddScreenState extends State<AlarmAddScreen> {
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 30);
  final _labelController = TextEditingController();
  final _days = ['월', '화', '수', '목', '금', '토', '일'];
  final Set<String> _selectedDays = {'월', '화', '수', '목', '금'};
  String _selectedSubject = '한국사';
  final _subjects = ['한국사', '영어', '수학', '과학'];

  String get _ampm => _time.hour < 12 ? '오전' : '오후';
  String get _timeStr {
    final h = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final m = _time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
                  hintText: '예: 출근 준비',
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

          // 퀴즈 과목
          _section(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('알람 해제 퀴즈 과목', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3,
                children: _subjects.map((s) {
                  final on = _selectedSubject == s;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSubject = s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: on ? kPrimary.withOpacity(0.3) : kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: on ? kPrimary : kMuted.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(s, style: TextStyle(
                        color: on ? kPrimaryLight : kMuted, fontWeight: FontWeight.bold,
                      )),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // 저장 버튼
          GestureDetector(
            onTap: () => Navigator.pop(context),
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