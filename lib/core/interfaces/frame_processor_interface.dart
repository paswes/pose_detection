import 'package:camera/camera.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Result of processing a single frame
class FrameProcessingResult {
  /// Detected pose (null if no pose found)
  final TimestampedPose? pose;

  /// ML Kit processing time in milliseconds
  final double processingLatencyMs;

  /// Total latency from frame capture to result in milliseconds
  final double endToEndLatencyMs;

  /// Whether processing completed without error
  final bool success;

  /// Error message if processing failed
  final String? errorMessage;

  const FrameProcessingResult({
    this.pose,
    required this.processingLatencyMs,
    required this.endToEndLatencyMs,
    required this.success,
    this.errorMessage,
  });

  /// Create a successful result
  factory FrameProcessingResult.success({
    TimestampedPose? pose,
    required double processingLatencyMs,
    required double endToEndLatencyMs,
  }) {
    return FrameProcessingResult(
      pose: pose,
      processingLatencyMs: processingLatencyMs,
      endToEndLatencyMs: endToEndLatencyMs,
      success: true,
    );
  }

  /// Create a failure result
  factory FrameProcessingResult.failure({
    required String error,
    required double processingLatencyMs,
  }) {
    return FrameProcessingResult(
      processingLatencyMs: processingLatencyMs,
      endToEndLatencyMs: 0,
      success: false,
      errorMessage: error,
    );
  }
}

/// Abstract interface for frame processing orchestration.
abstract class IFrameProcessor {
  /// Process a single camera frame
  Future<FrameProcessingResult> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required int frameIndex,
    required int timestampMicros,
    int? previousTimestampMicros,
  });

  /// Release resources
  void dispose();
}
