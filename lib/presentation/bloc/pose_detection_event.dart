import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';

/// Events for generic PoseDetectionBloc
abstract class PoseDetectionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

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
  final int timestampMicros;

  ProcessFrameEvent(this.image, this.sensorOrientation, this.timestampMicros);

  @override
  List<Object?> get props => [image, sensorOrientation, timestampMicros];
}

/// Dispose resources
class DisposeEvent extends PoseDetectionEvent {}
