import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';

sealed class PoseDetectionState extends Equatable {
  const PoseDetectionState();

  @override
  List<Object?> get props => [];
}

class PoseDetectionInitial extends PoseDetectionState {
  const PoseDetectionInitial();
}

class CameraInitializing extends PoseDetectionState {
  const CameraInitializing();
}

class CameraReady extends PoseDetectionState {
  final CameraController cameraController;

  const CameraReady(this.cameraController);

  @override
  List<Object?> get props => [cameraController];
}

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

class RecordingStopped extends PoseDetectionState {
  const RecordingStopped();
}

class SessionSaved extends PoseDetectionState {
  final String sessionId;

  const SessionSaved(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class SavingSession extends PoseDetectionState {
  const SavingSession();
}

class PoseDetectionError extends PoseDetectionState {
  final String message;

  const PoseDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}
