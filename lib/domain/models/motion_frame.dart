import 'package:equatable/equatable.dart';
import 'package:pose_detection/core/utils/vector3.dart';
import 'package:pose_detection/domain/models/body_segment.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/joint_angle.dart';

/// A single frame of motion data combining raw pose with computed metrics.
/// This is the primary model for motion analysis - exercise-agnostic.
class MotionFrame extends Equatable {
  /// Raw pose data from ML Kit
  final DetectedPose pose;

  /// Computed joint angles for this frame
  final Map<String, JointAngle> angles;

  /// Computed body segment lengths for this frame
  final Map<String, BodySegment> segments;

  /// Landmark velocities (pixels per second) - computed from previous frame
  final Map<int, Vector3> velocities;

  const MotionFrame({
    required this.pose,
    this.angles = const {},
    this.segments = const {},
    this.velocities = const {},
  });

  /// Timestamp from the underlying pose (microseconds)
  int get timestampMicros => pose.timestampMicros;

  /// Get angle by joint ID, returns null if not computed
  JointAngle? getAngle(String jointId) => angles[jointId];

  /// Get segment by ID, returns null if not computed
  BodySegment? getSegment(String segmentId) => segments[segmentId];

  /// Get velocity for a landmark by ID, returns null if not computed
  Vector3? getVelocity(int landmarkId) => velocities[landmarkId];

  /// Get velocity magnitude for a landmark (speed in pixels/second)
  double? getSpeed(int landmarkId) => velocities[landmarkId]?.magnitude;

  /// Whether any velocity data is available
  bool get hasVelocityData => velocities.isNotEmpty;

  /// Create a copy with updated values
  MotionFrame copyWith({
    DetectedPose? pose,
    Map<String, JointAngle>? angles,
    Map<String, BodySegment>? segments,
    Map<int, Vector3>? velocities,
  }) {
    return MotionFrame(
      pose: pose ?? this.pose,
      angles: angles ?? this.angles,
      segments: segments ?? this.segments,
      velocities: velocities ?? this.velocities,
    );
  }

  @override
  List<Object?> get props => [pose, angles, segments, velocities];
}
