import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pose_detection/core/utils/transform_calculator.dart';

/// Widget for displaying fullscreen camera preview.
/// Uses BoxFit.cover to fill the screen while maintaining aspect ratio.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;

  const CameraPreviewWidget({
    super.key,
    required this.cameraController,
  });

  /// Calculates the BoxFit.cover transformation parameters.
  /// @deprecated Use TransformCalculator.calculateCoverTransform instead.
  @Deprecated('Use TransformCalculator.calculateCoverTransform instead')
  static ({double scale, Offset offset, Size fittedSize}) getImageToScreenTransform({
    required Size imageSize,
    required Size screenSize,
  }) {
    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: imageSize,
      screenSize: screenSize,
    );
    return (
      scale: transform.scale,
      offset: transform.offset,
      fittedSize: transform.fittedSize,
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
