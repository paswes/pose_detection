import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/position_validation_result.dart';

/// Interface for validating if a user is properly positioned for an exercise
/// Checks if required landmarks are visible and user is in correct orientation
abstract class IPositionValidator {
  /// Validate if the detected pose is in the correct position for the exercise
  /// Returns a PositionValidationResult with landmark statuses and guidance
  PositionValidationResult validate(DetectedPose? pose);
}
