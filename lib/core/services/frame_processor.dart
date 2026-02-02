import 'package:camera/camera.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';

/// Result of processing a single frame.
class FrameProcessingResult {
  final DetectedPose? pose;
  final double latencyMs;
  final bool success;
  final String? error;

  const FrameProcessingResult({
    this.pose,
    required this.latencyMs,
    required this.success,
    this.error,
  });

  factory FrameProcessingResult.success({
    DetectedPose? pose,
    required double latencyMs,
  }) {
    return FrameProcessingResult(
      pose: pose,
      latencyMs: latencyMs,
      success: true,
    );
  }

  factory FrameProcessingResult.failure({
    required String error,
    required double latencyMs,
  }) {
    return FrameProcessingResult(
      latencyMs: latencyMs,
      success: false,
      error: error,
    );
  }
}

/// Orchestrates frame processing pipeline.
/// Handles pose detection and latency measurement.
class FrameProcessor {
  final IPoseDetector _poseDetector;

  FrameProcessor({required IPoseDetector poseDetector})
      : _poseDetector = poseDetector;

  Future<FrameProcessingResult> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required int captureTimestampMicros,
  }) async {
    final startTime = DateTime.now();

    try {
      final pose = await _poseDetector.detectPose(
        image: image,
        sensorOrientation: sensorOrientation,
      );

      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      final latencyMs = (nowMicros - captureTimestampMicros) / 1000.0;

      return FrameProcessingResult.success(
        pose: pose,
        latencyMs: latencyMs,
      );
    } catch (e) {
      final latencyMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      return FrameProcessingResult.failure(
        error: e.toString(),
        latencyMs: latencyMs,
      );
    }
  }

  void dispose() {
    _poseDetector.dispose();
  }
}
