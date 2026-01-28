import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Widget for displaying fullscreen camera preview
class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;

  const CameraPreviewWidget({
    super.key,
    required this.cameraController,
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

    // Calculate aspect ratio for fullscreen - EXACT from original
    final size = MediaQuery.of(context).size;
    final cameraAspectRatio = cameraController.value.aspectRatio;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.width * cameraAspectRatio,
          child: CameraPreview(cameraController),
        ),
      ),
    );
  }
}
