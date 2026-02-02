import 'package:camera/camera.dart';

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

  /// Get the camera description
  CameraDescription? getCameraDescription();

  /// Dispose camera resources
  void dispose();
}
