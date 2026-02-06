import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/models/person_detection_result.dart';

/// Validates if a detected pose represents a real person
///
/// ML Kit returns poses even for objects (cables, desks, etc.) with high confidence.
/// This validator applies multiple geometric and proportion checks:
///
/// 1. Core landmark confidence (nose, shoulders, hips)
/// 2. Geometric plausibility (head > shoulders > hips)
/// 3. Minimum size requirements
/// 4. Shoulder symmetry
/// 5. Hip symmetry
/// 6. Neck proportion
/// 7. Face parts detection (eyes, ears)
class PersonValidator implements IPersonValidator {
  static const double _minConfidence = 0.5;
  static const double _minShoulderWidth = 40.0;
  static const double _minTorsoLength = 60.0;
  static const double _maxSymmetryRatio = 0.3;
  static const double _minNeckRatio = 0.2;
  static const double _maxNeckRatio = 1.5;
  static const double _minProportionRatio = 0.5;
  static const double _maxProportionRatio = 3.0;
  static const int _minFaceParts = 2;

  @override
  PersonDetectionResult validate(DetectedPose? pose) {
    if (pose == null) {
      return PersonDetectionResult.noPose();
    }

    // Get core landmarks
    final nose = _getLandmark(pose, 0);
    final leftShoulder = _getLandmark(pose, 11);
    final rightShoulder = _getLandmark(pose, 12);
    final leftHip = _getLandmark(pose, 23);
    final rightHip = _getLandmark(pose, 24);

    // Get face landmarks
    final leftEye = _getLandmark(pose, 2);
    final rightEye = _getLandmark(pose, 5);
    final leftEar = _getLandmark(pose, 7);
    final rightEar = _getLandmark(pose, 8);

    // Check core landmark confidence
    final hasAllConfidence = _hasMinConfidence(nose) &&
        _hasMinConfidence(leftShoulder) &&
        _hasMinConfidence(rightShoulder) &&
        _hasMinConfidence(leftHip) &&
        _hasMinConfidence(rightHip);

    if (!hasAllConfidence) {
      return PersonDetectionResult.noPose();
    }

    // Calculate metrics
    final shoulderCenterY = (leftShoulder!.y + rightShoulder!.y) / 2;
    final hipCenterY = (leftHip!.y + rightHip!.y) / 2;

    // Geometry checks
    final headAboveShoulders = nose!.y < shoulderCenterY;
    final shouldersAboveHips = shoulderCenterY < hipCenterY;

    // Size metrics
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = hipCenterY - shoulderCenterY;
    final ratio = shoulderWidth > 0 && torsoLength > 0
        ? torsoLength / shoulderWidth
        : 0.0;
    final proportionsOk = ratio >= _minProportionRatio && ratio <= _maxProportionRatio;
    final minSizeOk = shoulderWidth >= _minShoulderWidth && torsoLength >= _minTorsoLength;

    // Symmetry checks
    final shoulderSymmetry = (leftShoulder.y - rightShoulder.y).abs();
    final shoulderSymmetryOk = shoulderWidth > 0 && shoulderSymmetry < shoulderWidth * _maxSymmetryRatio;

    final hipWidth = (leftHip.x - rightHip.x).abs();
    final hipSymmetry = (leftHip.y - rightHip.y).abs();
    final hipSymmetryOk = hipWidth > 0 && hipSymmetry < hipWidth * _maxSymmetryRatio;

    // Neck proportion
    final neckLength = shoulderCenterY - nose.y;
    final neckRatio = shoulderWidth > 0 ? neckLength / shoulderWidth : 0.0;
    final neckOk = neckRatio >= _minNeckRatio && neckRatio <= _maxNeckRatio;

    // Face parts detection
    int facePartsDetected = 0;
    if (_hasMinConfidence(leftEye)) facePartsDetected++;
    if (_hasMinConfidence(rightEye)) facePartsDetected++;
    if (_hasMinConfidence(leftEar)) facePartsDetected++;
    if (_hasMinConfidence(rightEar)) facePartsDetected++;
    final faceOk = facePartsDetected >= _minFaceParts;

    // Final decision: all checks must pass
    final isPersonDetected = headAboveShoulders &&
        shouldersAboveHips &&
        proportionsOk &&
        minSizeOk &&
        shoulderSymmetryOk &&
        hipSymmetryOk &&
        neckOk &&
        faceOk;

    return PersonDetectionResult(
      isPersonDetected: isPersonDetected,
      shoulderWidth: shoulderWidth,
      torsoLength: torsoLength,
      ratio: ratio,
      minSizeOk: minSizeOk,
      proportionsOk: proportionsOk,
      headAboveShoulders: headAboveShoulders,
      shouldersAboveHips: shouldersAboveHips,
      shoulderSymmetry: shoulderSymmetry,
      shoulderSymmetryOk: shoulderSymmetryOk,
      hipSymmetry: hipSymmetry,
      hipSymmetryOk: hipSymmetryOk,
      neckLength: neckLength,
      neckRatio: neckRatio,
      neckOk: neckOk,
      facePartsDetected: facePartsDetected,
      faceOk: faceOk,
    );
  }

  Landmark? _getLandmark(DetectedPose pose, int id) {
    return pose.landmarks.where((l) => l.id == id).firstOrNull;
  }

  bool _hasMinConfidence(Landmark? landmark) {
    return landmark != null && landmark.confidence >= _minConfidence;
  }
}
