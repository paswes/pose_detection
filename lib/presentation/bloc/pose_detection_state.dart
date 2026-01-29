import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/domain/models/validation_result.dart';

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

  /// Current validated pose (only set if pose passed all validation gates)
  /// This is the "Human-Only Signal" - confirmed to be a real human
  final TimestampedPose? currentPose;

  /// Latest validation result (for debugging/metrics)
  final PoseValidationResult? lastValidation;

  final Size? imageSize;
  final PoseSession session;

  /// Whether validation is enabled
  final bool validationEnabled;

  Detecting({
    required this.cameraController,
    this.currentPose,
    this.lastValidation,
    this.imageSize,
    required this.session,
    this.validationEnabled = true,
  });

  /// Whether current frame has a valid human pose
  bool get hasValidPose => currentPose != null;

  /// Whether last validation resulted in a ghost pose rejection
  bool get lastPoseWasGhost =>
      lastValidation != null &&
      !lastValidation!.isValid &&
      lastValidation!.pose.landmarks.isNotEmpty;

  Detecting copyWith({
    TimestampedPose? currentPose,
    PoseValidationResult? lastValidation,
    Size? imageSize,
    PoseSession? session,
    bool? validationEnabled,
    bool clearCurrentPose = false,
  }) {
    return Detecting(
      cameraController: cameraController,
      currentPose: clearCurrentPose ? null : (currentPose ?? this.currentPose),
      lastValidation: lastValidation ?? this.lastValidation,
      imageSize: imageSize ?? this.imageSize,
      session: session ?? this.session,
      validationEnabled: validationEnabled ?? this.validationEnabled,
    );
  }

  @override
  List<Object?> get props => [
        cameraController,
        currentPose,
        lastValidation,
        imageSize,
        session,
        validationEnabled,
      ];
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
