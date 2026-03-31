import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';

/// States for PoseDetectionBloc
sealed class PoseDetectionState extends Equatable {
  const PoseDetectionState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class PoseDetectionInitial extends PoseDetectionState {
  const PoseDetectionInitial();
}

/// Camera is initializing
class CameraInitializing extends PoseDetectionState {
  const CameraInitializing();
}

/// Camera initialized and ready to start capture
class CameraReady extends PoseDetectionState {
  final CameraController cameraController;

  // CameraController is mutable, so const is not possible.
  // ignore: prefer_const_constructors_in_immutables
  CameraReady(this.cameraController);

  @override
  List<Object?> get props => [cameraController];
}

/// Actively detecting poses with real-time metrics
class Detecting extends PoseDetectionState {
  final CameraController cameraController;
  final bool canSwitchCamera;
  final bool isFrontCamera;

  const Detecting({
    required this.cameraController,
    this.canSwitchCamera = false,
    this.isFrontCamera = false,
  });

  Detecting copyWith({
    bool? canSwitchCamera,
    bool? isFrontCamera,
  }) {
    return Detecting(
      cameraController: cameraController,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  @override
  List<Object?> get props => [
    cameraController,
    canSwitchCamera,
    isFrontCamera,
  ];
}

/// Actively recording a session (video + pose tracking)
class Recording extends PoseDetectionState {
  final CameraController cameraController;
  final DetectedPose? currentPose;
  final bool isFrontCamera;
  final bool isPersonDetected;
  final Duration recordingDuration;
  final int frameCount;

  const Recording({
    required this.cameraController,
    this.currentPose,
    this.isFrontCamera = false,
    this.isPersonDetected = false,
    this.recordingDuration = Duration.zero,
    this.frameCount = 0,
  });

  Recording copyWith({
    DetectedPose? currentPose,
    bool clearPose = false,
    bool? isPersonDetected,
    Duration? recordingDuration,
    int? frameCount,
  }) {
    return Recording(
      cameraController: cameraController,
      currentPose: clearPose ? null : (currentPose ?? this.currentPose),
      isFrontCamera: isFrontCamera,
      isPersonDetected: isPersonDetected ?? this.isPersonDetected,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      frameCount: frameCount ?? this.frameCount,
    );
  }

  @override
  List<Object?> get props => [
    cameraController,
    currentPose,
    isFrontCamera,
    isPersonDetected,
    recordingDuration,
    frameCount,
  ];
}

/// Recording stopped, waiting for user to provide title
class RecordingStopped extends PoseDetectionState {
  const RecordingStopped();
}

/// Session saved successfully after recording
class SessionSaved extends PoseDetectionState {
  final String sessionId;

  const SessionSaved(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

/// Saving session in progress
class SavingSession extends PoseDetectionState {
  const SavingSession();
}

/// Error state
class PoseDetectionError extends PoseDetectionState {
  final String message;

  const PoseDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}
