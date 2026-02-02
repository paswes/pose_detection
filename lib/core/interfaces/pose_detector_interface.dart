import 'package:camera/camera.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Abstract interface for pose detection.
/// Decouples from ML Kit implementation for testability.
abstract class IPoseDetector {
  /// Process a camera image and return timestamped pose data.
  /// Returns null if no pose detected.
  Future<TimestampedPose?> detectPose({
    required CameraImage image,
    required int sensorOrientation,
    required int frameIndex,
    required int cameraTimestampMicros,
    int? previousTimestampMicros,
  });

  /// Release detector resources
  void dispose();
}
