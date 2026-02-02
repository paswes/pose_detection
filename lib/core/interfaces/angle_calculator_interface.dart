import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/joint_angle.dart';

/// Abstract interface for joint angle calculations
/// Enables testability through dependency injection
abstract class IAngleCalculator {
  /// Calculate angle for a specific joint from a pose
  /// Returns null if landmarks have insufficient confidence
  JointAngle? calculateAngle(AnatomicalJoint joint, TimestampedPose pose);

  /// Calculate all available joint angles from a pose
  /// Only returns angles where all three landmarks meet confidence threshold
  List<JointAngle> calculateAllAngles(TimestampedPose pose);

  /// Get the three landmark IDs that form a specific joint angle
  /// Returns (proximal, vertex, distal) landmark indices
  /// The angle is measured at the vertex
  (int, int, int) getLandmarkTriplet(AnatomicalJoint joint);
}
