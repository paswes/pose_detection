import 'dart:ui';

/// Transform parameters for coordinate mapping.
/// Represents BoxFit.cover transformation.
class ImageTransform {
  final double scale;
  final Offset offset;
  final Size fittedSize;

  const ImageTransform({
    required this.scale,
    required this.offset,
    required this.fittedSize,
  });
}

/// Calculator for BoxFit.cover transformations.
/// Pure math utility - no UI dependencies.
class TransformCalculator {
  /// Calculates the BoxFit.cover transformation parameters.
  /// This MUST match the exact behavior of FittedBox with BoxFit.cover.
  static ImageTransform calculateCoverTransform({
    required Size imageSize,
    required Size screenSize,
  }) {
    // BoxFit.cover: Scale uniformly to cover the entire target,
    // potentially clipping parts of the source.
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    // Use the LARGER scale to ensure full coverage (BoxFit.cover behavior)
    final scale = scaleX > scaleY ? scaleX : scaleY;

    // Calculate the fitted image size after scaling
    final fittedWidth = imageSize.width * scale;
    final fittedHeight = imageSize.height * scale;

    // Center offset (parts extending beyond screen are clipped)
    final offsetX = (screenSize.width - fittedWidth) / 2;
    final offsetY = (screenSize.height - fittedHeight) / 2;

    return ImageTransform(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      fittedSize: Size(fittedWidth, fittedHeight),
    );
  }
}
