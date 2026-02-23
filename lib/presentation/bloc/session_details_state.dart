import 'package:equatable/equatable.dart';

import 'package:pose_detection/core/utils/rdl_rep_counter.dart';
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
  final int repCount;
  final double? hipAngle;
  final List<RdlRepData> reps;

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
    this.repCount = 0,
    this.hipAngle,
    this.reps = const [],
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
    int? repCount,
    double? Function()? hipAngle,
    List<RdlRepData>? reps,
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
      repCount: repCount ?? this.repCount,
      hipAngle: hipAngle != null ? hipAngle() : this.hipAngle,
      reps: reps ?? this.reps,
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
    repCount,
    hipAngle,
    reps,
  ];
}

/// Error loading session or initializing video player.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
