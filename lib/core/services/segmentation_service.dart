import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:pose_detection/domain/models/detected_object.dart';
import 'package:pose_detection/domain/models/segmentation_result.dart';

/// Agnostic service for selfie/subject segmentation
///
/// This service is a pure technical wrapper around ML Kit's selfie segmentation.
/// It is "dumb" regarding the use-case context - it simply segments the image
/// into foreground (subject) and background without interpretation.
///
/// Key principles (per Clean Architecture):
/// - No knowledge of "humans" - just "foreground subject"
/// - No filtering logic or use-case assumptions
/// - Returns agnostic segmentation data
/// - ML Kit types do not leak beyond this service boundary
class SegmentationService {
  SelfieSegmenter? _segmenter;

  /// Initialize the segmenter lazily
  void _ensureInitialized() {
    _segmenter ??= SelfieSegmenter(
      mode: SegmenterMode.stream,
      enableRawSizeMask: false, // Use mask matching input image size
    );
  }

  /// Segment a camera frame into foreground and background
  ///
  /// Returns a [SegmentationResult] containing coverage and confidence metrics.
  /// The Domain layer is responsible for interpreting whether the foreground
  /// represents a valid human subject.
  Future<SegmentationResult> segmentFrame({
    required CameraImage image,
    required int sensorOrientation,
  }) async {
    _ensureInitialized();

    final startTime = DateTime.now();
    final inputImage = _convertCameraImage(image, sensorOrientation);
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    if (inputImage == null) {
      return SegmentationResult.empty(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    final mask = await _segmenter!.processImage(inputImage);
    final latencyMs =
        DateTime.now().difference(startTime).inMicroseconds / 1000.0;

    if (mask == null) {
      return SegmentationResult(
        maskWidth: 0,
        maskHeight: 0,
        foregroundPixels: 0,
        averageConfidence: 0.0,
        segmentationLatencyMs: latencyMs,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    // Analyze the mask to extract metrics
    final analysis = _analyzeMask(mask);

    return SegmentationResult(
      maskWidth: mask.width,
      maskHeight: mask.height,
      foregroundPixels: analysis.foregroundPixels,
      averageConfidence: analysis.averageConfidence,
      foregroundBounds: analysis.bounds,
      segmentationLatencyMs: latencyMs,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Analyze the segmentation mask to extract metrics
  /// This is pure data extraction, no interpretation
  _MaskAnalysis _analyzeMask(SegmentationMask mask) {
    final confidences = mask.confidences;
    final width = mask.width;
    final height = mask.height;

    if (confidences.isEmpty || width == 0 || height == 0) {
      return const _MaskAnalysis(
        foregroundPixels: 0,
        averageConfidence: 0.0,
        bounds: null,
      );
    }

    int foregroundCount = 0;
    double totalConfidence = 0.0;

    // Track bounds
    int minX = width;
    int maxX = 0;
    int minY = height;
    int maxY = 0;

    // Threshold for considering a pixel as foreground
    const double foregroundThreshold = 0.5;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = y * width + x;
        if (index < confidences.length) {
          final confidence = confidences[index];

          if (confidence >= foregroundThreshold) {
            foregroundCount++;
            totalConfidence += confidence;

            // Update bounds
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
    }

    if (foregroundCount == 0) {
      return const _MaskAnalysis(
        foregroundPixels: 0,
        averageConfidence: 0.0,
        bounds: null,
      );
    }

    final avgConfidence = totalConfidence / foregroundCount;

    // Normalize bounds to 0.0-1.0
    final normalizedBounds = NormalizedBoundingBox(
      left: minX / width,
      top: minY / height,
      right: (maxX + 1) / width,
      bottom: (maxY + 1) / height,
    );

    return _MaskAnalysis(
      foregroundPixels: foregroundCount,
      averageConfidence: avgConfidence,
      bounds: normalizedBounds,
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

  /// Close the segmenter and release resources
  void dispose() {
    _segmenter?.close();
    _segmenter = null;
  }
}

/// Internal helper for mask analysis results
class _MaskAnalysis {
  final int foregroundPixels;
  final double averageConfidence;
  final NormalizedBoundingBox? bounds;

  const _MaskAnalysis({
    required this.foregroundPixels,
    required this.averageConfidence,
    required this.bounds,
  });
}
