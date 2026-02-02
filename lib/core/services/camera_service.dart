import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';

/// Service responsible for camera lifecycle management.
/// Implements ICameraService for dependency injection.
class CameraService implements ICameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  @override
  bool get isStreamingImages =>
      isInitialized && _controller!.value.isStreamingImages;

  @override
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

  @override
  void startImageStream(Function(CameraImage) onImage) {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }

    _controller!.startImageStream(onImage);
  }

  @override
  void stopImageStream() {
    if (isInitialized && isStreamingImages) {
      _controller!.stopImageStream();
    }
  }

  @override
  CameraDescription? getCameraDescription() {
    if (_cameras == null || _cameras!.isEmpty) return null;
    return _cameras!.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
  }

  @override
  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _controller = null;
  }
}
