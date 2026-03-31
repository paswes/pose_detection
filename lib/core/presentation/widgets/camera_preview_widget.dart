import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Widget for displaying fullscreen camera preview.
/// Uses BoxFit.cover to fill the screen while maintaining aspect ratio.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final bool isLandscape;

  const CameraPreviewWidget({
    super.key,
    required this.cameraController,
    this.isLandscape = false,
  });

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

    // Determine image dimensions based on camera orientation
    final double imageWidth;
    final double imageHeight;

    if (isLandscape) {
      imageWidth = previewSize.width;
      imageHeight = previewSize.height;
    } else {
      // Portrait mode on iOS: the image comes rotated, so swap dimensions
      // previewSize.width is the shorter dimension (portrait width)
      // previewSize.height is the longer dimension (portrait height)
      imageWidth = previewSize.height;
      imageHeight = previewSize.width;
    }

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
