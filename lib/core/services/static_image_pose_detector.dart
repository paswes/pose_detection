import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:pose_detection/core/domain/models/detected_pose.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';

/// Detects poses in static image files (e.g. JPEG frames extracted from video).
///
/// Uses [PoseDetectionMode.single] for better accuracy on individual frames,
/// unlike [PoseDetectionService] which uses `.stream` for live camera input.
class StaticImagePoseDetector {
  PoseDetector? _poseDetector;

  /// Initialize the pose detector lazily to defer ML model loading.
  void _ensureInitialized() {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.single,
      ),
    );
  }

  /// Detect a pose in a JPEG image file.
  ///
  /// [filePath] — absolute path to the JPEG image file.
  /// [imageWidth] / [imageHeight] — the image dimensions (from video metadata).
  /// ML Kit returns landmark coordinates in the image's pixel space.
  ///
  /// Returns `null` if no pose is detected.
  Future<DetectedPose?> detectPoseFromFile(
    String filePath, {
    required double imageWidth,
    required double imageHeight,
  }) async {
    _ensureInitialized();

    final inputImage = InputImage.fromFilePath(filePath);
    final poses = await _poseDetector!.processImage(inputImage);

    if (poses.isEmpty) return null;

    return _convertToDomainModel(
      pose: poses.first,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Convert ML Kit [Pose] to domain [DetectedPose].
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
            likelihood: entry.value.likelihood,
          );
        })
        .toList(growable: false);

    return DetectedPose(
      landmarks: landmarks,
      imageSize: Size(imageWidth, imageHeight),
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  /// Release ML Kit resources.
  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
