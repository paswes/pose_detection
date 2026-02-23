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

/// Loading session data and preparing first frame.
class SessionDetailsLoading extends SessionDetailsState {
  const SessionDetailsLoading();
}

/// Frames loaded and ready for playback.
class SessionDetailsLoaded extends SessionDetailsState {
  final Session session;
  final List<TrackedFrame> frames;
  final ui.Image? currentImage;
  final int currentFrameIndex;
  final int? selectedLandmarkId;
  final bool isAutoPlaying;

  const SessionDetailsLoaded({
    required this.session,
    required this.frames,
    this.currentImage,
    this.currentFrameIndex = 0,
    this.selectedLandmarkId,
    this.isAutoPlaying = false,
  });

  int get totalFrames => frames.length;

  TrackedFrame? get currentFrame =>
      currentFrameIndex < frames.length ? frames[currentFrameIndex] : null;

  SessionDetailsLoaded copyWith({
    ui.Image? Function()? currentImage,
    int? currentFrameIndex,
    int? Function()? selectedLandmarkId,
    bool? isAutoPlaying,
  }) {
    return SessionDetailsLoaded(
      session: session,
      frames: frames,
      currentImage: currentImage != null
          ? currentImage()
          : this.currentImage,
      currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
      selectedLandmarkId: selectedLandmarkId != null
          ? selectedLandmarkId()
          : this.selectedLandmarkId,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
    );
  }

  @override
  List<Object?> get props => [
    session.id,
    currentFrameIndex,
    selectedLandmarkId,
    totalFrames,
    isAutoPlaying,
  ];
}

/// Error loading session or decoding frames.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
