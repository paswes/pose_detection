import 'dart:ui';
import 'package:pose_detection/core/utils/transform_calculator.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Utility class for coordinate space transformations.
///
/// Handles transformation from image space (pixels from ML Kit)
/// to widget space (pixels for UI rendering with BoxFit.cover).
///
/// CRITICAL: Uses the EXACT same transformation logic as
/// [CameraPreviewWidget] to ensure pixel-perfect overlay alignment.
class CoordinateTranslator {
  /// Translates raw image coordinates to widget coordinates for UI rendering.
  /// Uses BoxFit.cover scaling to EXACTLY match camera preview display.
  static Offset translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: imageSize,
      screenSize: widgetSize,
    );

    return Offset(
      x * transform.scale + transform.offset.dx,
      y * transform.scale + transform.offset.dy,
    );
  }

  /// Translate a Landmark to widget space for rendering
  static Offset translateLandmark(
    Landmark landmark,
    Size imageSize,
    Size widgetSize,
  ) {
    return translatePoint(landmark.x, landmark.y, imageSize, widgetSize);
  }

  /// Pre-compute all landmark translations for a pose.
  /// Returns a Map from landmark ID to screen position.
  ///
  /// More efficient than calling translateLandmark repeatedly
  /// when drawing connections, as each landmark is translated only once.
  static Map<int, Offset> translateAllLandmarks(
    List<Landmark> landmarks,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: imageSize,
      screenSize: widgetSize,
    );

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
  ///
  /// The depth value is normalized relative to the pose's Z-range for visualization.
  static Map<int, ({Offset position, double normalizedDepth})>
  translateAllLandmarksWithDepth(
    List<Landmark> landmarks,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: imageSize,
      screenSize: widgetSize,
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
      // Normalize Z to 0.0-1.0 range (0 = furthest, 1 = closest)
      // Note: More negative Z = closer to camera in ML Kit convention
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
}
