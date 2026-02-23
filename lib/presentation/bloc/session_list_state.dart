import 'package:pose_detection/data/models/session.dart';

/// States for the session list on the home page.
sealed class SessionListState {
  const SessionListState();
}

/// Demo video is being processed on first launch.
class SessionListInitializing extends SessionListState {
  final int completedFrames;
  final int totalFrames;

  const SessionListInitializing({
    this.completedFrames = 0,
    this.totalFrames = 0,
  });

  double get progress =>
      totalFrames > 0 ? completedFrames / totalFrames : 0.0;
}

/// Sessions loaded successfully.
class SessionListLoaded extends SessionListState {
  final List<Session> sessions;
  final bool processingVideo;
  final int processingCompleted;
  final int processingTotal;

  const SessionListLoaded({
    required this.sessions,
    this.processingVideo = false,
    this.processingCompleted = 0,
    this.processingTotal = 0,
  });

  double get processingProgress =>
      processingTotal > 0 ? processingCompleted / processingTotal : 0.0;

  SessionListLoaded copyWith({
    List<Session>? sessions,
    bool? processingVideo,
    int? processingCompleted,
    int? processingTotal,
  }) {
    return SessionListLoaded(
      sessions: sessions ?? this.sessions,
      processingVideo: processingVideo ?? this.processingVideo,
      processingCompleted: processingCompleted ?? this.processingCompleted,
      processingTotal: processingTotal ?? this.processingTotal,
    );
  }
}
