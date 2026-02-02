import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';

/// Service responsible for camera lifecycle management.
/// Implements ICameraService for dependency injection.
class CameraService implements ICameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraLensDirection _currentDirection = CameraLensDirection.back;
  Function(CameraImage)? _imageStreamCallback;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  @override
  bool get isStreamingImages =>
      isInitialized && _controller!.value.isStreamingImages;

  @override
  CameraLensDirection get currentLensDirection => _currentDirection;

  @override
  bool get canSwitchCamera {
    if (_cameras == null) return false;
    final hasBack = _cameras!.any((c) => c.lensDirection == CameraLensDirection.back);
    final hasFront = _cameras!.any((c) => c.lensDirection == CameraLensDirection.front);
    return hasBack && hasFront;
  }

  @override
  Future<void> initialize() async {
    _cameras = await availableCameras();

    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    await _initializeCameraWithDirection(_currentDirection);
  }

  Future<void> _initializeCameraWithDirection(CameraLensDirection direction) async {
    // Find camera with requested direction, fallback to first available
    final camera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => _cameras!.first,
    );

    _currentDirection = camera.lensDirection;

    _controller = CameraController(
      camera,
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
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;

    // Save current streaming state and callback
    final wasStreaming = isStreamingImages;
    final callback = _imageStreamCallback;

    // Stop current stream
    if (wasStreaming) {
      stopImageStream();
    }

    // Dispose current controller
    await _controller?.dispose();
    _controller = null;

    // Switch direction
    final newDirection = _currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    // Initialize with new direction
    await _initializeCameraWithDirection(newDirection);

    // Restart stream if was streaming
    if (wasStreaming && callback != null) {
      startImageStream(callback);
    }
  }

  @override
  void startImageStream(Function(CameraImage) onImage) {
    if (!isInitialized) {
      throw Exception('Camera not initialized');
    }

    _imageStreamCallback = onImage;
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
      (cam) => cam.lensDirection == _currentDirection,
      orElse: () => _cameras!.first,
    );
  }

  @override
  void dispose() {
    stopImageStream();
    _imageStreamCallback = null;
    _controller?.dispose();
    _controller = null;
  }
}
