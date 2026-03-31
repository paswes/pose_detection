import 'dart:ui';
import 'package:pose_detection/core/utils/transform_calculator.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';

/// How the video/image is fitted into the widget.
enum FitMode { cover, contain }

/// Utility class for coordinate space transformations.
///
/// Handles transformation from image space (pixels from ML Kit)
/// to widget space (pixels for UI rendering).
///
/// CRITICAL: Uses the EXACT same transformation logic as
/// the video/camera display widget to ensure pixel-perfect overlay alignment.
class CoordinateTranslator {
  /// Translates raw image coordinates to widget coordinates for UI rendering.
  static Offset translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize, {
    FitMode fitMode = FitMode.cover,
  }) {
    final transform = _getTransform(imageSize, widgetSize, fitMode);

    return Offset(
      x * transform.scale + transform.offset.dx,
      y * transform.scale + transform.offset.dy,
    );
  }

  /// Translate a Landmark to widget space for rendering
  static Offset translateLandmark(
    Landmark landmark,
    Size imageSize,
    Size widgetSize, {
    FitMode fitMode = FitMode.cover,
  }) {
    return translatePoint(
      landmark.x,
      landmark.y,
      imageSize,
      widgetSize,
      fitMode: fitMode,
    );
  }

  /// Pre-compute all landmark translations for a pose.
  /// Returns a Map from landmark ID to screen position.
  static Map<int, Offset> translateAllLandmarks(
    List<Landmark> landmarks,
    Size imageSize,
    Size widgetSize, {
    FitMode fitMode = FitMode.cover,
  }) {
    final transform = _getTransform(imageSize, widgetSize, fitMode);

    final result = <int, Offset>{};
    for (final landmark in landmarks) {
      result[landmark.id] = Offset(
        landmark.x * transform.scale + transform.offset.dx,
        landmark.y * transform.scale + transform.offset.dy,
      );
    }
    return result;
  }

  /// Pre-compute translations with Z-depth information.
  /// Returns a Map from landmark ID to a record containing position and depth.
  static Map<int, ({Offset position, double normalizedDepth})>
  translateAllLandmarksWithDepth(
    List<Landmark> landmarks,
    Size imageSize,
    Size widgetSize, {
    FitMode fitMode = FitMode.cover,
    double alignY = 0.5,
  }) {
    final transform = _getTransform(
      imageSize,
      widgetSize,
      fitMode,
      alignY: alignY,
    );

    // Calculate Z-range for normalization
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;
    for (final landmark in landmarks) {
      if (landmark.z < minZ) minZ = landmark.z;
      if (landmark.z > maxZ) maxZ = landmark.z;
    }
    final zRange = maxZ - minZ;
    final hasValidZRange = zRange > 0.001;

    final result = <int, ({Offset position, double normalizedDepth})>{};
    for (final landmark in landmarks) {
      final normalizedDepth = hasValidZRange
          ? 1.0 - ((landmark.z - minZ) / zRange)
          : 0.5;

      result[landmark.id] = (
        position: Offset(
          landmark.x * transform.scale + transform.offset.dx,
          landmark.y * transform.scale + transform.offset.dy,
        ),
        normalizedDepth: normalizedDepth.clamp(0.0, 1.0),
      );
    }
    return result;
  }

  static ImageTransform _getTransform(
    Size imageSize,
    Size widgetSize,
    FitMode fitMode, {
    double alignY = 0.5,
  }) {
    return switch (fitMode) {
      FitMode.cover => TransformCalculator.calculateCoverTransform(
        imageSize: imageSize,
        screenSize: widgetSize,
      ),
      FitMode.contain => TransformCalculator.calculateContainTransform(
        imageSize: imageSize,
        screenSize: widgetSize,
        alignY: alignY,
      ),
    };
  }
}
