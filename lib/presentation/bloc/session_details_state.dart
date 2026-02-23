import 'package:equatable/equatable.dart';

import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// States for the session details playback screen.
sealed class SessionDetailsState extends Equatable {
  const SessionDetailsState();

  @override
  List<Object?> get props => [];
}

/// Loading session data and preparing video player.
class SessionDetailsLoading extends SessionDetailsState {
  const SessionDetailsLoading();
}

/// Video player ready and frames loaded for playback.
class SessionDetailsLoaded extends SessionDetailsState {
  final Session session;
  final List<TrackedFrame> frames;
  final int currentFrameIndex;
  final int? selectedLandmarkId;
  final bool isPlaying;
  final bool isVideoReady;
  final Duration videoPosition;
  final Duration videoDuration;
  final double playbackSpeed;

  const SessionDetailsLoaded({
    required this.session,
    required this.frames,
    this.currentFrameIndex = 0,
    this.selectedLandmarkId,
    this.isPlaying = false,
    this.isVideoReady = false,
    this.videoPosition = Duration.zero,
    this.videoDuration = Duration.zero,
    this.playbackSpeed = 1.0,
  });

  int get totalFrames => frames.length;

  TrackedFrame? get currentFrame =>
      currentFrameIndex < frames.length ? frames[currentFrameIndex] : null;

  SessionDetailsLoaded copyWith({
    int? currentFrameIndex,
    int? Function()? selectedLandmarkId,
    bool? isPlaying,
    bool? isVideoReady,
    Duration? videoPosition,
    Duration? videoDuration,
    double? playbackSpeed,
  }) {
    return SessionDetailsLoaded(
      session: session,
      frames: frames,
      currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
      selectedLandmarkId: selectedLandmarkId != null
          ? selectedLandmarkId()
          : this.selectedLandmarkId,
      isPlaying: isPlaying ?? this.isPlaying,
      isVideoReady: isVideoReady ?? this.isVideoReady,
      videoPosition: videoPosition ?? this.videoPosition,
      videoDuration: videoDuration ?? this.videoDuration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  @override
  List<Object?> get props => [
    session.id,
    currentFrameIndex,
    selectedLandmarkId,
    totalFrames,
    isPlaying,
    isVideoReady,
    videoPosition,
    videoDuration,
    playbackSpeed,
  ];
}

/// Error loading session or initializing video player.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
