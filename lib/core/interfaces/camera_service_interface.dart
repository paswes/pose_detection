import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Abstract interface for camera operations.
/// Enables mocking for tests and alternative implementations.
abstract class ICameraService {
  /// The underlying camera controller
  CameraController? get controller;

  /// Whether the camera has been initialized
  bool get isInitialized;

  /// Whether the camera is currently streaming images
  bool get isStreamingImages;

  /// Current camera lens direction (front or back)
  CameraLensDirection get currentLensDirection;

  /// Current capture orientation
  DeviceOrientation get currentOrientation;

  /// Whether the device has multiple cameras and can switch
  bool get canSwitchCamera;

  /// Initialize the camera
  Future<void> initialize();

  /// Start streaming camera images
  void startImageStream(Function(CameraImage) onImage);

  /// Stop streaming camera images
  void stopImageStream();

  /// Switch between front and back camera
  /// Handles stopping stream, disposing, reinitializing, and restarting stream
  Future<void> switchCamera();

  /// Change capture orientation (portrait/landscape)
  /// Handles stopping stream, disposing, reinitializing with new orientation, and restarting stream
  Future<void> setOrientation(DeviceOrientation orientation);

  /// Whether the camera is currently recording video
  bool get isRecordingVideo;

  /// Start video recording
  Future<void> startVideoRecording();

  /// Stop video recording and return the file
  Future<XFile> stopVideoRecording();

  /// Get the camera description
  CameraDescription? getCameraDescription();

  /// Dispose camera resources
  void dispose();
}
