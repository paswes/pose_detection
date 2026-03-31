import 'package:pose_detection/core/domain/models/detected_pose.dart';
import 'package:pose_detection/core/domain/models/person_detection_result.dart';

/// Interface for validating if a detected pose represents a real person
/// ML Kit returns poses even for objects (cables, desks, etc.)
/// This validator checks geometric plausibility, proportions, and face features
abstract class IPersonValidator {
  /// Validate if the detected pose represents a real person
  /// Returns a PersonDetectionResult with all debug metrics
  PersonDetectionResult validate(DetectedPose? pose);
}
