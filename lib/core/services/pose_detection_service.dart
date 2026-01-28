import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service responsible for ML Kit pose detection
class PoseDetectionService {
  late final PoseDetector _poseDetector;

  PoseDetectionService() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  /// Process a camera image and detect poses
  Future<List<Pose>> detectPoses(CameraImage image, int sensorOrientation) async {
    final inputImage = _convertCameraImage(image, sensorOrientation);

    if (inputImage == null) {
      return [];
    }

    return await _poseDetector.processImage(inputImage);
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImage(CameraImage image, int sensorOrientation) {
    // Get the rotation for the camera
    final imageRotation = InputImageRotationValue.fromRawValue(
      sensorOrientation,
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

  /// Close the pose detector
  void dispose() {
    _poseDetector.close();
  }
}
