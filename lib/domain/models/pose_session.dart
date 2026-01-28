import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Represents a pose detection session with captured data
class PoseSession {
  final DateTime startTime;
  final DateTime? endTime;
  final List<Pose> capturedPoses;
  final int totalFramesProcessed;

  PoseSession({
    required this.startTime,
    this.endTime,
    required this.capturedPoses,
    required this.totalFramesProcessed,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  bool get isActive => endTime == null;

  PoseSession copyWith({
    DateTime? startTime,
    DateTime? endTime,
    List<Pose>? capturedPoses,
    int? totalFramesProcessed,
  }) {
    return PoseSession(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capturedPoses: capturedPoses ?? this.capturedPoses,
      totalFramesProcessed: totalFramesProcessed ?? this.totalFramesProcessed,
    );
  }
}
