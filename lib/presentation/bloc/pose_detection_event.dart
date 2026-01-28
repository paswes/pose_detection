import 'package:camera/camera.dart';

/// Events for generic PoseDetectionBloc
abstract class PoseDetectionEvent {}

/// Initialize camera and services
class InitializeEvent extends PoseDetectionEvent {}

/// Start a new pose capture session
class StartCaptureEvent extends PoseDetectionEvent {}

/// Stop the current capture session
class StopCaptureEvent extends PoseDetectionEvent {}

/// Process a camera image frame
class ProcessFrameEvent extends PoseDetectionEvent {
  final CameraImage image;
  final int sensorOrientation;

  ProcessFrameEvent(this.image, this.sensorOrientation);
}

/// Dispose resources
class DisposeEvent extends PoseDetectionEvent {}
