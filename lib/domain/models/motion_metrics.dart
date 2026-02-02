import 'joint_angle.dart';
import 'landmark_velocity.dart';
import 'body_region.dart';

/// Aggregated motion metrics snapshot
/// Combines all motion analysis results for a single pose
class MotionMetrics {
  /// All calculated joint angles
  final List<JointAngle> jointAngles;

  /// Velocities per landmark (may be empty if no history)
  final List<LandmarkVelocity> velocities;

  /// Body region confidence breakdown
  final BodyRegionBreakdown bodyRegions;

  /// Overall pose confidence (average of all landmarks)
  final double overallConfidence;

  /// Timestamp of this analysis (microseconds)
  final int timestampMicros;

  const MotionMetrics({
    required this.jointAngles,
    required this.velocities,
    required this.bodyRegions,
    required this.overallConfidence,
    required this.timestampMicros,
  });

  /// Get angle for a specific joint
  JointAngle? getAngle(AnatomicalJoint joint) {
    for (final angle in jointAngles) {
      if (angle.joint == joint) return angle;
    }
    return null;
  }

  /// Get velocity for a specific landmark
  LandmarkVelocity? getVelocity(int landmarkId) {
    for (final v in velocities) {
      if (v.landmarkId == landmarkId) return v;
    }
    return null;
  }

  /// Average speed across all landmarks
  double get averageSpeed {
    if (velocities.isEmpty) return 0;
    return velocities.fold(0.0, (sum, v) => sum + v.speed) / velocities.length;
  }

  /// Landmark with highest speed
  LandmarkVelocity? get fastestLandmark {
    if (velocities.isEmpty) return null;
    return velocities.reduce((a, b) => a.speed > b.speed ? a : b);
  }

  /// Number of valid angles calculated
  int get validAngleCount => jointAngles.length;

  /// Number of velocity measurements
  int get velocityCount => velocities.length;

  /// Overall movement category based on average speed
  SpeedCategory get movementCategory {
    final avg = averageSpeed;
    if (avg < 0.1) return SpeedCategory.stationary;
    if (avg < 0.3) return SpeedCategory.slow;
    if (avg < 0.7) return SpeedCategory.moderate;
    return SpeedCategory.fast;
  }

  /// Empty metrics for initial state
  static const empty = MotionMetrics(
    jointAngles: [],
    velocities: [],
    bodyRegions: BodyRegionBreakdown.empty,
    overallConfidence: 0,
    timestampMicros: 0,
  );
}
