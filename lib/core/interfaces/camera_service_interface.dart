import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

abstract class ICameraService {
  CameraController? get controller;

  bool get isInitialized;

  bool get isStreamingImages;

  CameraLensDirection get currentLensDirection;

  DeviceOrientation get currentOrientation;

  bool get canSwitchCamera;

  Future<void> initialize();

  void startImageStream(Function(CameraImage) onImage);

  void stopImageStream();

  Future<void> switchCamera();

  Future<void> setOrientation(DeviceOrientation orientation);

  bool get isRecordingVideo;

  Future<void> startVideoRecording();

  Future<XFile> stopVideoRecording();

  CameraDescription? getCameraDescription();

  void dispose();
}
