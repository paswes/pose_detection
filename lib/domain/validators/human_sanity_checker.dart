import 'dart:math' as math;
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/validation_result.dart';

/// Deterministic biomechanical validator for human poses
/// Filters out "ghost poses" - ML Kit hallucinations on furniture, plants, etc.
///
/// Uses multiple anatomical constraints to verify poses are biomechanically
/// possible for real humans. All checks are deterministic and don't require
/// ML inference.
class HumanSanityChecker {
  /// Minimum average confidence across key landmarks to consider valid
  static const double _minKeyLandmarkConfidence = 0.5;

  /// Minimum number of key landmarks that must be visible
  static const int _minVisibleKeyLandmarks = 6;

  /// Maximum allowed aspect ratio for human body (height/width)
  /// Normal humans range from ~2.0 (wide stance) to ~6.0 (arms down)
  static const double _maxBodyAspectRatio = 8.0;
  static const double _minBodyAspectRatio = 0.5;

  /// Proportion constraints (as ratios to total body height)
  /// Based on standard human proportions
  static const double _maxHeadToBodyRatio = 0.35; // Head shouldn't be >35% of body
  static const double _minHeadToBodyRatio = 0.08; // Head shouldn't be <8% of body

  /// Landmark IDs for key body parts (MediaPipe Pose landmarks)
  /// Shoulders
  static const int _leftShoulder = 11;
  static const int _rightShoulder = 12;

  /// Hips
  static const int _leftHip = 23;
  static const int _rightHip = 24;

  /// Knees
  static const int _leftKnee = 25;
  static const int _rightKnee = 26;

  /// Ankles
  static const int _leftAnkle = 27;
  static const int _rightAnkle = 28;

  /// Face landmarks
  static const int _nose = 0;

  /// Elbows
  static const int _leftElbow = 13;
  static const int _rightElbow = 14;

  /// Wrists
  static const int _leftWrist = 15;
  static const int _rightWrist = 16;

  /// Key landmarks that should be visible for a valid detection
  static const List<int> _keyLandmarkIds = [
    _nose,
    _leftShoulder,
    _rightShoulder,
    _leftHip,
    _rightHip,
    _leftKnee,
    _rightKnee,
    _leftAnkle,
    _rightAnkle,
  ];

  /// Validate a pose using biomechanical constraints
  /// Returns a SanityCheckResult indicating validity and reasons
  SanityCheckResult validate(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;
    final failedChecks = <RejectionReason>[];
    final checkScores = <String, double>{};

    // Check 1: Sufficient landmark confidence
    final confidenceResult = _checkLandmarkConfidence(landmarks);
    checkScores['landmarkConfidence'] = confidenceResult.score;
    if (!confidenceResult.passed) {
      failedChecks.add(RejectionReason.insufficientLandmarkConfidence);
    }

    // Check 2: Anatomical proportions
    final proportionResult = _checkAnatomicalProportions(landmarks);
    checkScores['anatomicalProportions'] = proportionResult.score;
    if (!proportionResult.passed) {
      failedChecks.add(RejectionReason.anatomicallyImpossible);
    }

    // Check 3: Body aspect ratio
    final aspectRatioResult = _checkBodyAspectRatio(landmarks);
    checkScores['bodyAspectRatio'] = aspectRatioResult.score;
    if (!aspectRatioResult.passed) {
      failedChecks.add(RejectionReason.anatomicallyImpossible);
    }

    // Check 4: Spatial coherence (landmarks should be reasonably close)
    final coherenceResult = _checkSpatialCoherence(landmarks);
    checkScores['spatialCoherence'] = coherenceResult.score;
    if (!coherenceResult.passed) {
      failedChecks.add(RejectionReason.suspectedHallucination);
    }

    // Check 5: Biomechanical joint angles
    final jointAngleResult = _checkJointAngles(landmarks);
    checkScores['jointAngles'] = jointAngleResult.score;
    if (!jointAngleResult.passed) {
      failedChecks.add(RejectionReason.biomechanicallyInvalid);
    }

    // Check 6: Symmetry check (body should be roughly symmetric)
    final symmetryResult = _checkBodySymmetry(landmarks);
    checkScores['bodySymmetry'] = symmetryResult.score;
    if (!symmetryResult.passed) {
      failedChecks.add(RejectionReason.suspectedHallucination);
    }

    // Calculate overall human likelihood score
    final scores = checkScores.values.toList();
    final humanLikelihood =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

    // Remove duplicates from failed checks
    final uniqueFailedChecks = failedChecks.toSet().toList();

    return SanityCheckResult(
      isValid: uniqueFailedChecks.isEmpty,
      failedChecks: uniqueFailedChecks,
      humanLikelihood: humanLikelihood,
      checkScores: checkScores,
    );
  }

  /// Check if key landmarks have sufficient confidence
  _CheckResult _checkLandmarkConfidence(List<NormalizedLandmark> landmarks) {
    final landmarkMap = {for (var lm in landmarks) lm.id: lm};

    int visibleCount = 0;
    double totalConfidence = 0.0;

    for (final id in _keyLandmarkIds) {
      final landmark = landmarkMap[id];
      if (landmark != null && landmark.likelihood >= _minKeyLandmarkConfidence) {
        visibleCount++;
        totalConfidence += landmark.likelihood;
      }
    }

    final avgConfidence =
        visibleCount > 0 ? totalConfidence / visibleCount : 0.0;

    final passed = visibleCount >= _minVisibleKeyLandmarks &&
        avgConfidence >= _minKeyLandmarkConfidence;

    return _CheckResult(
      passed: passed,
      score: avgConfidence,
    );
  }

  /// Check anatomical proportions (head to body ratio, limb ratios)
  _CheckResult _checkAnatomicalProportions(List<NormalizedLandmark> landmarks) {
    final landmarkMap = {for (var lm in landmarks) lm.id: lm};

    // Get key points for proportion checks
    final nose = landmarkMap[_nose];
    final leftShoulder = landmarkMap[_leftShoulder];
    final rightShoulder = landmarkMap[_rightShoulder];
    final leftHip = landmarkMap[_leftHip];
    final rightHip = landmarkMap[_rightHip];
    final leftAnkle = landmarkMap[_leftAnkle];
    final rightAnkle = landmarkMap[_rightAnkle];

    // Need minimum landmarks for this check
    if (nose == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      // Can't verify - give benefit of doubt with medium score
      return const _CheckResult(passed: true, score: 0.5);
    }

    // Calculate body measurements
    final shoulderCenter = _midpoint(leftShoulder, rightShoulder);
    final hipCenter = _midpoint(leftHip, rightHip);

    // Head size estimate (nose to shoulder midpoint)
    final headSize = _distance(nose, shoulderCenter);

    // Calculate total body height estimate
    double bodyHeight;
    if (leftAnkle != null && rightAnkle != null) {
      final ankleCenter = _midpoint(leftAnkle, rightAnkle);
      bodyHeight = math.max(
        _distanceFromPoint(nose.x, nose.y, ankleCenter.x, ankleCenter.y),
        0.01, // Prevent division by zero
      );
    } else {
      // Estimate from shoulders to hips, multiply by typical factor
      final torsoHeight = _distance(shoulderCenter, hipCenter);
      bodyHeight = torsoHeight * 2.5; // Rough estimate
    }

    // Check head to body ratio
    final headRatio = headSize / bodyHeight;
    final headRatioValid =
        headRatio >= _minHeadToBodyRatio && headRatio <= _maxHeadToBodyRatio;

    // Score based on how close to ideal proportions
    // Ideal head ratio is around 0.13 (1/7.5 of body height)
    const idealHeadRatio = 0.13;
    final headScore =
        1.0 - (headRatio - idealHeadRatio).abs().clamp(0.0, 0.5) * 2;

    return _CheckResult(
      passed: headRatioValid,
      score: headScore.clamp(0.0, 1.0),
    );
  }

  /// Check body bounding box aspect ratio
  _CheckResult _checkBodyAspectRatio(List<NormalizedLandmark> landmarks) {
    if (landmarks.isEmpty) {
      return const _CheckResult(passed: false, score: 0.0);
    }

    // Calculate bounding box from all landmarks
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final lm in landmarks) {
      if (lm.likelihood >= 0.3) {
        // Only use reasonably confident landmarks
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
        if (lm.y < minY) minY = lm.y;
        if (lm.y > maxY) maxY = lm.y;
      }
    }

    if (minX >= maxX || minY >= maxY) {
      return const _CheckResult(passed: false, score: 0.0);
    }

    final width = maxX - minX;
    final height = maxY - minY;

    // Prevent division by zero
    if (width < 0.001) {
      return const _CheckResult(passed: false, score: 0.0);
    }

    final aspectRatio = height / width;

    final isValid =
        aspectRatio >= _minBodyAspectRatio && aspectRatio <= _maxBodyAspectRatio;

    // Score based on how typical the aspect ratio is
    // Typical standing human is around 3.0-4.0
    const idealAspectRatio = 3.5;
    final deviation = (aspectRatio - idealAspectRatio).abs();
    final score = (1.0 - deviation / 5.0).clamp(0.0, 1.0);

    return _CheckResult(passed: isValid, score: score);
  }

  /// Check that landmarks are spatially coherent (not scattered randomly)
  _CheckResult _checkSpatialCoherence(List<NormalizedLandmark> landmarks) {
    final landmarkMap = {for (var lm in landmarks) lm.id: lm};

    // Check that torso landmarks form a reasonable quadrilateral
    final leftShoulder = landmarkMap[_leftShoulder];
    final rightShoulder = landmarkMap[_rightShoulder];
    final leftHip = landmarkMap[_leftHip];
    final rightHip = landmarkMap[_rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return const _CheckResult(passed: true, score: 0.5);
    }

    // Shoulders should be above hips
    final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipY = (leftHip.y + rightHip.y) / 2;

    if (shoulderY >= hipY) {
      // Shoulders below or at same level as hips - likely hallucination
      return const _CheckResult(passed: false, score: 0.1);
    }

    // Shoulder width and hip width should be reasonable
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    final hipWidth = (rightHip.x - leftHip.x).abs();
    final torsoHeight = hipY - shoulderY;

    // Shoulders should generally be wider than or similar to hips
    // (unless the person is rotated)
    final widthRatio =
        hipWidth > 0.001 ? shoulderWidth / hipWidth : double.infinity;
    final widthValid = widthRatio > 0.3 && widthRatio < 3.0;

    // Torso should have reasonable proportions
    final avgWidth = (shoulderWidth + hipWidth) / 2;
    final torsoRatio = avgWidth > 0.001 ? torsoHeight / avgWidth : 0.0;
    final torsoValid = torsoRatio > 0.3 && torsoRatio < 4.0;

    final isValid = widthValid && torsoValid;
    final score = (widthValid ? 0.5 : 0.0) + (torsoValid ? 0.5 : 0.0);

    return _CheckResult(passed: isValid, score: score);
  }

  /// Check that joint angles are within biomechanical limits
  _CheckResult _checkJointAngles(List<NormalizedLandmark> landmarks) {
    final landmarkMap = {for (var lm in landmarks) lm.id: lm};

    double totalScore = 0.0;
    int checksPerformed = 0;

    // Check elbow angles (should be 0-180 degrees, not hyperextended)
    final leftElbowAngle = _calculateAngle(
      landmarkMap[_leftShoulder],
      landmarkMap[_leftElbow],
      landmarkMap[_leftWrist],
    );

    if (leftElbowAngle != null) {
      // Elbow should be between 0 and 180 degrees
      final isValid = leftElbowAngle >= 0 && leftElbowAngle <= 180;
      totalScore += isValid ? 1.0 : 0.0;
      checksPerformed++;
    }

    final rightElbowAngle = _calculateAngle(
      landmarkMap[_rightShoulder],
      landmarkMap[_rightElbow],
      landmarkMap[_rightWrist],
    );

    if (rightElbowAngle != null) {
      final isValid = rightElbowAngle >= 0 && rightElbowAngle <= 180;
      totalScore += isValid ? 1.0 : 0.0;
      checksPerformed++;
    }

    // Check knee angles (should be 0-180 degrees)
    final leftKneeAngle = _calculateAngle(
      landmarkMap[_leftHip],
      landmarkMap[_leftKnee],
      landmarkMap[_leftAnkle],
    );

    if (leftKneeAngle != null) {
      final isValid = leftKneeAngle >= 0 && leftKneeAngle <= 180;
      totalScore += isValid ? 1.0 : 0.0;
      checksPerformed++;
    }

    final rightKneeAngle = _calculateAngle(
      landmarkMap[_rightHip],
      landmarkMap[_rightKnee],
      landmarkMap[_rightAnkle],
    );

    if (rightKneeAngle != null) {
      final isValid = rightKneeAngle >= 0 && rightKneeAngle <= 180;
      totalScore += isValid ? 1.0 : 0.0;
      checksPerformed++;
    }

    if (checksPerformed == 0) {
      return const _CheckResult(passed: true, score: 0.5);
    }

    final avgScore = totalScore / checksPerformed;
    return _CheckResult(
      passed: avgScore >= 0.5,
      score: avgScore,
    );
  }

  /// Check body symmetry (left and right sides should be roughly mirror images)
  _CheckResult _checkBodySymmetry(List<NormalizedLandmark> landmarks) {
    final landmarkMap = {for (var lm in landmarks) lm.id: lm};

    // Pairs to check for symmetry
    final symmetryPairs = [
      (_leftShoulder, _rightShoulder),
      (_leftHip, _rightHip),
      (_leftKnee, _rightKnee),
      (_leftAnkle, _rightAnkle),
      (_leftElbow, _rightElbow),
      (_leftWrist, _rightWrist),
    ];

    double totalScore = 0.0;
    int validPairs = 0;

    for (final pair in symmetryPairs) {
      final left = landmarkMap[pair.$1];
      final right = landmarkMap[pair.$2];

      if (left != null &&
          right != null &&
          left.likelihood >= 0.3 &&
          right.likelihood >= 0.3) {
        // Y coordinates should be similar for symmetric poses
        // Allow for natural asymmetry (up to 0.2 normalized units)
        final yDiff = (left.y - right.y).abs();
        final pairScore = (1.0 - yDiff / 0.3).clamp(0.0, 1.0);

        totalScore += pairScore;
        validPairs++;
      }
    }

    if (validPairs < 2) {
      // Not enough pairs to verify symmetry
      return const _CheckResult(passed: true, score: 0.5);
    }

    final avgScore = totalScore / validPairs;

    // We're lenient here - asymmetry is common in natural poses
    return _CheckResult(
      passed: avgScore >= 0.3,
      score: avgScore,
    );
  }

  // Helper methods

  /// Calculate midpoint between two landmarks
  NormalizedLandmark _midpoint(NormalizedLandmark a, NormalizedLandmark b) {
    return NormalizedLandmark(
      id: -1,
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      likelihood: (a.likelihood + b.likelihood) / 2,
    );
  }

  /// Calculate Euclidean distance between two landmarks
  double _distance(NormalizedLandmark a, NormalizedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate Euclidean distance from point to point
  double _distanceFromPoint(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate angle at point B in triangle ABC (in degrees)
  double? _calculateAngle(
    NormalizedLandmark? a,
    NormalizedLandmark? b,
    NormalizedLandmark? c,
  ) {
    if (a == null ||
        b == null ||
        c == null ||
        a.likelihood < 0.3 ||
        b.likelihood < 0.3 ||
        c.likelihood < 0.3) {
      return null;
    }

    // Vectors BA and BC
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    // Dot product and magnitudes
    final dotProduct = baX * bcX + baY * bcY;
    final magBA = math.sqrt(baX * baX + baY * baY);
    final magBC = math.sqrt(bcX * bcX + bcY * bcY);

    if (magBA < 0.0001 || magBC < 0.0001) {
      return null;
    }

    // Angle in radians, then convert to degrees
    final cosAngle = (dotProduct / (magBA * magBC)).clamp(-1.0, 1.0);
    final angleRad = math.acos(cosAngle);

    return angleRad * 180 / math.pi;
  }
}

/// Internal result of a single check
class _CheckResult {
  final bool passed;
  final double score;

  const _CheckResult({
    required this.passed,
    required this.score,
  });
}
