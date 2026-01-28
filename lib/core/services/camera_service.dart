import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Service responsible for camera lifecycle management
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraController? get controller => _controller;
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;
  bool get isStreamingImages =>
      isInitialized && _controller!.value.isStreamingImages;

  /// Initialize the camera with back-facing lens
  Future<void> initialize() async {
    _cameras = await availableCameras();

    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    // Find the back camera
    final backCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    // Lock camera orientation to portrait
    await _controller!.lockCaptureOrientation(
      DeviceOrientation.portraitUp,
    );
  }

  /// Start streaming camera images
  void startImageStream(Function(CameraImage) onImage) {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }

    _controller!.startImageStream(onImage);
  }

  /// Stop streaming camera images
  void stopImageStream() {
    if (isInitialized && isStreamingImages) {
      _controller!.stopImageStream();
    }
  }

  /// Get camera description
  CameraDescription? getCameraDescription() {
    if (_cameras == null || _cameras!.isEmpty) return null;
    return _cameras!.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
  }

  /// Dispose camera resources
  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _controller = null;
  }
}
