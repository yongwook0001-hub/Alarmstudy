import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

enum MotionMissionType { squat, blink }

/// 선택한 동작 미션만 카운트한다.
/// - 스쿼트: 앉았다 일어서기 = 1회, [requiredSquats]회
/// - 눈 깜빡임: 감았다 뜨기 = 1회, [requiredBlinks]회
class MotionMissionScreen extends StatefulWidget {
  static const requiredSquats = 5;
  static const requiredBlinks = 10;

  final int wrongCount;
  final MotionMissionType missionType;
  final VoidCallback onComplete;

  const MotionMissionScreen({
    super.key,
    required this.wrongCount,
    required this.missionType,
    required this.onComplete,
  });

  @override
  State<MotionMissionScreen> createState() => _MotionMissionScreenState();
}

class _MotionMissionScreenState extends State<MotionMissionScreen> {
  bool _recognized = false;
  bool _permissionGranted = false;
  bool _isProcessing = false;
  String _statusText = '카메라를 준비하고 있습니다...';
  String? _error;

  static const _eyeClosedThreshold = 0.4;
  static const _eyeOpenThreshold = 0.55;
  static const _squatDownThreshold = 40.0;
  static const _squatUpThreshold = 15.0;

  int _blinkCount = 0;
  bool _eyesWereClosed = false;

  int _squatCount = 0;
  bool _wasCrouching = false;

  CameraController? _cameraController;
  CameraDescription? _camera;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  PoseDetector? _poseDetector;
  FaceDetector? _faceDetector;

  bool get _isSquat => widget.missionType == MotionMissionType.squat;
  int get _required => _isSquat ? MotionMissionScreen.requiredSquats : MotionMissionScreen.requiredBlinks;
  int get _progress => _isSquat ? _squatCount : _blinkCount;
  String get _missionLabel => _isSquat ? '스쿼트' : '눈 깜빡임';

  @override
  void initState() {
    super.initState();
    if (_isSquat) {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
    } else {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
    }
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _permissionGranted = false;
        _error = '카메라 권한이 필요합니다.';
        _statusText = '카메라 권한을 허용해 주세요.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final camera = front.isNotEmpty ? front.first : cameras.first;

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.startImageStream(_processImage);

      if (!mounted) return;
      setState(() {
        _camera = camera;
        _cameraController = controller;
        _permissionGranted = true;
        _statusText = _isSquat
            ? '전신이 보이게 선 뒤 스쿼트 $_required회를 해주세요.'
            : '얼굴을 중앙에 두고 눈을 $_required번 깜빡여 주세요.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '카메라를 시작하지 못했습니다: $e';
        _statusText = '카메라를 시작할 수 없습니다.';
      });
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _cameraController;
    if (camera == null || controller == null) return null;

    final rotation = _rotationFor(camera, controller);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if ((Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationFor(CameraDescription camera, CameraController controller) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final deviceOrientation = _orientations[controller.value.deviceOrientation];
    if (deviceOrientation == null) return null;

    var rotationCompensation = deviceOrientation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing || _recognized || !mounted) return;

    _isProcessing = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        if (mounted) {
          setState(() => _statusText = '카메라 프레임을 처리하지 못했어요. 잠시만요...');
        }
        return;
      }

      if (_isSquat) {
        await _processSquat(inputImage);
      } else {
        await _processBlink(inputImage);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statusText = '인식 중 잠시 문제가 발생했습니다.');
      }
    } finally {
      if (mounted) _isProcessing = false;
    }
  }

  Future<void> _processBlink(InputImage inputImage) async {
    final faces = await _faceDetector!.processImage(inputImage);
    if (faces.isEmpty) {
      if (mounted) {
        setState(() {
          _statusText = '얼굴이 안 보여요. 전면 카메라에 얼굴을 맞춰 주세요. ($_blinkCount/$_required)';
        });
      }
      return;
    }

    final face = faces.first;
    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;
    if (leftOpen == null || rightOpen == null) {
      if (mounted) {
        setState(() => _statusText = '얼굴을 인식 중... 조명을 밝게 하고 정면을 봐 주세요.');
      }
      return;
    }

    final openness = (leftOpen + rightOpen) / 2;
    if (!_eyesWereClosed && openness < _eyeClosedThreshold) {
      _eyesWereClosed = true;
      if (mounted) {
        setState(() => _statusText = '눈을 다시 떠 주세요 ($_blinkCount/$_required)');
      }
    } else if (_eyesWereClosed && openness > _eyeOpenThreshold) {
      _eyesWereClosed = false;
      _blinkCount++;
      if (_blinkCount >= _required) {
        setState(() {
          _recognized = true;
          _statusText = '눈 깜빡임 $_blinkCount/$_required 완료! 알람을 끌 수 있습니다.';
        });
      } else if (mounted) {
        setState(() => _statusText = '눈 깜빡임 $_blinkCount/$_required');
      }
    } else if (mounted) {
      setState(() {
        _statusText = _eyesWereClosed
            ? '눈을 다시 떠 주세요 ($_blinkCount/$_required)'
            : '눈을 깜빡여 주세요 ($_blinkCount/$_required)';
      });
    }
  }

  Future<void> _processSquat(InputImage inputImage) async {
    final poses = await _poseDetector!.processImage(inputImage);
    if (poses.isEmpty) {
      if (mounted) {
        setState(() {
          _statusText = '전신이 안 보여요. 한 걸음 물러나서 서 주세요. ($_squatCount/$_required)';
        });
      }
      return;
    }

    final pose = poses.first;
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftKnee == null || rightKnee == null || leftHip == null || rightHip == null) {
      if (mounted) {
        setState(() {
          _statusText = '무릎·엉덩이가 보이게 전신이 나오도록 맞춰 주세요. ($_squatCount/$_required)';
        });
      }
      return;
    }

    final kneeY = (leftKnee.y + rightKnee.y) / 2;
    final hipY = (leftHip.y + rightHip.y) / 2;
    final crouchDepth = hipY - kneeY;

    // 앉기(깊이 큼) → 일어서기(깊이 작음) = 1회
    if (!_wasCrouching && crouchDepth > _squatDownThreshold) {
      _wasCrouching = true;
      if (mounted) {
        setState(() => _statusText = '좋아요, 이제 일어나 주세요 ($_squatCount/$_required)');
      }
    } else if (_wasCrouching && crouchDepth < _squatUpThreshold) {
      _wasCrouching = false;
      _squatCount++;
      if (_squatCount >= _required) {
        setState(() {
          _recognized = true;
          _statusText = '스쿼트 $_squatCount/$_required 완료! 알람을 끌 수 있습니다.';
        });
      } else if (mounted) {
        setState(() => _statusText = '스쿼트 $_squatCount/$_required');
      }
    } else if (mounted) {
      setState(() {
        _statusText = _wasCrouching
            ? '일어나 주세요 ($_squatCount/$_required)'
            : '앉았다 일어서 주세요 ($_squatCount/$_required)';
      });
    }
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
              Text('선택한 미션: $_missionLabel ($_required회)',
                  style: TextStyle(color: kMuted, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 340,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cameraController != null && _cameraController!.value.isInitialized)
                      CameraPreview(_cameraController!)
                    else
                      Center(
                        child: Text(
                          _error ?? _statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: kRed, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _permissionGranted
                                ? '$_missionLabel · $_progress/$_required'
                                : '대기',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
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
                        style: TextStyle(
                            color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              const Spacer(),
              PrimaryButton(
                label: '알람 끄기',
                onTap: _recognized ? widget.onComplete : null,
                height: 56,
                backgroundColor: _recognized ? kPrimary : kBorder,
                textColor: _recognized ? Colors.white : kMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
