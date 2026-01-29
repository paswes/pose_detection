import 'dart:math' as math;

import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/validation/pose_landmark_ids.dart';
import 'package:pose_detection/domain/validation/pose_validation_result.dart';

/// Configuration for human pose validation thresholds
/// Tunable parameters for different use cases
class HumanPoseValidatorConfig {
  /// Minimum confidence for high-priority landmarks (shoulders, hips, nose)
  final double minHighPriorityConfidence;

  /// Minimum confidence for medium-priority landmarks (elbows, knees)
  final double minMediumPriorityConfidence;

  /// Minimum average confidence across all visible landmarks
  final double minAverageConfidence;

  /// Minimum number of high-priority landmarks that must be visible
  final int minHighPriorityLandmarks;

  /// Overall validation threshold (weighted score must exceed this)
  final double validationThreshold;

  /// Maximum allowed movement per frame (in normalized coordinates)
  /// Prevents accepting poses that "teleport" (likely false positives)
  final double maxFrameMovement;

  /// Number of frames to track for temporal consistency
  final int temporalWindowSize;

  // Anatomical proportion constraints (as ratios)

  /// Min/max ratio of shoulder width to hip width
  final (double min, double max) shoulderToHipRatio;

  /// Min/max ratio of upper arm to forearm length
  final (double min, double max) upperArmToForearmRatio;

  /// Min/max ratio of thigh to shin length
  final (double min, double max) thighToShinRatio;

  /// Min/max ratio of torso length to leg length
  final (double min, double max) torsoToLegRatio;

  /// Max asymmetry between left/right sides (as percentage)
  final double maxLateralAsymmetry;

  // Height-based validation (optional but recommended for fitness use)

  /// User's height in cm (optional - enables height-based validation)
  final double? userHeightCm;

  /// Expected head height as ratio of total body height (0.10-0.15)
  final (double min, double max) headToHeightRatio;

  /// Expected torso height (shoulder to hip) as ratio of total body height
  final (double min, double max) torsoToHeightRatio;

  /// Expected leg height (hip to ankle) as ratio of total body height
  final (double min, double max) legToHeightRatio;

  /// Max variance in estimated body height between frames (0.08 = 8%)
  final double maxTemporalHeightVariance;

  /// Minimum body size as percentage of image area (filters tiny/distant detections)
  final double minBodySizeRatio;

  const HumanPoseValidatorConfig({
    // Confidence thresholds - balanced for real-world conditions
    this.minHighPriorityConfidence = 0.50, // Relaxed for variable lighting
    this.minMediumPriorityConfidence = 0.30,
    this.minAverageConfidence = 0.40,
    this.minHighPriorityLandmarks = 3, // Allow one occluded landmark
    this.validationThreshold = 0.60, // Balanced threshold
    this.maxFrameMovement = 0.15, // 15% of screen per frame max
    this.temporalWindowSize = 5,
    // Anatomical ratios - these are the main furniture filters (keep tight)
    this.shoulderToHipRatio = (0.85, 1.25), // Shoulders slightly wider than hips
    this.upperArmToForearmRatio = (0.7, 1.4), // Similar lengths
    this.thighToShinRatio = (0.75, 1.35), // Thigh often slightly longer
    this.torsoToLegRatio = (0.4, 1.0), // Varies with pose
    this.maxLateralAsymmetry = 0.25, // 25% max asymmetry (relaxed slightly)
    // Height-based validation
    this.userHeightCm,
    this.headToHeightRatio = (0.08, 0.18), // Relaxed for pose variation
    this.torsoToHeightRatio = (0.22, 0.42), // Relaxed for bending
    this.legToHeightRatio = (0.38, 0.62), // Relaxed for pose variation
    this.maxTemporalHeightVariance = 0.12, // Relaxed for movement
    this.minBodySizeRatio = 0.015, // Body must occupy at least 1.5% of image
  });

  /// Preset for strict validation (near-zero false positives for fitness tracking)
  factory HumanPoseValidatorConfig.strict() {
    return const HumanPoseValidatorConfig(
      minHighPriorityConfidence: 0.70,
      minMediumPriorityConfidence: 0.50,
      minAverageConfidence: 0.55,
      minHighPriorityLandmarks: 4,
      validationThreshold: 0.75,
      maxFrameMovement: 0.08,
      shoulderToHipRatio: (0.90, 1.20),
      upperArmToForearmRatio: (0.75, 1.35),
      thighToShinRatio: (0.80, 1.30),
      maxLateralAsymmetry: 0.15,
      minBodySizeRatio: 0.03,
    );
  }

  /// Preset for lenient validation (more permissive, catches edge cases)
  factory HumanPoseValidatorConfig.lenient() {
    return const HumanPoseValidatorConfig(
      minHighPriorityConfidence: 0.40,
      minMediumPriorityConfidence: 0.25,
      minAverageConfidence: 0.35,
      minHighPriorityLandmarks: 3,
      validationThreshold: 0.55,
      maxFrameMovement: 0.20,
      shoulderToHipRatio: (0.6, 1.8),
      upperArmToForearmRatio: (0.5, 1.8),
      thighToShinRatio: (0.6, 1.6),
      maxLateralAsymmetry: 0.35,
      minBodySizeRatio: 0.01,
    );
  }
}

/// Validates that a detected pose represents a real human
/// Uses multiple heuristics: confidence, anatomy, proportions, temporal consistency
class HumanPoseValidator {
  final HumanPoseValidatorConfig config;

  /// Recent poses for temporal consistency tracking
  final List<TimestampedPose> _recentPoses = [];

  /// Recent estimated body heights for temporal height stability
  final List<double> _recentHeights = [];

  HumanPoseValidator({this.config = const HumanPoseValidatorConfig()});

  /// Clear temporal history (call when starting new session)
  void reset() {
    _recentPoses.clear();
    _recentHeights.clear();
  }

  /// Validate a pose and return detailed result
  PoseValidationResult validate(TimestampedPose pose) {
    // Run all validation checks
    final confidenceCheck = _checkLandmarkConfidence(pose);
    final coreBodyCheck = _checkCoreBodyPresence(pose);
    final proportionsCheck = _checkBodyProportions(pose);
    final connectivityCheck = _checkSkeletalConnectivity(pose);
    final coherenceCheck = _checkSpatialCoherence(pose);
    final temporalCheck = _checkTemporalConsistency(pose);
    final heightCheck = _checkBodyHeightConsistency(pose);

    final checks = ValidationChecks(
      landmarkConfidence: confidenceCheck,
      coreBodyPresence: coreBodyCheck,
      bodyProportions: proportionsCheck,
      skeletalConnectivity: connectivityCheck,
      spatialCoherence: coherenceCheck,
      temporalConsistency: temporalCheck,
      bodyHeightConsistency: heightCheck,
    );

    final weightedScore = checks.weightedScore;
    final isValid = weightedScore >= config.validationThreshold;

    // === DIAGNOSTIC LOGGING ===
    _logDiagnostics(pose, checks, weightedScore, isValid);

    // Update temporal history
    _updateTemporalHistory(pose, isValid);

    if (isValid) {
      return PoseValidationResult.valid(
        confidence: weightedScore,
        checks: checks,
      );
    }

    // Determine rejection reason from failed checks
    final failedChecks = checks.failedChecks;
    final rejectionReason = _generateRejectionReason(failedChecks, checks);

    return PoseValidationResult.invalid(
      reason: rejectionReason,
      checks: checks,
      confidence: weightedScore,
    );
  }

  /// Log detailed diagnostic information for debugging false positives
  void _logDiagnostics(
    TimestampedPose pose,
    ValidationChecks checks,
    double weightedScore,
    bool isValid,
  ) {
    final landmarks = pose.normalizedLandmarks;

    // Get key landmarks
    final nose = _getLandmarkById(landmarks, PoseLandmarkId.nose);
    final lShoulder = _getLandmarkById(landmarks, PoseLandmarkId.leftShoulder);
    final rShoulder = _getLandmarkById(landmarks, PoseLandmarkId.rightShoulder);
    final lHip = _getLandmarkById(landmarks, PoseLandmarkId.leftHip);
    final rHip = _getLandmarkById(landmarks, PoseLandmarkId.rightHip);
    final lAnkle = _getLandmarkById(landmarks, PoseLandmarkId.leftAnkle);
    final rAnkle = _getLandmarkById(landmarks, PoseLandmarkId.rightAnkle);

    // Calculate average confidence
    double totalConf = 0;
    int count = 0;
    for (final lm in landmarks) {
      if (lm.likelihood > 0.1) {
        totalConf += lm.likelihood;
        count++;
      }
    }
    final avgConf = count > 0 ? totalConf / count : 0.0;

    // Calculate geometry
    double shoulderWidth = 0;
    double hipWidth = 0;
    double shoulderHipRatio = 0;
    double torsoHeight = 0;
    double bodyHeight = 0;
    double bodyArea = 0;

    if (lShoulder != null && rShoulder != null) {
      shoulderWidth = (lShoulder.x - rShoulder.x).abs();
    }
    if (lHip != null && rHip != null) {
      hipWidth = (lHip.x - rHip.x).abs();
    }
    if (shoulderWidth > 0 && hipWidth > 0) {
      shoulderHipRatio = shoulderWidth / hipWidth;
    }

    // Torso height (shoulders to hips)
    if (lShoulder != null && rShoulder != null && lHip != null && rHip != null) {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final hipMidY = (lHip.y + rHip.y) / 2;
      torsoHeight = (hipMidY - shoulderMidY).abs();
    }

    // Body height (nose to ankles)
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minX = double.infinity;
    double maxX = double.negativeInfinity;

    for (final lm in landmarks) {
      if (lm.likelihood > 0.3) {
        if (lm.y < minY) minY = lm.y;
        if (lm.y > maxY) maxY = lm.y;
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
      }
    }

    if (minY != double.infinity && maxY != double.negativeInfinity) {
      bodyHeight = maxY - minY;
      final bodyWidth = maxX - minX;
      bodyArea = bodyHeight * bodyWidth;
    }

    // Vertical ordering check
    String verticalOrder = '';
    if (nose != null && lShoulder != null && rShoulder != null) {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      verticalOrder += nose.y < shoulderMidY ? 'nose<shoulder ' : 'nose>=shoulder! ';
    }
    if (lShoulder != null && rShoulder != null && lHip != null && rHip != null) {
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final hipMidY = (lHip.y + rHip.y) / 2;
      verticalOrder += shoulderMidY < hipMidY ? 'shoulder<hip ' : 'shoulder>=hip! ';
    }

    Logger.info('Validator', '''
=== POSE VALIDATION [Frame ${pose.frameIndex}] ===
RESULT: ${isValid ? '✓ VALID' : '✗ REJECTED'} (score: ${weightedScore.toStringAsFixed(3)}, threshold: ${config.validationThreshold})

CONFIDENCE: avg=${avgConf.toStringAsFixed(2)}, landmarks=$count/33

GEOMETRY:
  Shoulder width: ${shoulderWidth.toStringAsFixed(3)}
  Hip width: ${hipWidth.toStringAsFixed(3)}
  Shoulder/Hip ratio: ${shoulderHipRatio.toStringAsFixed(2)} (expected: 0.85-1.25)
  Torso height: ${torsoHeight.toStringAsFixed(3)}
  Body height: ${bodyHeight.toStringAsFixed(3)}
  Body area: ${(bodyArea * 100).toStringAsFixed(2)}% of image
  Vertical: $verticalOrder

POSITIONS (x, y):
  Nose: ${nose != null ? '(${nose.x.toStringAsFixed(2)}, ${nose.y.toStringAsFixed(2)})' : 'null'}
  L.Shoulder: ${lShoulder != null ? '(${lShoulder.x.toStringAsFixed(2)}, ${lShoulder.y.toStringAsFixed(2)})' : 'null'}
  R.Shoulder: ${rShoulder != null ? '(${rShoulder.x.toStringAsFixed(2)}, ${rShoulder.y.toStringAsFixed(2)})' : 'null'}
  L.Hip: ${lHip != null ? '(${lHip.x.toStringAsFixed(2)}, ${lHip.y.toStringAsFixed(2)})' : 'null'}
  R.Hip: ${rHip != null ? '(${rHip.x.toStringAsFixed(2)}, ${rHip.y.toStringAsFixed(2)})' : 'null'}
  L.Ankle: ${lAnkle != null ? '(${lAnkle.x.toStringAsFixed(2)}, ${lAnkle.y.toStringAsFixed(2)})' : 'null'}
  R.Ankle: ${rAnkle != null ? '(${rAnkle.x.toStringAsFixed(2)}, ${rAnkle.y.toStringAsFixed(2)})' : 'null'}

CHECKS:
  Confidence: ${checks.landmarkConfidence.passed ? 'PASS' : 'FAIL'} (${checks.landmarkConfidence.score.toStringAsFixed(2)}) ${checks.landmarkConfidence.details ?? ''}
  CoreBody: ${checks.coreBodyPresence.passed ? 'PASS' : 'FAIL'} (${checks.coreBodyPresence.score.toStringAsFixed(2)}) ${checks.coreBodyPresence.details ?? ''}
  Proportions: ${checks.bodyProportions.passed ? 'PASS' : 'FAIL'} (${checks.bodyProportions.score.toStringAsFixed(2)}) ${checks.bodyProportions.details ?? ''}
  Connectivity: ${checks.skeletalConnectivity.passed ? 'PASS' : 'FAIL'} (${checks.skeletalConnectivity.score.toStringAsFixed(2)}) ${checks.skeletalConnectivity.details ?? ''}
  Coherence: ${checks.spatialCoherence.passed ? 'PASS' : 'FAIL'} (${checks.spatialCoherence.score.toStringAsFixed(2)}) ${checks.spatialCoherence.details ?? ''}
  Temporal: ${checks.temporalConsistency != null ? (checks.temporalConsistency!.passed ? 'PASS' : 'FAIL') : 'N/A'} (${checks.temporalConsistency?.score.toStringAsFixed(2) ?? 'N/A'})
  Height: ${checks.bodyHeightConsistency != null ? (checks.bodyHeightConsistency!.passed ? 'PASS' : 'FAIL') : 'N/A'} (${checks.bodyHeightConsistency?.score.toStringAsFixed(2) ?? 'N/A'})
==========================================''');
  }

  /// Check 1: Landmark Confidence
  /// Ensures key landmarks have sufficient ML confidence
  CheckResult _checkLandmarkConfidence(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    // Check high-priority landmarks
    int highPriorityVisible = 0;

    for (final id in PoseLandmarkId.highPriority) {
      final landmark = _getLandmarkById(landmarks, id);
      if (landmark != null && landmark.likelihood >= config.minHighPriorityConfidence) {
        highPriorityVisible++;
      }
    }

    // Calculate average confidence across all landmarks
    double totalConfidence = 0;
    int visibleCount = 0;

    for (final landmark in landmarks) {
      if (landmark.likelihood > 0.1) {
        // Only count landmarks with minimal visibility
        totalConfidence += landmark.likelihood;
        visibleCount++;
      }
    }

    final averageConfidence = visibleCount > 0 ? totalConfidence / visibleCount : 0.0;

    // Score calculation
    final highPriorityScore = highPriorityVisible / PoseLandmarkId.highPriority.length;
    final confidenceScore = averageConfidence;
    final score = (highPriorityScore * 0.6 + confidenceScore * 0.4).clamp(0.0, 1.0);

    final passed = highPriorityVisible >= config.minHighPriorityLandmarks &&
        averageConfidence >= config.minAverageConfidence;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'highPriority: $highPriorityVisible/${PoseLandmarkId.highPriority.length}, avg: ${(averageConfidence * 100).toStringAsFixed(0)}%',
    );
  }

  /// Check 2: Core Body Presence
  /// Verifies the fundamental torso structure is visible
  CheckResult _checkCoreBodyPresence(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    // Check all four torso corners
    final leftShoulder = _getLandmarkById(landmarks, PoseLandmarkId.leftShoulder);
    final rightShoulder = _getLandmarkById(landmarks, PoseLandmarkId.rightShoulder);
    final leftHip = _getLandmarkById(landmarks, PoseLandmarkId.leftHip);
    final rightHip = _getLandmarkById(landmarks, PoseLandmarkId.rightHip);

    int visibleCorners = 0;

    for (final landmark in [leftShoulder, rightShoulder, leftHip, rightHip]) {
      if (landmark != null && landmark.likelihood >= config.minHighPriorityConfidence) {
        visibleCorners++;
      }
    }

    // Check for nose (head presence)
    final nose = _getLandmarkById(landmarks, PoseLandmarkId.nose);
    final hasHead = nose != null && nose.likelihood >= config.minHighPriorityConfidence;

    // Score: need at least 3 torso corners and preferably head
    final torsoScore = visibleCorners / 4.0;
    final headBonus = hasHead ? 0.1 : 0.0;
    final score = (torsoScore + headBonus).clamp(0.0, 1.0);

    // Need at least 3 corners for valid torso (allows minor occlusion)
    final passed = visibleCorners >= 3;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'torso: $visibleCorners/4, head: $hasHead',
    );
  }

  /// Check 3: Body Proportions
  /// Validates anatomical ratios match human body
  CheckResult _checkBodyProportions(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    int validRatios = 0;
    int checkedRatios = 0;
    final violations = <String>[];

    // Check shoulder to hip ratio
    final shoulderWidth = _getDistance(
      landmarks,
      PoseLandmarkId.leftShoulder,
      PoseLandmarkId.rightShoulder,
    );
    final hipWidth = _getDistance(
      landmarks,
      PoseLandmarkId.leftHip,
      PoseLandmarkId.rightHip,
    );

    if (shoulderWidth != null && hipWidth != null && hipWidth > 0.01) {
      checkedRatios++;
      final ratio = shoulderWidth / hipWidth;
      if (ratio >= config.shoulderToHipRatio.$1 && ratio <= config.shoulderToHipRatio.$2) {
        validRatios++;
      } else {
        violations.add('shoulder/hip=${ratio.toStringAsFixed(2)}');
      }
    }

    // Check arm proportions (left)
    final leftUpperArm = _getDistance(
      landmarks,
      PoseLandmarkId.leftShoulder,
      PoseLandmarkId.leftElbow,
    );
    final leftForearm = _getDistance(
      landmarks,
      PoseLandmarkId.leftElbow,
      PoseLandmarkId.leftWrist,
    );

    if (leftUpperArm != null && leftForearm != null && leftForearm > 0.01) {
      checkedRatios++;
      final ratio = leftUpperArm / leftForearm;
      if (ratio >= config.upperArmToForearmRatio.$1 &&
          ratio <= config.upperArmToForearmRatio.$2) {
        validRatios++;
      } else {
        violations.add('L-arm=${ratio.toStringAsFixed(2)}');
      }
    }

    // Check leg proportions (left)
    final leftThigh = _getDistance(
      landmarks,
      PoseLandmarkId.leftHip,
      PoseLandmarkId.leftKnee,
    );
    final leftShin = _getDistance(
      landmarks,
      PoseLandmarkId.leftKnee,
      PoseLandmarkId.leftAnkle,
    );

    if (leftThigh != null && leftShin != null && leftShin > 0.01) {
      checkedRatios++;
      final ratio = leftThigh / leftShin;
      if (ratio >= config.thighToShinRatio.$1 && ratio <= config.thighToShinRatio.$2) {
        validRatios++;
      } else {
        violations.add('L-leg=${ratio.toStringAsFixed(2)}');
      }
    }

    // Check lateral symmetry
    final rightUpperArm = _getDistance(
      landmarks,
      PoseLandmarkId.rightShoulder,
      PoseLandmarkId.rightElbow,
    );

    if (leftUpperArm != null && rightUpperArm != null) {
      checkedRatios++;
      final maxArm = math.max(leftUpperArm, rightUpperArm);
      final minArm = math.min(leftUpperArm, rightUpperArm);
      final asymmetry = maxArm > 0 ? (maxArm - minArm) / maxArm : 0;

      if (asymmetry <= config.maxLateralAsymmetry) {
        validRatios++;
      } else {
        violations.add('arm-asym=${(asymmetry * 100).toStringAsFixed(0)}%');
      }
    }

    // Score calculation
    final score = checkedRatios > 0 ? validRatios / checkedRatios : 0.0;

    // Pass if most ratios are valid (60% threshold - balanced for real humans)
    final passed = checkedRatios == 0 || (validRatios / checkedRatios) >= 0.60;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'valid: $validRatios/$checkedRatios${violations.isNotEmpty ? ', violations: ${violations.join(", ")}' : ''}',
    );
  }

  /// Check 4: Skeletal Connectivity
  /// Ensures landmarks form a connected skeleton (not scattered points)
  CheckResult _checkSkeletalConnectivity(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    // Check that connected body parts are actually near each other
    final connections = [
      // Torso connections
      (PoseLandmarkId.leftShoulder, PoseLandmarkId.rightShoulder, 0.5),
      (PoseLandmarkId.leftHip, PoseLandmarkId.rightHip, 0.4),
      (PoseLandmarkId.leftShoulder, PoseLandmarkId.leftHip, 0.6),
      (PoseLandmarkId.rightShoulder, PoseLandmarkId.rightHip, 0.6),
      // Arm connections
      (PoseLandmarkId.leftShoulder, PoseLandmarkId.leftElbow, 0.4),
      (PoseLandmarkId.leftElbow, PoseLandmarkId.leftWrist, 0.4),
      (PoseLandmarkId.rightShoulder, PoseLandmarkId.rightElbow, 0.4),
      (PoseLandmarkId.rightElbow, PoseLandmarkId.rightWrist, 0.4),
      // Leg connections
      (PoseLandmarkId.leftHip, PoseLandmarkId.leftKnee, 0.5),
      (PoseLandmarkId.leftKnee, PoseLandmarkId.leftAnkle, 0.5),
      (PoseLandmarkId.rightHip, PoseLandmarkId.rightKnee, 0.5),
      (PoseLandmarkId.rightKnee, PoseLandmarkId.rightAnkle, 0.5),
    ];

    int validConnections = 0;
    int checkedConnections = 0;

    for (final (id1, id2, maxDist) in connections) {
      final dist = _getDistance(landmarks, id1, id2);
      if (dist != null) {
        checkedConnections++;
        // Connection is valid if distance is within expected range
        if (dist <= maxDist && dist >= 0.01) {
          // Not too far, not collapsed
          validConnections++;
        }
      }
    }

    final score = checkedConnections > 0 ? validConnections / checkedConnections : 0.0;

    // Pass if most connections are valid (65% threshold - balanced for real humans)
    final passed = checkedConnections == 0 || score >= 0.65;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'connected: $validConnections/$checkedConnections',
    );
  }

  /// Check 5: Spatial Coherence
  /// Verifies landmarks form a coherent spatial structure
  CheckResult _checkSpatialCoherence(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    int coherentRelations = 0;
    int checkedRelations = 0;

    // Check vertical ordering (head above shoulders above hips above knees above ankles)
    final nose = _getLandmarkById(landmarks, PoseLandmarkId.nose);
    final leftShoulder = _getLandmarkById(landmarks, PoseLandmarkId.leftShoulder);
    final rightShoulder = _getLandmarkById(landmarks, PoseLandmarkId.rightShoulder);
    final leftHip = _getLandmarkById(landmarks, PoseLandmarkId.leftHip);
    final rightHip = _getLandmarkById(landmarks, PoseLandmarkId.rightHip);
    final leftKnee = _getLandmarkById(landmarks, PoseLandmarkId.leftKnee);
    final leftAnkle = _getLandmarkById(landmarks, PoseLandmarkId.leftAnkle);

    // Nose should be above shoulders (allowing for looking down poses)
    if (nose != null && leftShoulder != null && rightShoulder != null) {
      checkedRelations++;
      final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
      // Head can be at same level but not way below (relaxed for real-world poses)
      if (nose.y <= shoulderMidY + 0.12) {
        coherentRelations++;
      }
    }

    // Shoulders should be above hips (with tolerance for bending)
    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null) {
      checkedRelations++;
      final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
      final hipMidY = (leftHip.y + rightHip.y) / 2;
      // Allow bending forward (relaxed for exercise poses like crunches, pushups)
      if (shoulderMidY <= hipMidY + 0.15) {
        coherentRelations++;
      }
    }

    // Hips should be above knees (unless sitting with legs up)
    if (leftHip != null && leftKnee != null) {
      checkedRelations++;
      if (leftHip.y <= leftKnee.y + 0.1) {
        coherentRelations++;
      }
    }

    // Knees should be above ankles (unless kneeling)
    if (leftKnee != null && leftAnkle != null) {
      checkedRelations++;
      if (leftKnee.y <= leftAnkle.y + 0.1) {
        coherentRelations++;
      }
    }

    // Check horizontal coherence: left/right sides shouldn't be swapped
    if (leftShoulder != null && rightShoulder != null) {
      checkedRelations++;
      // Shoulders must have meaningful horizontal separation (relaxed for angled views)
      final xDiff = (leftShoulder.x - rightShoulder.x).abs();
      if (xDiff >= 0.05) {
        // Shoulders have clear separation
        coherentRelations++;
      }
    }

    final score = checkedRelations > 0 ? coherentRelations / checkedRelations : 0.0;

    // Pass if most spatial relations are coherent (70% threshold)
    final passed = checkedRelations == 0 || score >= 0.60;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'coherent: $coherentRelations/$checkedRelations',
    );
  }

  /// Check 6: Temporal Consistency
  /// Verifies pose doesn't "teleport" between frames
  CheckResult? _checkTemporalConsistency(TimestampedPose pose) {
    if (_recentPoses.isEmpty) {
      return null; // No history to compare against
    }

    final previousPose = _recentPoses.last;
    final landmarks = pose.normalizedLandmarks;
    final prevLandmarks = previousPose.normalizedLandmarks;

    // Calculate average movement of key landmarks
    final keyLandmarks = [
      PoseLandmarkId.nose,
      PoseLandmarkId.leftShoulder,
      PoseLandmarkId.rightShoulder,
      PoseLandmarkId.leftHip,
      PoseLandmarkId.rightHip,
    ];

    double totalMovement = 0;
    int comparedLandmarks = 0;

    for (final id in keyLandmarks) {
      final curr = _getLandmarkById(landmarks, id);
      final prev = _getLandmarkById(prevLandmarks, id);

      if (curr != null &&
          prev != null &&
          curr.likelihood >= 0.3 &&
          prev.likelihood >= 0.3) {
        final dx = curr.x - prev.x;
        final dy = curr.y - prev.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        totalMovement += distance;
        comparedLandmarks++;
      }
    }

    if (comparedLandmarks == 0) {
      return null;
    }

    final avgMovement = totalMovement / comparedLandmarks;

    // Score inversely proportional to movement (less movement = higher score)
    // Movement of 0 = score of 1.0, movement of maxFrameMovement = score of 0.5
    final normalizedMovement = avgMovement / config.maxFrameMovement;
    final score = (1.0 - normalizedMovement * 0.5).clamp(0.0, 1.0);

    final passed = avgMovement <= config.maxFrameMovement;

    return CheckResult(
      passed: passed,
      score: score,
      details: 'movement: ${(avgMovement * 100).toStringAsFixed(1)}%',
    );
  }

  /// Check 7: Body Height Consistency
  /// Validates that body parts form anatomically consistent proportions
  /// relative to the total detected body height
  CheckResult? _checkBodyHeightConsistency(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    // Get key body landmarks
    final nose = _getLandmarkById(landmarks, PoseLandmarkId.nose);
    final leftShoulder = _getLandmarkById(landmarks, PoseLandmarkId.leftShoulder);
    final rightShoulder = _getLandmarkById(landmarks, PoseLandmarkId.rightShoulder);
    final leftHip = _getLandmarkById(landmarks, PoseLandmarkId.leftHip);
    final rightHip = _getLandmarkById(landmarks, PoseLandmarkId.rightHip);
    final leftAnkle = _getLandmarkById(landmarks, PoseLandmarkId.leftAnkle);
    final rightAnkle = _getLandmarkById(landmarks, PoseLandmarkId.rightAnkle);

    // Need minimum landmarks to calculate body height
    if (nose == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    // Calculate segment heights (using Y coordinates - lower Y = higher on screen)
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipMidY = (leftHip.y + rightHip.y) / 2;

    // Head height: nose to shoulder midpoint
    final headHeight = shoulderMidY - nose.y;

    // Torso height: shoulder to hip
    final torsoHeight = hipMidY - shoulderMidY;

    // Leg height: hip to ankle (use available ankle)
    double? legHeight;
    if (leftAnkle != null &&
        leftAnkle.likelihood >= config.minMediumPriorityConfidence) {
      legHeight = leftAnkle.y - hipMidY;
    } else if (rightAnkle != null &&
        rightAnkle.likelihood >= config.minMediumPriorityConfidence) {
      legHeight = rightAnkle.y - hipMidY;
    }

    // Calculate total detected height
    double totalHeight;
    if (legHeight != null && legHeight > 0) {
      totalHeight = headHeight + torsoHeight + legHeight;
    } else {
      // Estimate without legs (less accurate but still useful)
      totalHeight = (headHeight + torsoHeight) / 0.55; // Head+torso ≈ 55% of height
    }

    // Validate proportions
    int validProportions = 0;
    int checkedProportions = 0;
    final violations = <String>[];

    // Check head ratio (should be 10-16% of height)
    if (headHeight > 0 && totalHeight > 0) {
      checkedProportions++;
      final headRatio = headHeight / totalHeight;
      if (headRatio >= config.headToHeightRatio.$1 &&
          headRatio <= config.headToHeightRatio.$2) {
        validProportions++;
      } else {
        violations.add('head=${(headRatio * 100).toStringAsFixed(0)}%');
      }
    }

    // Check torso ratio (should be 25-38% of height)
    if (torsoHeight > 0 && totalHeight > 0) {
      checkedProportions++;
      final torsoRatio = torsoHeight / totalHeight;
      if (torsoRatio >= config.torsoToHeightRatio.$1 &&
          torsoRatio <= config.torsoToHeightRatio.$2) {
        validProportions++;
      } else {
        violations.add('torso=${(torsoRatio * 100).toStringAsFixed(0)}%');
      }
    }

    // Check leg ratio if available (should be 42-58% of height)
    if (legHeight != null && legHeight > 0 && totalHeight > 0) {
      checkedProportions++;
      final legRatio = legHeight / totalHeight;
      if (legRatio >= config.legToHeightRatio.$1 &&
          legRatio <= config.legToHeightRatio.$2) {
        validProportions++;
      } else {
        violations.add('legs=${(legRatio * 100).toStringAsFixed(0)}%');
      }
    }

    // Check minimum body size (avoid tiny/distant false detections)
    final shoulderWidth = _getDistance(
      landmarks,
      PoseLandmarkId.leftShoulder,
      PoseLandmarkId.rightShoulder,
    );
    final hipWidth = _getDistance(
      landmarks,
      PoseLandmarkId.leftHip,
      PoseLandmarkId.rightHip,
    );

    if (shoulderWidth != null && hipWidth != null && torsoHeight > 0) {
      checkedProportions++;
      // Approximate body area as rectangle
      final avgWidth = (shoulderWidth + hipWidth) / 2;
      final bodyArea = avgWidth * (headHeight + torsoHeight);
      if (bodyArea >= config.minBodySizeRatio) {
        validProportions++;
      } else {
        violations.add('size=${(bodyArea * 100).toStringAsFixed(1)}%');
      }
    }

    // Check temporal height stability
    if (_recentHeights.isNotEmpty && totalHeight > 0) {
      checkedProportions++;
      final avgRecentHeight =
          _recentHeights.reduce((a, b) => a + b) / _recentHeights.length;
      final heightVariance = (totalHeight - avgRecentHeight).abs() / avgRecentHeight;

      if (heightVariance <= config.maxTemporalHeightVariance) {
        validProportions++;
      } else {
        violations.add('heightVar=${(heightVariance * 100).toStringAsFixed(0)}%');
      }
    }

    // Update height history for valid measurements
    if (totalHeight > 0) {
      _recentHeights.add(totalHeight);
      while (_recentHeights.length > config.temporalWindowSize) {
        _recentHeights.removeAt(0);
      }
    }

    if (checkedProportions == 0) {
      return null;
    }

    final score = validProportions / checkedProportions;
    final passed = score >= 0.6; // Need 60% of height checks to pass

    return CheckResult(
      passed: passed,
      score: score,
      details: 'valid: $validProportions/$checkedProportions${violations.isNotEmpty ? ', violations: ${violations.join(", ")}' : ''}',
    );
  }

  /// Update temporal history with new pose
  void _updateTemporalHistory(TimestampedPose pose, bool wasValid) {
    if (wasValid) {
      _recentPoses.add(pose);

      // Keep only the configured window size
      while (_recentPoses.length > config.temporalWindowSize) {
        _recentPoses.removeAt(0);
      }
    }
    // Invalid poses don't get added to history (prevents corrupting baseline)
  }

  /// Helper: Get landmark by ID
  NormalizedLandmark? _getLandmarkById(List<NormalizedLandmark> landmarks, int id) {
    for (final landmark in landmarks) {
      if (landmark.id == id) {
        return landmark;
      }
    }
    return null;
  }

  /// Helper: Get distance between two landmarks
  double? _getDistance(List<NormalizedLandmark> landmarks, int id1, int id2) {
    final l1 = _getLandmarkById(landmarks, id1);
    final l2 = _getLandmarkById(landmarks, id2);

    if (l1 == null ||
        l2 == null ||
        l1.likelihood < config.minMediumPriorityConfidence ||
        l2.likelihood < config.minMediumPriorityConfidence) {
      return null;
    }

    final dx = l1.x - l2.x;
    final dy = l1.y - l2.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Generate human-readable rejection reason
  String _generateRejectionReason(List<String> failedChecks, ValidationChecks checks) {
    if (failedChecks.isEmpty) {
      return 'Score below threshold';
    }

    // Return the most important failure
    if (failedChecks.contains('coreBodyPresence')) {
      return 'Missing core body landmarks (${checks.coreBodyPresence.details})';
    }
    if (failedChecks.contains('landmarkConfidence')) {
      return 'Low landmark confidence (${checks.landmarkConfidence.details})';
    }
    if (failedChecks.contains('bodyProportions')) {
      return 'Invalid body proportions (${checks.bodyProportions.details})';
    }
    if (failedChecks.contains('bodyHeightConsistency')) {
      return 'Invalid body height (${checks.bodyHeightConsistency?.details})';
    }
    if (failedChecks.contains('spatialCoherence')) {
      return 'Spatial structure invalid (${checks.spatialCoherence.details})';
    }
    if (failedChecks.contains('skeletalConnectivity')) {
      return 'Skeleton disconnected (${checks.skeletalConnectivity.details})';
    }
    if (failedChecks.contains('temporalConsistency')) {
      return 'Pose teleported (${checks.temporalConsistency?.details})';
    }

    return 'Failed checks: ${failedChecks.join(", ")}';
  }
}
