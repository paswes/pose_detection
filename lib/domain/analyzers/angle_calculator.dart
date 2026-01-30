import 'dart:math' as math;

import 'package:pose_detection/domain/models/motion_data.dart';

/// ML Kit Pose Landmark IDs
/// Reference: https://developers.google.com/ml-kit/vision/pose-detection
class LandmarkId {
  LandmarkId._();

  // Face
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int leftMouth = 9;
  static const int rightMouth = 10;

  // Upper body
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;

  // Lower body
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;
}

/// Utility class for calculating joint angles from pose landmarks.
/// All angle calculations use normalized landmarks (0-1 range) for
/// resolution-independent analysis.
class AngleCalculator {
  AngleCalculator._();

  /// Minimum confidence threshold for landmark to be considered valid
  static const double minConfidence = 0.5;

  /// Calculate angle at point B formed by points A -> B -> C (in degrees)
  ///
  /// Returns the angle at the middle point (B) in the range 0-180 degrees.
  /// Uses 2D coordinates (x, y) for calculation.
  static double calculateAngle(
    NormalizedLandmark a,
    NormalizedLandmark b,
    NormalizedLandmark c,
  ) {
    // Vector BA (from B to A)
    final baX = a.x - b.x;
    final baY = a.y - b.y;

    // Vector BC (from B to C)
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    // Dot product of BA and BC
    final dotProduct = baX * bcX + baY * bcY;

    // Magnitudes of BA and BC
    final magnitudeBA = math.sqrt(baX * baX + baY * baY);
    final magnitudeBC = math.sqrt(bcX * bcX + bcY * bcY);

    // Avoid division by zero
    if (magnitudeBA == 0 || magnitudeBC == 0) {
      return 180.0; // Straight line
    }

    // Calculate cosine of angle
    final cosAngle = dotProduct / (magnitudeBA * magnitudeBC);

    // Clamp to valid range to handle floating point errors
    final clampedCos = cosAngle.clamp(-1.0, 1.0);

    // Convert to degrees
    return math.acos(clampedCos) * 180.0 / math.pi;
  }

  /// Get a landmark by ID from the pose, returns null if not found or low confidence
  static NormalizedLandmark? _getLandmark(
    TimestampedPose pose,
    int id, {
    double minConfidence = minConfidence,
  }) {
    try {
      final landmark = pose.normalizedLandmarks.firstWhere((l) => l.id == id);
      if (landmark.likelihood < minConfidence) return null;
      return landmark;
    } catch (_) {
      return null;
    }
  }

  /// Calculate knee angle: Hip -> Knee -> Ankle
  ///
  /// Standing position is ~170-180 degrees
  /// Parallel squat is ~90 degrees
  /// Deep squat is <90 degrees
  static double? calculateKneeAngle(TimestampedPose pose, {required bool isLeft}) {
    final hipId = isLeft ? LandmarkId.leftHip : LandmarkId.rightHip;
    final kneeId = isLeft ? LandmarkId.leftKnee : LandmarkId.rightKnee;
    final ankleId = isLeft ? LandmarkId.leftAnkle : LandmarkId.rightAnkle;

    final hip = _getLandmark(pose, hipId);
    final knee = _getLandmark(pose, kneeId);
    final ankle = _getLandmark(pose, ankleId);

    if (hip == null || knee == null || ankle == null) return null;

    return calculateAngle(hip, knee, ankle);
  }

  /// Calculate average knee angle (left and right)
  static double? calculateAverageKneeAngle(TimestampedPose pose) {
    final leftAngle = calculateKneeAngle(pose, isLeft: true);
    final rightAngle = calculateKneeAngle(pose, isLeft: false);

    if (leftAngle == null && rightAngle == null) return null;
    if (leftAngle == null) return rightAngle;
    if (rightAngle == null) return leftAngle;

    return (leftAngle + rightAngle) / 2;
  }

  /// Calculate hip angle: Shoulder -> Hip -> Knee
  ///
  /// Standing position is ~170-180 degrees
  /// Lower values indicate more hip flexion
  static double? calculateHipAngle(TimestampedPose pose, {required bool isLeft}) {
    final shoulderId = isLeft ? LandmarkId.leftShoulder : LandmarkId.rightShoulder;
    final hipId = isLeft ? LandmarkId.leftHip : LandmarkId.rightHip;
    final kneeId = isLeft ? LandmarkId.leftKnee : LandmarkId.rightKnee;

    final shoulder = _getLandmark(pose, shoulderId);
    final hip = _getLandmark(pose, hipId);
    final knee = _getLandmark(pose, kneeId);

    if (shoulder == null || hip == null || knee == null) return null;

    return calculateAngle(shoulder, hip, knee);
  }

  /// Calculate average hip angle (left and right)
  static double? calculateAverageHipAngle(TimestampedPose pose) {
    final leftAngle = calculateHipAngle(pose, isLeft: true);
    final rightAngle = calculateHipAngle(pose, isLeft: false);

    if (leftAngle == null && rightAngle == null) return null;
    if (leftAngle == null) return rightAngle;
    if (rightAngle == null) return leftAngle;

    return (leftAngle + rightAngle) / 2;
  }

  /// Calculate trunk angle relative to vertical axis (in degrees)
  ///
  /// Uses the midpoint of shoulders and midpoint of hips to form the trunk line.
  /// 0 degrees = perfectly upright
  /// Positive values = forward lean
  static double? calculateTrunkAngle(TimestampedPose pose) {
    final leftShoulder = _getLandmark(pose, LandmarkId.leftShoulder);
    final rightShoulder = _getLandmark(pose, LandmarkId.rightShoulder);
    final leftHip = _getLandmark(pose, LandmarkId.leftHip);
    final rightHip = _getLandmark(pose, LandmarkId.rightHip);

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    // Calculate midpoints
    final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipMidX = (leftHip.x + rightHip.x) / 2;
    final hipMidY = (leftHip.y + rightHip.y) / 2;

    // Vector from hip to shoulder (trunk direction)
    final trunkX = shoulderMidX - hipMidX;
    final trunkY = shoulderMidY - hipMidY;

    // Vertical axis (pointing up in screen coordinates where Y increases downward)
    // In normalized coordinates, "up" is negative Y direction
    const verticalX = 0.0;
    const verticalY = -1.0;

    // Calculate angle between trunk and vertical
    final dotProduct = trunkX * verticalX + trunkY * verticalY;
    final magnitudeTrunk = math.sqrt(trunkX * trunkX + trunkY * trunkY);
    const magnitudeVertical = 1.0;

    if (magnitudeTrunk == 0) return 0.0;

    final cosAngle = dotProduct / (magnitudeTrunk * magnitudeVertical);
    final clampedCos = cosAngle.clamp(-1.0, 1.0);

    return math.acos(clampedCos) * 180.0 / math.pi;
  }

  /// Calculate knee valgus/varus (frontal plane deviation)
  ///
  /// Compares knee X position to the line between hip and ankle.
  /// Returns degrees of deviation:
  /// - Positive: Knee is medial (valgus / "knee cave")
  /// - Negative: Knee is lateral (varus / "bow-legged")
  /// - Zero: Knee tracks directly over ankle
  static double? calculateKneeValgus(TimestampedPose pose, {required bool isLeft}) {
    final hipId = isLeft ? LandmarkId.leftHip : LandmarkId.rightHip;
    final kneeId = isLeft ? LandmarkId.leftKnee : LandmarkId.rightKnee;
    final ankleId = isLeft ? LandmarkId.leftAnkle : LandmarkId.rightAnkle;

    final hip = _getLandmark(pose, hipId);
    final knee = _getLandmark(pose, kneeId);
    final ankle = _getLandmark(pose, ankleId);

    if (hip == null || knee == null || ankle == null) return null;

    // Calculate expected knee X position (linear interpolation between hip and ankle)
    // based on knee Y position
    final hipToAnkleY = ankle.y - hip.y;
    if (hipToAnkleY.abs() < 0.001) return 0.0; // Nearly horizontal, can't calculate

    final t = (knee.y - hip.y) / hipToAnkleY;
    final expectedKneeX = hip.x + t * (ankle.x - hip.x);

    // Calculate deviation
    final deviationX = knee.x - expectedKneeX;

    // Convert to approximate degrees
    // Using hip-ankle distance as reference for scaling
    final hipAnkleDistance =
        math.sqrt(math.pow(ankle.x - hip.x, 2) + math.pow(ankle.y - hip.y, 2));

    if (hipAnkleDistance < 0.001) return 0.0;

    // Approximate angle using small angle approximation
    // atan(deviation / distance) converted to degrees
    final angleRadians = math.atan(deviationX / hipAnkleDistance);
    final angleDegrees = angleRadians * 180.0 / math.pi;

    // For left leg, medial is positive X (toward center)
    // For right leg, medial is negative X (toward center)
    // We return positive for valgus (knee caving inward)
    return isLeft ? angleDegrees : -angleDegrees;
  }

  /// Calculate average knee valgus (left and right)
  static double? calculateAverageKneeValgus(TimestampedPose pose) {
    final leftValgus = calculateKneeValgus(pose, isLeft: true);
    final rightValgus = calculateKneeValgus(pose, isLeft: false);

    if (leftValgus == null && rightValgus == null) return null;
    if (leftValgus == null) return rightValgus;
    if (rightValgus == null) return leftValgus;

    return (leftValgus + rightValgus) / 2;
  }

  /// Calculate minimum confidence among key squat landmarks
  static double? getSquatLandmarkConfidence(TimestampedPose pose) {
    final keyLandmarkIds = [
      LandmarkId.leftShoulder,
      LandmarkId.rightShoulder,
      LandmarkId.leftHip,
      LandmarkId.rightHip,
      LandmarkId.leftKnee,
      LandmarkId.rightKnee,
      LandmarkId.leftAnkle,
      LandmarkId.rightAnkle,
    ];

    double? minConfidence;

    for (final id in keyLandmarkIds) {
      try {
        final landmark = pose.normalizedLandmarks.firstWhere((l) => l.id == id);
        if (minConfidence == null || landmark.likelihood < minConfidence) {
          minConfidence = landmark.likelihood;
        }
      } catch (_) {
        return null; // Missing landmark
      }
    }

    return minConfidence;
  }
}
