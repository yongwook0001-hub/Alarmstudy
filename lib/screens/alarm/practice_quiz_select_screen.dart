import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/alarm_model.dart';
import '../../models/material_set.dart';
import 'alarm_ringing_screen.dart';

/// 가상 문제풀이 - 알람이 울리는 걸 기다리지 않고 바로 퀴즈를 풀어보는 화면.
///
/// 실제 문제는 서버가 "세트에 연결된 알람" 기준으로만 내려주기 때문에(POST /api/sessions는
/// alarm_id가 필요) 세트를 직접 고르는 대신, 학습자료가 연결된 알람 중 하나를 골라
/// 그 알람으로 연습 세션을 시작한다.
class PracticeQuizSelectScreen extends StatelessWidget {
  final List<AlarmModel> alarms;
  final List<MaterialSet> sets;

  const PracticeQuizSelectScreen({super.key, required this.alarms, required this.sets});

  MaterialSet? _setFor(AlarmModel alarm) {
    try {
      return sets.firstWhere((s) => s.id == alarm.setId);
    } catch (_) {
      return null;
    }
  }

  void _start(BuildContext context, AlarmModel alarm, MaterialSet set) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmRingingScreen(
          alarm: alarm,
          set: set,
          practiceMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = alarms.where((a) => a.setId != null && _setFor(a) != null).toList();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kFg,
        title: Text('가상 문제풀이', style: TextStyle(color: kFg, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: available.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '학습자료가 연결된 알람이 없어요.\n알람 설정 탭에서 폴더를 연결한 알람을 먼저 만들어보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, fontSize: 14),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: available.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final alarm = available[i];
                  final set = _setFor(alarm)!;
                  return GestureDetector(
                    onTap: () => _start(context, alarm, set),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.quiz_outlined, color: kPrimary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(alarm.label,
                                    style: TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(set.title,
                                    style: TextStyle(color: kFg, fontSize: 15, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('알람 시각 ${alarm.time}',
                                    style: TextStyle(color: kMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: kMuted, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
