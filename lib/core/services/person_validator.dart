import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';
import 'package:pose_detection/core/domain/models/person_detection_result.dart';

/// Validates if a detected pose represents a real person.
///
/// ML Kit returns poses even for objects (cables, desks, etc.) with high
/// likelihood. This validator applies multiple geometric and proportion
/// checks using landmark IDs from [LandmarkSchema]:
///
/// 1. Core landmark likelihood (nose, shoulders, hips)
/// 2. Geometric plausibility (head > shoulders > hips)
/// 3. Minimum size requirements
/// 4. Shoulder symmetry
/// 5. Hip symmetry
/// 6. Neck proportion
/// 7. Face parts detection (eyes, ears)
class PersonValidator implements IPersonValidator {
  // Validation thresholds
  static const double _minLikelihood = 0.5;
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

    // Core landmarks
    final nose = _getLandmark(pose, LandmarkSchema.nose);
    final leftShoulder = _getLandmark(pose, LandmarkSchema.leftShoulder);
    final rightShoulder = _getLandmark(pose, LandmarkSchema.rightShoulder);
    final leftHip = _getLandmark(pose, LandmarkSchema.leftHip);
    final rightHip = _getLandmark(pose, LandmarkSchema.rightHip);

    // Face landmarks
    final leftEye = _getLandmark(pose, LandmarkSchema.leftEye);
    final rightEye = _getLandmark(pose, LandmarkSchema.rightEye);
    final leftEar = _getLandmark(pose, LandmarkSchema.leftEar);
    final rightEar = _getLandmark(pose, LandmarkSchema.rightEar);

    // Check core landmark likelihood
    final hasAllLikelihood =
        _hasMinLikelihood(nose) &&
        _hasMinLikelihood(leftShoulder) &&
        _hasMinLikelihood(rightShoulder) &&
        _hasMinLikelihood(leftHip) &&
        _hasMinLikelihood(rightHip);

    if (!hasAllLikelihood) {
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
    final proportionsOk =
        ratio >= _minProportionRatio && ratio <= _maxProportionRatio;
    final minSizeOk =
        shoulderWidth >= _minShoulderWidth && torsoLength >= _minTorsoLength;

    // Symmetry checks
    final shoulderSymmetry = (leftShoulder.y - rightShoulder.y).abs();
    final shoulderSymmetryOk =
        shoulderWidth > 0 &&
        shoulderSymmetry < shoulderWidth * _maxSymmetryRatio;

    final hipWidth = (leftHip.x - rightHip.x).abs();
    final hipSymmetry = (leftHip.y - rightHip.y).abs();
    final hipSymmetryOk =
        hipWidth > 0 && hipSymmetry < hipWidth * _maxSymmetryRatio;

    // Neck proportion
    final neckLength = shoulderCenterY - nose.y;
    final neckRatio = shoulderWidth > 0 ? neckLength / shoulderWidth : 0.0;
    final neckOk = neckRatio >= _minNeckRatio && neckRatio <= _maxNeckRatio;

    // Face parts detection
    int facePartsDetected = 0;
    if (_hasMinLikelihood(leftEye)) facePartsDetected++;
    if (_hasMinLikelihood(rightEye)) facePartsDetected++;
    if (_hasMinLikelihood(leftEar)) facePartsDetected++;
    if (_hasMinLikelihood(rightEar)) facePartsDetected++;
    final faceOk = facePartsDetected >= _minFaceParts;

    // Final decision: all checks must pass
    final isPersonDetected =
        headAboveShoulders &&
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

  bool _hasMinLikelihood(Landmark? landmark) {
    return landmark != null && landmark.likelihood >= _minLikelihood;
  }
}
