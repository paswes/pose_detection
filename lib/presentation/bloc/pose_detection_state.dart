import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';

/// States for generic PoseDetectionBloc
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
  final PoseSession? lastSession;

  CameraReady(this.cameraController, {this.lastSession});

  @override
  List<Object?> get props => [cameraController, lastSession];
}

/// Actively detecting poses with real-time metrics
class Detecting extends PoseDetectionState {
  final CameraController cameraController;
  final TimestampedPose? currentPose;
  final Size? imageSize;
  final PoseSession session;

  Detecting({
    required this.cameraController,
    this.currentPose,
    this.imageSize,
    required this.session,
  });

  Detecting copyWith({
    TimestampedPose? currentPose,
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

  @override
  List<Object?> get props => [cameraController, currentPose, imageSize, session];
}

/// Session completed with summary
class SessionSummary extends PoseDetectionState {
  final CameraController cameraController;
  final PoseSession session;

  SessionSummary({
    required this.cameraController,
    required this.session,
  });

  @override
  List<Object?> get props => [cameraController, session];
}

/// Error state
class PoseDetectionError extends PoseDetectionState {
  final String message;

  PoseDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}
