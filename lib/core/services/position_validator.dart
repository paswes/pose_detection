import 'package:pose_detection/core/interfaces/position_validator_interface.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/models/position_validation_result.dart';

/// Validates if user is properly positioned for seated leg extension:
/// 1. Left side facing camera (Z-depth check using hip + knee)
/// 2. Lower body landmarks (hip, knee) within target box
class PositionValidator implements IPositionValidator {
  // Landmark IDs (lower body for seated leg extension)
  static const int _leftHip = 23;
  static const int _rightHip = 24;
  static const int _leftKnee = 25;
  static const int _rightKnee = 26;

  // Target box boundaries (normalized 0-1, same as SilhouettePainter)
  // Box is centered, 60% width, 70% height
  static const double _boxLeft = 0.20;   // (1 - 0.6) / 2
  static const double _boxRight = 0.80;  // 1 - 0.20
  static const double _boxTop = 0.15;    // (1 - 0.7) / 2
  static const double _boxBottom = 0.85; // 1 - 0.15

  @override
  PositionValidationResult validate(DetectedPose? pose) {
    if (pose == null) {
      return PositionValidationResult.noPose();
    }

    final imageWidth = pose.imageSize.width;
    final imageHeight = pose.imageSize.height;

    // Get lower body landmarks
    final leftHip = _getLandmark(pose, _leftHip);
    final rightHip = _getLandmark(pose, _rightHip);
    final leftKnee = _getLandmark(pose, _leftKnee);
    final rightKnee = _getLandmark(pose, _rightKnee);

    // Calculate Z depths for side detection (using lower body)
    final leftZ = _avgZ([leftHip, leftKnee]);
    final rightZ = _avgZ([rightHip, rightKnee]);
    final zDiff = (leftZ ?? 0) - (rightZ ?? 0);

    // Check if left side is facing camera
    const zThreshold = 50.0;
    final bool isLeftSide = zDiff > zThreshold;
    final bool isRightSide = zDiff < -zThreshold;

    // Check if lower body landmarks are within the target box
    final hipInBox = _isInBox(leftHip, imageWidth, imageHeight);
    final kneeInBox = _isInBox(leftKnee, imageWidth, imageHeight);
    final isInBox = hipInBox && kneeInBox;

    // Build debug messages
    final messages = <String>[];

    // Side detection
    final String sideStatus;
    if (isLeftSide) {
      sideStatus = 'Seite: ✓ LINKS';
    } else if (isRightSide) {
      sideStatus = 'Seite: ✗ RECHTS';
    } else {
      sideStatus = 'Seite: ✗ FRONTAL';
    }
    messages.add(sideStatus);

    // Box position
    final String boxStatus;
    if (isInBox) {
      boxStatus = 'Position: ✓ IN BOX';
    } else {
      final parts = <String>[];
      if (!hipInBox) parts.add('Hüfte');
      if (!kneeInBox) parts.add('Knie');
      boxStatus = 'Position: ✗ ${parts.join(", ")} außerhalb';
    }
    messages.add(boxStatus);

    // Overall result: left side AND in box
    final isProperlyPositioned = isLeftSide && isInBox;

    return PositionValidationResult(
      isProperlyPositioned: isProperlyPositioned,
      leftHipStatus: hipInBox ? LandmarkStatus.detected : LandmarkStatus.missing,
      leftKneeStatus: kneeInBox ? LandmarkStatus.detected : LandmarkStatus.missing,
      leftAnkleStatus: LandmarkStatus.detected,
      isSideProfile: isLeftSide,
      avgLegConfidence: 0,
      guidanceMessages: messages,
    );
  }

  Landmark? _getLandmark(DetectedPose pose, int id) {
    return pose.landmarks.where((l) => l.id == id).firstOrNull;
  }

  double? _avgZ(List<Landmark?> landmarks) {
    final valid = landmarks.whereType<Landmark>().toList();
    if (valid.isEmpty) return null;
    return valid.map((l) => l.z).reduce((a, b) => a + b) / valid.length;
  }

  /// Check if landmark is within the target box (normalized coordinates)
  bool _isInBox(Landmark? landmark, double imageWidth, double imageHeight) {
    if (landmark == null) return false;

    // Normalize landmark position to 0-1
    final normalizedX = landmark.x / imageWidth;
    final normalizedY = landmark.y / imageHeight;

    return normalizedX >= _boxLeft &&
        normalizedX <= _boxRight &&
        normalizedY >= _boxTop &&
        normalizedY <= _boxBottom;
  }
}
