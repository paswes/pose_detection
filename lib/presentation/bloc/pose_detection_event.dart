import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

/// Events for generic PoseDetectionBloc
sealed class PoseDetectionEvent extends Equatable {
  const PoseDetectionEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize camera and services
class InitializeEvent extends PoseDetectionEvent {
  const InitializeEvent();
}

/// Start a new pose capture session
class StartCaptureEvent extends PoseDetectionEvent {
  const StartCaptureEvent();
}

/// Stop the current capture session
class StopCaptureEvent extends PoseDetectionEvent {
  const StopCaptureEvent();
}

/// Process a camera image frame
class ProcessFrameEvent extends PoseDetectionEvent {
  final CameraImage image;
  final int sensorOrientation;
  final int timestampMicros;

  const ProcessFrameEvent(
    this.image,
    this.sensorOrientation,
    this.timestampMicros,
  );

  @override
  List<Object?> get props => [image, sensorOrientation, timestampMicros];
}

/// Switch between front and back camera
class SwitchCameraEvent extends PoseDetectionEvent {
  const SwitchCameraEvent();
}

/// Change device orientation (portrait/landscape)
class ChangeOrientationEvent extends PoseDetectionEvent {
  final DeviceOrientation orientation;

  const ChangeOrientationEvent(this.orientation);

  @override
  List<Object?> get props => [orientation];
}

/// Tick to update recording duration (internal, fired by timer)
class RecordingTickEvent extends PoseDetectionEvent {
  const RecordingTickEvent();
}

/// Start recording a session (video + pose tracking)
class StartRecordingEvent extends PoseDetectionEvent {
  const StartRecordingEvent();
}

/// Stop recording (video + image stream stop immediately)
class StopRecordingEvent extends PoseDetectionEvent {
  const StopRecordingEvent();
}

/// Save the stopped recording with a title
class SaveSessionEvent extends PoseDetectionEvent {
  final String title;

  const SaveSessionEvent({required this.title});

  @override
  List<Object?> get props => [title];
}

/// Dispose resources
class DisposeEvent extends PoseDetectionEvent {
  const DisposeEvent();
}
