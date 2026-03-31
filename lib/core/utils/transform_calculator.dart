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

/// Calculator for BoxFit transformations.
/// Pure math utility - no UI dependencies.
class TransformCalculator {
  /// Calculates the BoxFit.cover transformation parameters.
  /// This MUST match the exact behavior of FittedBox with BoxFit.cover.
  static ImageTransform calculateCoverTransform({
    required Size imageSize,
    required Size screenSize,
  }) {
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    final scale = scaleX > scaleY ? scaleX : scaleY;

    final fittedWidth = imageSize.width * scale;
    final fittedHeight = imageSize.height * scale;

    final offsetX = (screenSize.width - fittedWidth) / 2;
    final offsetY = (screenSize.height - fittedHeight) / 2;

    return ImageTransform(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      fittedSize: Size(fittedWidth, fittedHeight),
    );
  }

  /// Calculates the BoxFit.contain transformation parameters.
  /// Fits the entire source inside the target, potentially letterboxing.
  ///
  /// [alignY] controls vertical placement of the fitted image: 0.0 = top,
  /// 0.5 = center (default), 1.0 = bottom.
  static ImageTransform calculateContainTransform({
    required Size imageSize,
    required Size screenSize,
    double alignY = 0.5,
  }) {
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    final fittedWidth = imageSize.width * scale;
    final fittedHeight = imageSize.height * scale;

    final offsetX = (screenSize.width - fittedWidth) / 2;
    final offsetY = (screenSize.height - fittedHeight) * alignY;

    return ImageTransform(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      fittedSize: Size(fittedWidth, fittedHeight),
    );
  }
}
