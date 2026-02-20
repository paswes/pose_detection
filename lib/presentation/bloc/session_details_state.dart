import 'package:equatable/equatable.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// Playback mode for the session details screen.
enum PlaybackMode {
  /// Video is playing continuously with ticker-driven overlay.
  continuous,

  /// Video is paused; user navigates frame-by-frame.
  frameStepping,
}

/// States for the session details playback screen.
sealed class SessionDetailsState extends Equatable {
  const SessionDetailsState();

  @override
  List<Object?> get props => [];
}

/// Loading session data and initializing video player.
class SessionDetailsLoading extends SessionDetailsState {
  const SessionDetailsLoading();
}

/// Session data loaded and video player ready.
class SessionDetailsLoaded extends SessionDetailsState {
  final Session session;
  final List<TrackedFrame> frames;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final int currentFrameIndex;
  final int totalFrames;
  final PlaybackMode playbackMode;
  final int? selectedLandmarkId;

  const SessionDetailsLoaded({
    required this.session,
    required this.frames,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.currentFrameIndex,
    required this.totalFrames,
    this.playbackMode = PlaybackMode.continuous,
    this.selectedLandmarkId,
  });

  SessionDetailsLoaded copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    int? currentFrameIndex,
    PlaybackMode? playbackMode,
    int? selectedLandmarkId,
    bool clearSelectedLandmark = false,
  }) {
    return SessionDetailsLoaded(
      session: session,
      frames: frames,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
      totalFrames: totalFrames,
      playbackMode: playbackMode ?? this.playbackMode,
      selectedLandmarkId: clearSelectedLandmark
          ? null
          : (selectedLandmarkId ?? this.selectedLandmarkId),
    );
  }

  @override
  List<Object?> get props => [
    session.id,
    isPlaying,
    position,
    duration,
    currentFrameIndex,
    totalFrames,
    playbackMode,
    selectedLandmarkId,
  ];
}

/// Error loading session or video.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
