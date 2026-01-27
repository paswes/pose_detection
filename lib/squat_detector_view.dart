import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// =============================================================================
// SQUAT DETECTOR VIEW - Main Widget
// =============================================================================

class SquatDetectorView extends StatefulWidget {
  const SquatDetectorView({super.key});

  @override
  State<SquatDetectorView> createState() => _SquatDetectorViewState();
}

class _SquatDetectorViewState extends State<SquatDetectorView>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Pose Detection
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );
  bool _isProcessingFrame = false;

  // Squat Counter State Machine
  SquatState _currentState = SquatState.standing;
  int _repCount = 0;
  double _currentKneeAngle = 180.0;

  // Hysteresis thresholds to prevent jitter
  static const double _upThreshold = 160.0;
  static const double _downThreshold = 100.0;
  static const double _hysteresisBuffer = 5.0;

  // Timer state
  bool _isCountdownActive = false;
  bool _isCountingActive = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  // UI feedback
  String _feedbackText = 'Press Start';
  Color _feedbackColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // ===========================================================================
  // CAMERA INITIALIZATION
  // ===========================================================================

  Future<void> _initializeCamera() async {
    _log('Camera', 'Initializing camera...');

    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _log('Camera', 'ERROR: No cameras available');
        return;
      }

      // Find the back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _log('Camera', 'Using camera: ${backCamera.name}');

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset
            .medium, // Medium resolution for balance of quality/performance
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Lock camera orientation to portrait
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      _log('Camera', 'Camera initialized successfully');
      _log('Camera', 'Resolution: ${_cameraController!.value.previewSize}');

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _log('Camera', 'ERROR initializing camera: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _log('Camera', 'Starting image stream...');

    _cameraController!.startImageStream((CameraImage image) {
      if (!_isProcessingFrame && _isCountingActive) {
        _isProcessingFrame = true;
        _processImage(image);
      }
    });
  }

  void _stopImageStream() {
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
      _log('Camera', 'Image stream stopped');
    }
  }

  // ===========================================================================
  // IMAGE PROCESSING & POSE DETECTION
  // ===========================================================================

  Future<void> _processImage(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);

      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _analyzePose(pose);
      }
    } catch (e) {
      _log('Pose', 'ERROR processing image: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameras!.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    // Get the rotation for the camera
    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );

    if (imageRotation == null) return null;

    // For iOS with BGRA8888 format
    if (Platform.isIOS) {
      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return null;
  }

  // ===========================================================================
  // POSE ANALYSIS & SQUAT DETECTION
  // ===========================================================================

  void _analyzePose(Pose pose) {
    // Get landmarks for knee angle calculation
    // We'll use the LEFT side landmarks (can be modified to use right or average)
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Check if we have all required landmarks
    if (leftHip == null ||
        leftKnee == null ||
        leftAnkle == null ||
        rightHip == null ||
        rightKnee == null ||
        rightAnkle == null) {
      return;
    }

    // Check landmark likelihood/confidence
    final minLikelihood = 0.5;
    if (leftHip.likelihood < minLikelihood ||
        leftKnee.likelihood < minLikelihood ||
        leftAnkle.likelihood < minLikelihood ||
        rightHip.likelihood < minLikelihood ||
        rightKnee.likelihood < minLikelihood ||
        rightAnkle.likelihood < minLikelihood) {
      return;
    }

    _log('Pose', 'Landmarks detected - Hip, Knee, Ankle visible');

    // Calculate knee angles for both legs
    final leftKneeAngle = _calculateAngle(
      Point(leftHip.x, leftHip.y),
      Point(leftKnee.x, leftKnee.y),
      Point(leftAnkle.x, leftAnkle.y),
    );

    final rightKneeAngle = _calculateAngle(
      Point(rightHip.x, rightHip.y),
      Point(rightKnee.x, rightKnee.y),
      Point(rightAnkle.x, rightAnkle.y),
    );

    // Use the average of both knees for more stability
    final averageKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    if (mounted) {
      setState(() {
        _currentKneeAngle = averageKneeAngle;
      });
    }

    // Update squat state machine
    _updateSquatState(averageKneeAngle);
  }

  /// Calculate angle at point B using Law of Cosines
  /// Points: A (hip), B (knee), C (ankle)
  double _calculateAngle(Point a, Point b, Point c) {
    // Vector BA
    final ba = Point(a.x - b.x, a.y - b.y);
    // Vector BC
    final bc = Point(c.x - b.x, c.y - b.y);

    // Dot product of BA and BC
    final dotProduct = ba.x * bc.x + ba.y * bc.y;

    // Magnitudes
    final magnitudeBA = sqrt(ba.x * ba.x + ba.y * ba.y);
    final magnitudeBC = sqrt(bc.x * bc.x + bc.y * bc.y);

    // Avoid division by zero
    if (magnitudeBA == 0 || magnitudeBC == 0) return 180.0;

    // Calculate angle in radians, then convert to degrees
    final cosAngle = dotProduct / (magnitudeBA * magnitudeBC);
    // Clamp to [-1, 1] to avoid NaN from acos due to floating point errors
    final clampedCos = cosAngle.clamp(-1.0, 1.0);
    final angleRadians = acos(clampedCos);
    final angleDegrees = angleRadians * 180 / pi;

    return angleDegrees;
  }

  /// State machine for squat counting with hysteresis
  void _updateSquatState(double kneeAngle) {
    final previousState = _currentState;

    switch (_currentState) {
      case SquatState.standing:
        // Transition to going down when angle drops below threshold
        if (kneeAngle < _upThreshold - _hysteresisBuffer) {
          _currentState = SquatState.goingDown;
          _updateFeedback('Go Down!', Colors.orange);
          _log(
            'State',
            'STANDING -> GOING_DOWN (angle: ${kneeAngle.toStringAsFixed(1)}°)',
          );
        }
        break;

      case SquatState.goingDown:
        // Reached bottom of squat
        if (kneeAngle < _downThreshold) {
          _currentState = SquatState.down;
          _updateFeedback('Stand Up!', Colors.red);
          _log(
            'State',
            'GOING_DOWN -> DOWN (angle: ${kneeAngle.toStringAsFixed(1)}°)',
          );
        }
        // Went back up without completing (reset)
        else if (kneeAngle > _upThreshold + _hysteresisBuffer) {
          _currentState = SquatState.standing;
          _updateFeedback('Go Down!', Colors.blue);
          _log('State', 'GOING_DOWN -> STANDING (incomplete)');
        }
        break;

      case SquatState.down:
        // Starting to come up
        if (kneeAngle > _downThreshold + _hysteresisBuffer) {
          _currentState = SquatState.goingUp;
          _updateFeedback('Keep Going!', Colors.orange);
          _log(
            'State',
            'DOWN -> GOING_UP (angle: ${kneeAngle.toStringAsFixed(1)}°)',
          );
        }
        break;

      case SquatState.goingUp:
        // Completed the rep - back to standing
        if (kneeAngle > _upThreshold) {
          _currentState = SquatState.standing;
          _incrementRep();
          _updateFeedback('Rep Complete!', Colors.green);
          _log(
            'State',
            'GOING_UP -> STANDING (REP COUNTED! angle: ${kneeAngle.toStringAsFixed(1)}°)',
          );

          // Reset feedback after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isCountingActive) {
              _updateFeedback('Go Down!', Colors.blue);
            }
          });
        }
        // Went back down (reset to down state)
        else if (kneeAngle < _downThreshold - _hysteresisBuffer) {
          _currentState = SquatState.down;
          _updateFeedback('Stand Up!', Colors.red);
          _log('State', 'GOING_UP -> DOWN (went back down)');
        }
        break;
    }

    if (previousState != _currentState && mounted) {
      setState(() {});
    }
  }

  void _incrementRep() {
    if (mounted) {
      setState(() {
        _repCount++;
      });
      _log('Counter', '🎯 REP INCREMENTED: $_repCount');
    }
  }

  void _updateFeedback(String text, Color color) {
    if (mounted) {
      setState(() {
        _feedbackText = text;
        _feedbackColor = color;
      });
    }
  }

  // ===========================================================================
  // TIMER & CONTROL
  // ===========================================================================

  void _startCountdown() {
    if (_isCountdownActive || _isCountingActive) return;

    _log('Timer', 'Starting 5-second countdown...');

    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 5;
      _repCount = 0;
      _currentState = SquatState.standing;
      _feedbackText = '5';
      _feedbackColor = Colors.white;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
        _feedbackText = _countdownSeconds > 0 ? '$_countdownSeconds' : 'GO!';
      });

      _log('Timer', 'Countdown: $_countdownSeconds');

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _startCounting();
      }
    });
  }

  void _startCounting() {
    _log('Counter', 'Squat counting started!');

    setState(() {
      _isCountdownActive = false;
      _isCountingActive = true;
      _feedbackText = 'Go Down!';
      _feedbackColor = Colors.blue;
    });

    _startImageStream();
  }

  void _reset() {
    _log('Control', 'Resetting counter...');

    _countdownTimer?.cancel();
    _stopImageStream();

    setState(() {
      _isCountdownActive = false;
      _isCountingActive = false;
      _countdownSeconds = 5;
      _repCount = 0;
      _currentState = SquatState.standing;
      _currentKneeAngle = 180.0;
      _feedbackText = 'Press Start';
      _feedbackColor = Colors.white;
    });
  }

  // ===========================================================================
  // LOGGING
  // ===========================================================================

  void _log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    developer.log('[$timestamp] [$tag] $message');
    debugPrint('[$timestamp] [$tag] $message');
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview (Fullscreen)
          _buildCameraPreview(),

          // Overlay UI
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Calculate aspect ratio for fullscreen
    final size = MediaQuery.of(context).size;
    final cameraAspectRatio = _cameraController!.value.aspectRatio;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.width * cameraAspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top Bar - Rep Counter
          _buildRepCounter(),

          const Spacer(),

          // Center - Feedback Text & Countdown
          _buildFeedbackDisplay(),

          const Spacer(),

          // Debug Info
          _buildDebugInfo(),

          // Bottom - Control Buttons
          _buildControlButtons(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRepCounter() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'REPS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
            ),
          ),
          Text(
            '$_repCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackDisplay() {
    final isCountdown = _isCountdownActive && _countdownSeconds > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: _feedbackColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _feedbackColor, width: 3),
      ),
      child: Text(
        _feedbackText,
        style: TextStyle(
          color: _feedbackColor,
          fontSize: isCountdown ? 80 : 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    if (!_isCountingActive) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Knee Angle: ${_currentKneeAngle.toStringAsFixed(1)}°',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'State: ${_currentState.name.toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildAngleIndicator(),
        ],
      ),
    );
  }

  Widget _buildAngleIndicator() {
    // Visual indicator showing current angle relative to thresholds
    final normalizedAngle =
        ((_currentKneeAngle - _downThreshold) / (_upThreshold - _downThreshold))
            .clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_downThreshold.toInt()}°',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            Text(
              '${_upThreshold.toInt()}°',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [Colors.red, Colors.orange, Colors.green],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left:
                    normalizedAngle * (MediaQuery.of(context).size.width - 104),
                child: Container(
                  width: 4,
                  height: 8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Start Button
        if (!_isCountdownActive && !_isCountingActive)
          _buildButton(
            onPressed: _startCountdown,
            icon: Icons.play_arrow,
            label: 'START',
            color: Colors.green,
          ),

        // Reset Button (always visible during counting)
        if (_isCountdownActive || _isCountingActive)
          _buildButton(
            onPressed: _reset,
            icon: Icons.refresh,
            label: 'RESET',
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER CLASSES & ENUMS
// =============================================================================

/// State machine states for squat detection
enum SquatState {
  standing, // User is standing (knee angle > 160°)
  goingDown, // User is descending
  down, // User is at bottom of squat (knee angle < 100°)
  goingUp, // User is ascending
}

/// Simple Point class for angle calculations
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}

// =============================================================================
// MAIN APP ENTRY (for standalone testing)
// =============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SquatCounterApp());
}

class SquatCounterApp extends StatelessWidget {
  const SquatCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Squat Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SquatDetectorView(),
    );
  }
}
