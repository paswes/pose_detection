import 'package:pose_detection/core/domain/models/detected_pose.dart';

/// Interface for validating if a detected pose represents a real person.
/// ML Kit returns poses even for objects (cables, desks, etc.)
/// This validator checks geometric plausibility, proportions, and face features.
abstract class IPersonValidator {
  /// Returns `true` if the detected pose represents a real person.
  bool validate(DetectedPose? pose);
}
