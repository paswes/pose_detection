import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';
import 'package:pose_detection/domain/models/person_detection_result.dart';

/// States for PoseDetectionBloc
abstract class PoseDetectionState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state
class PoseDetectionInitial extends PoseDetectionState {}

/// Camera is initializing
class CameraInitializing extends PoseDetectionState {}

/// Camera initialized and ready to start capture
class CameraReady extends PoseDetectionState {
  final CameraController cameraController;

  CameraReady(this.cameraController);

  @override
  List<Object?> get props => [cameraController];
}

/// Actively detecting poses with real-time metrics
class Detecting extends PoseDetectionState {
  final CameraController cameraController;
  final DetectedPose? currentPose;
  final DetectionMetrics metrics;
  final bool canSwitchCamera;
  final bool isFrontCamera;
  final PersonDetectionResult personDetection;

  Detecting({
    required this.cameraController,
    this.currentPose,
    this.metrics = const DetectionMetrics(),
    this.canSwitchCamera = false,
    this.isFrontCamera = false,
    PersonDetectionResult? personDetection,
  }) : personDetection = personDetection ?? PersonDetectionResult.noPose();

  Detecting copyWith({
    DetectedPose? currentPose,
    DetectionMetrics? metrics,
    bool? canSwitchCamera,
    bool? isFrontCamera,
    PersonDetectionResult? personDetection,
  }) {
    return Detecting(
      cameraController: cameraController,
      currentPose: currentPose ?? this.currentPose,
      metrics: metrics ?? this.metrics,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      personDetection: personDetection ?? this.personDetection,
    );
  }

  @override
  List<Object?> get props => [cameraController, currentPose, metrics, canSwitchCamera, isFrontCamera, personDetection];
}

/// Actively recording a session (video + pose tracking)
class Recording extends PoseDetectionState {
  final CameraController cameraController;
  final DetectedPose? currentPose;
  final DetectionMetrics metrics;
  final bool isFrontCamera;
  final PersonDetectionResult personDetection;
  final Duration recordingDuration;
  final int frameCount;

  Recording({
    required this.cameraController,
    this.currentPose,
    this.metrics = const DetectionMetrics(),
    this.isFrontCamera = false,
    PersonDetectionResult? personDetection,
    this.recordingDuration = Duration.zero,
    this.frameCount = 0,
  }) : personDetection = personDetection ?? PersonDetectionResult.noPose();

  Recording copyWith({
    DetectedPose? currentPose,
    DetectionMetrics? metrics,
    PersonDetectionResult? personDetection,
    Duration? recordingDuration,
    int? frameCount,
  }) {
    return Recording(
      cameraController: cameraController,
      currentPose: currentPose ?? this.currentPose,
      metrics: metrics ?? this.metrics,
      isFrontCamera: isFrontCamera,
      personDetection: personDetection ?? this.personDetection,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      frameCount: frameCount ?? this.frameCount,
    );
  }

  @override
  List<Object?> get props => [
    cameraController, currentPose, metrics, isFrontCamera,
    personDetection, recordingDuration, frameCount,
  ];
}

/// Recording stopped, waiting for user to provide title
class RecordingStopped extends PoseDetectionState {}

/// Session saved successfully after recording
class SessionSaved extends PoseDetectionState {
  final String sessionId;

  SessionSaved(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

/// Saving session in progress
class SavingSession extends PoseDetectionState {}

/// Error state
class PoseDetectionError extends PoseDetectionState {
  final String message;

  PoseDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}
