import 'package:pose_detection/core/interfaces/position_validator_interface.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/models/position_validation_result.dart';

/// Experimental validator - testing side detection
class PositionValidator implements IPositionValidator {
  // Landmark IDs
  static const int _leftShoulder = 11;
  static const int _rightShoulder = 12;
  static const int _leftHip = 23;
  static const int _rightHip = 24;

  @override
  PositionValidationResult validate(DetectedPose? pose) {
    if (pose == null) {
      return PositionValidationResult.noPose();
    }

    // Get landmarks for both sides
    final leftShoulder = _getLandmark(pose, _leftShoulder);
    final rightShoulder = _getLandmark(pose, _rightShoulder);
    final leftHip = _getLandmark(pose, _leftHip);
    final rightHip = _getLandmark(pose, _rightHip);

    // Calculate average Z depth for each side
    final leftZ = _avgZ([leftShoulder, leftHip]);
    final rightZ = _avgZ([rightShoulder, rightHip]);

    // Calculate Z difference (negative Z = closer to camera)
    final zDiff = (leftZ ?? 0) - (rightZ ?? 0);

    // Show values in UI for debugging
    final messages = <String>[
      'Z L: ${leftZ?.toStringAsFixed(0) ?? "?"} | Z R: ${rightZ?.toStringAsFixed(0) ?? "?"}',
      'Z Diff (L-R): ${zDiff.toStringAsFixed(0)}',
    ];

    // Determine which side is facing camera based on Z depth
    // Note: With selfie camera, the mapping might be inverted
    // Lower Z = closer to camera in ML Kit's coordinate system
    final String detectedSide;
    const threshold = 50.0;

    // INVERTED for selfie camera:
    // Positive diff (leftZ > rightZ) means LEFT side is facing camera
    // Negative diff (leftZ < rightZ) means RIGHT side is facing camera
    if (zDiff > threshold) {
      detectedSide = 'LEFT';
    } else if (zDiff < -threshold) {
      detectedSide = 'RIGHT';
    } else {
      detectedSide = 'FRONT';
    }

    messages.add('→ $detectedSide');

    return PositionValidationResult(
      isProperlyPositioned: detectedSide == 'LEFT',
      leftHipStatus: LandmarkStatus.detected,
      leftKneeStatus: LandmarkStatus.detected,
      leftAnkleStatus: LandmarkStatus.detected,
      isSideProfile: detectedSide != 'FRONT',
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
}
