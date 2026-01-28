import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Service responsible for ML Kit pose detection
/// Converts ML Kit outputs to domain-agnostic motion data models
class PoseDetectionService {
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

  /// Process a camera image and return timestamped pose data
  /// Returns null if no pose detected or conversion fails
  Future<TimestampedPose?> detectPose({
    required CameraImage image,
    required int sensorOrientation,
    required int frameIndex,
    required int cameraTimestampMicros,
    int? previousTimestampMicros,
  }) async {
    _ensureInitialized();

    final inputImage = _convertCameraImage(image, sensorOrientation);

    if (inputImage == null) {
      return null;
    }

    final poses = await _poseDetector!.processImage(inputImage);

    // Return first detected pose converted to domain model
    if (poses.isEmpty) {
      return null;
    }

    return _convertToDomainModel(
      pose: poses.first,
      frameIndex: frameIndex,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      cameraTimestampMicros: cameraTimestampMicros,
      previousTimestampMicros: previousTimestampMicros,
    );
  }

  /// Convert ML Kit Pose to domain TimestampedPose
  TimestampedPose _convertToDomainModel({
    required Pose pose,
    required int frameIndex,
    required double imageWidth,
    required double imageHeight,
    required int cameraTimestampMicros,
    int? previousTimestampMicros,
  }) {
    final imageSize = Size(imageWidth, imageHeight);

    // Extract raw landmarks from ML Kit
    final rawLandmarks = pose.landmarks.entries.map((entry) {
      final landmark = entry.value;
      return RawLandmark(
        id: entry.key.index,
        x: landmark.x,
        y: landmark.y,
        z: landmark.z,
        likelihood: landmark.likelihood,
      );
    }).toList(growable: false);

    // Normalize landmarks for resolution-independent analysis
    final normalizedLandmarks = CoordinateTranslator.normalizeAll(
      rawLandmarks,
      imageSize,
    );

    // Calculate frame delta for motion analysis
    final deltaTimeMicros = previousTimestampMicros != null
        ? cameraTimestampMicros - previousTimestampMicros
        : null;

    return TimestampedPose(
      landmarks: rawLandmarks,
      normalizedLandmarks: normalizedLandmarks,
      frameIndex: frameIndex,
      timestampMicros: cameraTimestampMicros,
      deltaTimeMicros: deltaTimeMicros,
      systemTime: DateTime.now(),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
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

    // Android not implemented - throw explicit error
    throw UnsupportedError(
      'Android YUV420 conversion not yet implemented. Only iOS BGRA8888 is supported.',
    );
  }

  /// Close the pose detector
  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}

