import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/session_metrics.dart';

/// Represents a pose detection session with captured motion data
class PoseSession {
  final DateTime startTime;
  final DateTime? endTime;
  final List<TimestampedPose> capturedPoses;
  final SessionMetrics metrics;

  PoseSession({
    required this.startTime,
    this.endTime,
    required this.capturedPoses,
    SessionMetrics? metrics,
  }) : metrics = metrics ?? const SessionMetrics();

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  bool get isActive => endTime == null;

  /// Effective FPS based on processed frames
  double get effectiveFps => metrics.effectiveFps(duration);

  PoseSession copyWith({
    DateTime? startTime,
    DateTime? endTime,
    List<TimestampedPose>? capturedPoses,
    SessionMetrics? metrics,
  }) {
    return PoseSession(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capturedPoses: capturedPoses ?? this.capturedPoses,
      metrics: metrics ?? this.metrics,
    );
  }
}
