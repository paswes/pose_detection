import 'dart:ui';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Utility class for coordinate space transformations
///
/// Handles three coordinate spaces:
/// 1. Raw image space (pixels from ML Kit)
/// 2. Normalized space (0.0 to 1.0, resolution-independent)
/// 3. Widget space (pixels for UI rendering with BoxFit.cover)
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
  /// Uses BoxFit.cover scaling to match camera preview display.
  ///
  /// This maintains aspect ratio and centers the image in the widget.
  static Offset translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize,
  ) {
    // Calculate scale factors
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    // Use the same scale for both axes to maintain aspect ratio
    // The camera preview uses BoxFit.cover, so we use the larger scale
    final scale = scaleX > scaleY ? scaleX : scaleY;

    // Calculate offset to center the scaled image
    final offsetX = (widgetSize.width - imageSize.width * scale) / 2;
    final offsetY = (widgetSize.height - imageSize.height * scale) / 2;

    final translatedX = x * scale + offsetX;
    final translatedY = y * scale + offsetY;

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
}
