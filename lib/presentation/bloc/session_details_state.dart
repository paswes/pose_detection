import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';

import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// States for the session details playback screen.
sealed class SessionDetailsState extends Equatable {
  const SessionDetailsState();

  @override
  List<Object?> get props => [];
}

/// Loading session data from database.
class SessionDetailsLoading extends SessionDetailsState {
  const SessionDetailsLoading();
}

/// Decoding video frames to images — shows progress.
class SessionDetailsDecoding extends SessionDetailsState {
  final int completed;
  final int total;

  const SessionDetailsDecoding({
    required this.completed,
    required this.total,
  });

  double get progress => total > 0 ? completed / total : 0.0;

  @override
  List<Object?> get props => [completed, total];
}

/// Frames decoded and ready for playback.
class SessionDetailsLoaded extends SessionDetailsState {
  final Session session;
  final List<TrackedFrame> frames;
  final List<ui.Image> frameImages;
  final int currentFrameIndex;
  final int? selectedLandmarkId;

  const SessionDetailsLoaded({
    required this.session,
    required this.frames,
    required this.frameImages,
    this.currentFrameIndex = 0,
    this.selectedLandmarkId,
  });

  int get totalFrames => frames.length;

  TrackedFrame? get currentFrame =>
      currentFrameIndex < frames.length ? frames[currentFrameIndex] : null;

  ui.Image? get currentImage =>
      currentFrameIndex < frameImages.length
          ? frameImages[currentFrameIndex]
          : null;

  SessionDetailsLoaded copyWith({
    int? currentFrameIndex,
    int? Function()? selectedLandmarkId,
  }) {
    return SessionDetailsLoaded(
      session: session,
      frames: frames,
      frameImages: frameImages,
      currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
      selectedLandmarkId: selectedLandmarkId != null
          ? selectedLandmarkId()
          : this.selectedLandmarkId,
    );
  }

  @override
  List<Object?> get props => [
    session.id,
    currentFrameIndex,
    selectedLandmarkId,
    totalFrames,
  ];
}

/// Error loading session or decoding frames.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
