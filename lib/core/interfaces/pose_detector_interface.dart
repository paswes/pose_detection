import 'package:camera/camera.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';

abstract class IPoseDetector {
  Future<DetectedPose?> detectPose({
    required CameraImage image,
    required int sensorOrientation,
  });

  void dispose();
}
