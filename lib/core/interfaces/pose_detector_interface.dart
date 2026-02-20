import 'package:camera/camera.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';

/// Abstract interface for pose detection.
/// Decouples from ML Kit implementation for testability.
abstract class IPoseDetector {
  /// Process a camera image and return detected pose.
  /// Returns null if no pose detected.
  Future<DetectedPose?> detectPose({
    required CameraImage image,
    required int sensorOrientation,
  });

  /// Release detector resources
  void dispose();
}
