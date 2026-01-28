import 'dart:ui';

/// Utility class to translate ML Kit landmark coordinates to widget coordinates.
///
/// CRITICAL: This preserves the exact scaling logic from the original PoC.
/// The coordinate system transformation accounts for:
/// - Aspect ratio differences between camera image and display widget
/// - BoxFit.cover behavior used in camera preview
class CoordinateTranslator {
  /// Translates ML Kit landmark coordinates to widget coordinates.
  /// ML Kit returns coordinates relative to the input image size.
  /// We need to scale these to match the displayed widget size.
  static Offset translatePoint(
    double x,
    double y,
    Size imageSize,
    Size widgetSize,
  ) {
    // The image from camera is typically rotated 90° on iOS
    // ML Kit handles rotation internally, but we need to account for
    // the aspect ratio difference between image and display.

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
}
