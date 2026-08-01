import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 정답률이 낮을 때 등장하는 동작 미션 화면.
///
/// ⚠️ 중요: 지금은 실제 카메라로 동작을 인식하는 게 아니라,
/// 화면이 뜨고 3초 뒤 자동으로 "인식 완료"되는 시뮬레이션이다.
/// 실제 카메라 기반 포즈 인식을 붙이려면:
///   1. camera 패키지로 실제 카메라 프리뷰 연결
///   2. google_mlkit_pose_detection 같은 포즈 인식 모델로 실시간 관절 좌표 분석
///   3. "두 팔이 어깨보다 위로 올라갔는지" 같은 조건을 좌표 기반으로 판정
/// 이 부분은 카메라 권한 처리, 기기 테스트(시뮬레이터 불가)까지 필요한
/// 별도의 큰 작업이라 이번엔 화면 흐름만 완성해뒀다.
class MotionMissionScreen extends StatefulWidget {
  final int wrongCount;
  final VoidCallback onComplete;

  const MotionMissionScreen({
    super.key,
    required this.wrongCount,
    required this.onComplete,
  });

  @override
  State<MotionMissionScreen> createState() => _MotionMissionScreenState();
}

class _MotionMissionScreenState extends State<MotionMissionScreen> {
  bool _recognized = false;

  @override
  void initState() {
    super.initState();
    // TODO(실제 구현 시): 이 Timer를 실제 포즈 인식 콜백으로 교체
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _recognized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.wrongCount}문제를 틀렸어요',
                  style: TextStyle(color: kFg, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('화면 속 동작을 똑같이 따라 해주세요',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 24),

              // 카메라 프리뷰 자리 (시뮬레이션 - 실제 camera 패키지로 교체 필요)
              Container(
                width: double.infinity,
                height: 340,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 14, top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: kRed, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('인식 중', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🙆', style: TextStyle(fontSize: 72)),
                          const SizedBox(height: 20),
                          const Text('두 팔을 위로 뻗어주세요',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('동작을 3초간 유지해주세요',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  _recognized ? '동작을 인식하고 있어요...' : '동작을 인식하고 있어요...',
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              if (_recognized)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('✓ 동작 인식 완료!',
                        style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

              const Spacer(),
              GestureDetector(
                onTap: _recognized ? widget.onComplete : null,
                child: Container(
                  height: 56, width: double.infinity,
                  decoration: BoxDecoration(
                    color: _recognized ? kPrimary : kBorder,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text('알람 끄기',
                      style: TextStyle(
                          color: _recognized ? Colors.white : kMuted,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}