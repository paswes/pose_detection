import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';

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

  Detecting({
    required this.cameraController,
    this.currentPose,
    this.metrics = const DetectionMetrics(),
    this.canSwitchCamera = false,
    this.isFrontCamera = false,
  });

  Detecting copyWith({
    DetectedPose? currentPose,
    DetectionMetrics? metrics,
    bool? canSwitchCamera,
    bool? isFrontCamera,
  }) {
    return Detecting(
      cameraController: cameraController,
      currentPose: currentPose ?? this.currentPose,
      metrics: metrics ?? this.metrics,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  @override
  List<Object?> get props => [cameraController, currentPose, metrics, canSwitchCamera, isFrontCamera];
}

/// Error state
class PoseDetectionError extends PoseDetectionState {
  final String message;

  PoseDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}
