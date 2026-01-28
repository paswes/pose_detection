import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection/domain/models/pose_session.dart';

/// States for generic PoseDetectionBloc
abstract class PoseDetectionState {}

/// Initial state
class PoseDetectionInitial extends PoseDetectionState {}

/// Camera is initializing
class CameraInitializing extends PoseDetectionState {}

/// Camera initialized and ready to start capture
class CameraReady extends PoseDetectionState {
  final CameraController cameraController;
  final PoseSession? lastSession;

  CameraReady(this.cameraController, {this.lastSession});
}

/// Actively detecting poses
class Detecting extends PoseDetectionState {
  final CameraController cameraController;
  final Pose? currentPose;
  final Size? imageSize;
  final PoseSession session;

  Detecting({
    required this.cameraController,
    this.currentPose,
    this.imageSize,
    required this.session,
  });

  Detecting copyWith({
    Pose? currentPose,
    Size? imageSize,
    PoseSession? session,
  }) {
    return Detecting(
      cameraController: cameraController,
      currentPose: currentPose ?? this.currentPose,
      imageSize: imageSize ?? this.imageSize,
      session: session ?? this.session,
    );
  }
}

/// Session completed with summary
class SessionSummary extends PoseDetectionState {
  final CameraController cameraController;
  final PoseSession session;

  SessionSummary({
    required this.cameraController,
    required this.session,
  });
}

/// Error state
class PoseDetectionError extends PoseDetectionState {
  final String message;

  PoseDetectionError(this.message);
}
