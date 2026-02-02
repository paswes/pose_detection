import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/landmark_velocity.dart';

/// Abstract interface for velocity tracking
/// Enables testability through dependency injection
abstract class IVelocityTracker {
  /// Calculate velocities for all landmarks between two poses
  /// Returns empty list if poses are too close in time
  List<LandmarkVelocity> calculateVelocities(
    TimestampedPose previousPose,
    TimestampedPose currentPose,
  );

  /// Get velocity for a specific landmark between two poses
  LandmarkVelocity? getVelocityForLandmark(
    int landmarkId,
    TimestampedPose previousPose,
    TimestampedPose currentPose,
  );

  /// Get smoothed velocities using recent pose history
  /// Averages velocities over the smoothing window for noise reduction
  List<LandmarkVelocity> getSmoothedVelocities(
    List<TimestampedPose> recentPoses,
    int smoothingWindow,
  );
}
