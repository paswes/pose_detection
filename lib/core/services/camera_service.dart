import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';

class CameraService implements ICameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraLensDirection _currentDirection = CameraLensDirection.back;
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;
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
  DeviceOrientation get currentOrientation => _currentOrientation;

  @override
  bool get canSwitchCamera {
    if (_cameras == null) return false;
    final hasBack = _cameras!.any(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    final hasFront = _cameras!.any(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
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

  Future<void> _initializeCameraWithDirection(
    CameraLensDirection direction, [
    DeviceOrientation? orientation,
  ]) async {
    final camera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => _cameras!.first,
    );

    _currentDirection = camera.lensDirection;
    _currentOrientation = orientation ?? DeviceOrientation.portraitUp;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    await _controller!.lockCaptureOrientation(_currentOrientation);
  }

  @override
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;

    final wasStreaming = isStreamingImages;
    final callback = _imageStreamCallback;

    if (wasStreaming) {
      stopImageStream();
    }

    await _controller?.dispose();
    _controller = null;

    final newDirection = _currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await _initializeCameraWithDirection(newDirection);

    if (wasStreaming && callback != null) {
      startImageStream(callback);
    }
  }

  @override
  Future<void> setOrientation(DeviceOrientation orientation) async {
    if (_currentOrientation == orientation) return;

    final wasStreaming = isStreamingImages;
    final callback = _imageStreamCallback;

    if (wasStreaming) {
      stopImageStream();
    }

    await _controller?.dispose();
    _controller = null;

    await _initializeCameraWithDirection(_currentDirection, orientation);

    if (wasStreaming && callback != null) {
      startImageStream(callback);
    }
  }

  @override
  bool get isRecordingVideo =>
      isInitialized && _controller!.value.isRecordingVideo;

  @override
  Future<void> startVideoRecording() async {
    if (!isInitialized) throw Exception('Camera not initialized');
    await _controller!.startVideoRecording();
  }

  @override
  Future<XFile> stopVideoRecording() async {
    if (!isInitialized) throw Exception('Camera not initialized');
    return await _controller!.stopVideoRecording();
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
