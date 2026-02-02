import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Service responsible for ML Kit pose detection.
/// Converts ML Kit outputs to simple domain models.
class PoseDetectionService implements IPoseDetector {
  PoseDetector? _poseDetector;

  /// Initialize the pose detector lazily to defer ML model loading
  void _ensureInitialized() {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  @override
  Future<DetectedPose?> detectPose({
    required CameraImage image,
    required int sensorOrientation,
  }) async {
    _ensureInitialized();

    final inputImage = _convertCameraImage(image, sensorOrientation);
    if (inputImage == null) return null;

    final poses = await _poseDetector!.processImage(inputImage);
    if (poses.isEmpty) return null;

    return _convertToDomainModel(
      pose: poses.first,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
    );
  }

  /// Convert ML Kit Pose to domain DetectedPose
  DetectedPose _convertToDomainModel({
    required Pose pose,
    required double imageWidth,
    required double imageHeight,
  }) {
    final landmarks = pose.landmarks.entries
        .map((entry) {
          return Landmark(
            id: entry.key.index,
            x: entry.value.x,
            y: entry.value.y,
            z: entry.value.z,
            confidence: entry.value.likelihood,
          );
        })
        .toList(growable: false);

    return DetectedPose(
      landmarks: landmarks,
      imageSize: Size(imageWidth, imageHeight),
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImage(CameraImage image, int sensorOrientation) {
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

    throw UnsupportedError(
      'Android YUV420 conversion not yet implemented. Only iOS BGRA8888 is supported.',
    );
  }

  @override
  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
