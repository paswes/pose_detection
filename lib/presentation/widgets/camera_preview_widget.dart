import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Widget for displaying fullscreen camera preview
///
/// Uses BoxFit.cover to fill the screen while maintaining aspect ratio.
/// The actual image dimensions and screen size are exposed via [getImageToScreenTransform]
/// for synchronized coordinate mapping in overlay painters.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;

  const CameraPreviewWidget({
    super.key,
    required this.cameraController,
  });

  /// Calculates the BoxFit.cover transformation parameters.
  /// Returns a record with scale factor and offset for coordinate translation.
  ///
  /// This MUST match the exact behavior of FittedBox with BoxFit.cover.
  static ({double scale, Offset offset, Size fittedSize}) getImageToScreenTransform({
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

    return (
      scale: scale,
      offset: Offset(offsetX, offsetY),
      fittedSize: Size(fittedWidth, fittedHeight),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Get the actual camera image dimensions (width x height in pixels)
    // Note: previewSize is in landscape orientation (width > height typically)
    final previewSize = cameraController.value.previewSize;
    if (previewSize == null) {
      return const Center(
        child: Text(
          'Camera preview size unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // For portrait mode on iOS, the image comes rotated:
    // previewSize.width is the shorter dimension (portrait width)
    // previewSize.height is the longer dimension (portrait height)
    // We need to use the image as-is since ML Kit coordinates match this orientation
    final imageWidth = previewSize.height; // Swap for portrait
    final imageHeight = previewSize.width;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: imageWidth,
          height: imageHeight,
          child: CameraPreview(cameraController),
        ),
      ),
    );
  }
}
