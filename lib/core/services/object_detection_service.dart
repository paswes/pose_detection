import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:pose_detection/domain/models/detected_object.dart';

/// Agnostic service for object detection
///
/// This service is a pure technical wrapper around ML Kit's object detection.
/// It is "dumb" regarding the use-case context - it simply detects all objects
/// and returns them without any filtering or interpretation.
///
/// Key principles (per Clean Architecture):
/// - No knowledge of "humans" or specific object types
/// - No filtering logic or use-case assumptions
/// - Returns all detected entities as agnostic domain models
/// - ML Kit types do not leak beyond this service boundary
class ObjectDetectionService {
  ObjectDetector? _objectDetector;

  /// Initialize the object detector lazily
  void _ensureInitialized() {
    _objectDetector ??= ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  /// Detect all objects in a camera frame
  ///
  /// Returns an [ObjectDetectionResult] containing all detected objects
  /// without any filtering. The Domain layer is responsible for
  /// interpreting these results (e.g., filtering for humans).
  Future<ObjectDetectionResult> detectObjects({
    required CameraImage image,
    required int sensorOrientation,
  }) async {
    _ensureInitialized();

    final startTime = DateTime.now();
    final inputImage = _convertCameraImage(image, sensorOrientation);
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    if (inputImage == null) {
      return ObjectDetectionResult(
        objects: const [],
        detectionLatencyMs: 0.0,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    final mlKitObjects = await _objectDetector!.processImage(inputImage);
    final latencyMs =
        DateTime.now().difference(startTime).inMicroseconds / 1000.0;

    // Convert all ML Kit objects to agnostic domain models
    final imageSize = Size(imageWidth, imageHeight);
    final detectedObjects = mlKitObjects
        .map((obj) => _convertToAgnosticModel(obj, imageSize))
        .toList();

    return ObjectDetectionResult(
      objects: detectedObjects,
      detectionLatencyMs: latencyMs,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Convert ML Kit DetectedObject to agnostic DetectedObjectData
  /// No filtering, no interpretation - pure data transformation
  DetectedObjectData _convertToAgnosticModel(
    DetectedObject mlKitObject,
    Size imageSize,
  ) {
    final rect = mlKitObject.boundingBox;

    // Normalize bounding box to 0.0-1.0 coordinate space
    final normalizedBounds = NormalizedBoundingBox(
      left: rect.left / imageSize.width,
      top: rect.top / imageSize.height,
      right: rect.right / imageSize.width,
      bottom: rect.bottom / imageSize.height,
    );

    // Convert all labels without filtering
    final labels = mlKitObject.labels.map((label) {
      return ObjectLabel(
        text: label.text,
        confidence: label.confidence,
        index: label.index,
      );
    }).toList();

    return DetectedObjectData(
      bounds: normalizedBounds,
      labels: labels,
      trackingId: mlKitObject.trackingId,
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

    // Android not implemented
    throw UnsupportedError(
      'Android YUV420 conversion not yet implemented. Only iOS BGRA8888 is supported.',
    );
  }

  /// Close the object detector and release resources
  void dispose() {
    _objectDetector?.close();
    _objectDetector = null;
  }
}
