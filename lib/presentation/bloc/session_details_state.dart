import 'package:equatable/equatable.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

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
  final TrackedFrame? currentFrame;

  const SessionDetailsLoaded({
    required this.session,
    required this.frames,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.currentFrame,
  });

  SessionDetailsLoaded copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    TrackedFrame? currentFrame,
  }) {
    return SessionDetailsLoaded(
      session: session,
      frames: frames,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentFrame: currentFrame ?? this.currentFrame,
    );
  }

  @override
  List<Object?> get props => [
    session.id,
    isPlaying,
    position,
    duration,
    currentFrame?.timestampMicros,
  ];
}

/// Error loading session or video.
class SessionDetailsError extends SessionDetailsState {
  final String message;

  const SessionDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
