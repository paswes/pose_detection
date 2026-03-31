import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

sealed class PoseDetectionEvent extends Equatable {
  const PoseDetectionEvent();

  @override
  List<Object?> get props => [];
}

class InitializeEvent extends PoseDetectionEvent {
  const InitializeEvent();
}

class StartCaptureEvent extends PoseDetectionEvent {
  const StartCaptureEvent();
}

class StopCaptureEvent extends PoseDetectionEvent {
  const StopCaptureEvent();
}

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

class SwitchCameraEvent extends PoseDetectionEvent {
  const SwitchCameraEvent();
}

class ChangeOrientationEvent extends PoseDetectionEvent {
  final DeviceOrientation orientation;

  const ChangeOrientationEvent(this.orientation);

  @override
  List<Object?> get props => [orientation];
}

class RecordingTickEvent extends PoseDetectionEvent {
  const RecordingTickEvent();
}

class StartRecordingEvent extends PoseDetectionEvent {
  const StartRecordingEvent();
}

class StopRecordingEvent extends PoseDetectionEvent {
  const StopRecordingEvent();
}

class SaveSessionEvent extends PoseDetectionEvent {
  final String title;

  const SaveSessionEvent({required this.title});

  @override
  List<Object?> get props => [title];
}

class DisposeEvent extends PoseDetectionEvent {
  const DisposeEvent();
}
