import 'dart:ui';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/presentation/widgets/camera_preview_widget.dart';

/// Utility class for coordinate space transformations
///
/// Handles three coordinate spaces:
/// 1. Raw image space (pixels from ML Kit)
/// 2. Normalized space (0.0 to 1.0, resolution-independent)
/// 3. Widget space (pixels for UI rendering with BoxFit.cover)
///
/// CRITICAL: This class uses the EXACT same transformation logic as
/// [CameraPreviewWidget] to ensure pixel-perfect overlay alignment.
class CoordinateTranslator {
  /// Normalize coordinates to resolution-independent space (0.0 to 1.0)
  /// This is critical for motion analysis across different devices
  ///
  /// IMPORTANT NOTE ON Z COORDINATE:
  /// ML Kit's Z coordinate is a depth estimate relative to the hip midpoint,
  /// measured in a scaled unit that is NOT pixels. The scale is approximately
  /// the same as X/Y pixel coordinates, but represents depth rather than screen position.
  ///
  /// For 3D motion analysis:
  /// - X and Y are normalized to 0.0-1.0 (resolution-independent)
  /// - Z is kept in its raw form (depth estimate in arbitrary units)
  /// - This creates intentionally mixed units in NormalizedLandmark
  ///
  /// Downstream consumers should:
  /// - Use normalized X/Y for 2D position analysis
  /// - Use raw Z for relative depth comparisons only
  /// - NOT mix Z with X/Y in distance calculations without conversion
  static NormalizedLandmark normalize(RawLandmark raw, Size imageSize) {
    return NormalizedLandmark(
      id: raw.id,
      x: raw.x / imageSize.width,
      y: raw.y / imageSize.height,
      z: raw.z, // Z is depth estimate, preserved in raw form (see doc above)
      likelihood: raw.likelihood,
    );
  }

  /// Batch normalize all landmarks in a pose
  static List<NormalizedLandmark> normalizeAll(
    List<RawLandmark> rawLandmarks,
    Size imageSize,
  ) {
    return rawLandmarks
        .map((raw) => normalize(raw, imageSize))
        .toList(growable: false);
  }

  /// Translates raw image coordinates to widget coordinates for UI rendering.
  /// Uses BoxFit.cover scaling to EXACTLY match camera preview display.
  ///
  /// This method delegates to [CameraPreviewWidget.getImageToScreenTransform]
  /// to ensure the transformation is identical to the camera preview rendering.
  static Offset translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = CameraPreviewWidget.getImageToScreenTransform(
      imageSize: imageSize,
      screenSize: widgetSize,
    );

    final translatedX = x * transform.scale + transform.offset.dx;
    final translatedY = y * transform.scale + transform.offset.dy;

    return Offset(translatedX, translatedY);
  }

  /// Translate a RawLandmark to widget space for rendering
  static Offset translateLandmark(
    RawLandmark landmark,
    Size imageSize,
    Size widgetSize,
  ) {
    return translatePoint(landmark.x, landmark.y, imageSize, widgetSize);
  }

  /// Pre-compute all landmark translations for a pose.
  /// Returns a Map from landmark ID to screen position.
  ///
  /// This is more efficient than calling translateLandmark repeatedly
  /// when drawing connections, as each landmark is translated only once.
  static Map<int, Offset> translateAllLandmarks(
    List<RawLandmark> landmarks,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = CameraPreviewWidget.getImageToScreenTransform(
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
    List<RawLandmark> landmarks,
    Size imageSize,
    Size widgetSize,
  ) {
    final transform = CameraPreviewWidget.getImageToScreenTransform(
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
    final hasValidZRange = zRange > 0.001; // Avoid division by near-zero

    final result = <int, ({Offset position, double normalizedDepth})>{};
    for (final landmark in landmarks) {
      // Normalize Z to 0.0-1.0 range (0 = furthest, 1 = closest)
      // Note: More negative Z = closer to camera in ML Kit convention
      final normalizedDepth = hasValidZRange
          ? 1.0 - ((landmark.z - minZ) / zRange) // Invert so closer = higher
          : 0.5; // Default to middle if no Z variance

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
