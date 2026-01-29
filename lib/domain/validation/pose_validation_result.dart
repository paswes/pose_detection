/// Result of human pose validation with detailed breakdown
class PoseValidationResult {
  /// Overall validation passed
  final bool isValid;

  /// Overall confidence score (0.0 to 1.0)
  /// Composite of all validation factors
  final double confidence;

  /// Individual check results for debugging and tuning
  final ValidationChecks checks;

  /// Human-readable reason if invalid (for logging/debugging)
  final String? rejectionReason;

  const PoseValidationResult({
    required this.isValid,
    required this.confidence,
    required this.checks,
    this.rejectionReason,
  });

  /// Create a valid result
  factory PoseValidationResult.valid({
    required double confidence,
    required ValidationChecks checks,
  }) {
    return PoseValidationResult(
      isValid: true,
      confidence: confidence,
      checks: checks,
    );
  }

  /// Create an invalid result with reason
  factory PoseValidationResult.invalid({
    required String reason,
    required ValidationChecks checks,
    double confidence = 0.0,
  }) {
    return PoseValidationResult(
      isValid: false,
      confidence: confidence,
      checks: checks,
      rejectionReason: reason,
    );
  }

  @override
  String toString() {
    if (isValid) {
      return 'Valid(confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
    }
    return 'Invalid($rejectionReason, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Individual validation check results
class ValidationChecks {
  /// Landmark confidence check
  final CheckResult landmarkConfidence;

  /// Core body presence check (torso landmarks visible)
  final CheckResult coreBodyPresence;

  /// Body proportion check (anatomically plausible ratios)
  final CheckResult bodyProportions;

  /// Skeletal connectivity check (connected parts form valid skeleton)
  final CheckResult skeletalConnectivity;

  /// Spatial coherence check (landmarks form coherent spatial structure)
  final CheckResult spatialCoherence;

  /// Temporal consistency check (pose doesn't teleport between frames)
  final CheckResult? temporalConsistency;

  /// Body height consistency check (head+torso+legs form valid proportions)
  final CheckResult? bodyHeightConsistency;

  const ValidationChecks({
    required this.landmarkConfidence,
    required this.coreBodyPresence,
    required this.bodyProportions,
    required this.skeletalConnectivity,
    required this.spatialCoherence,
    this.temporalConsistency,
    this.bodyHeightConsistency,
  });

  /// Get all checks that failed
  List<String> get failedChecks {
    final failed = <String>[];
    if (!landmarkConfidence.passed) failed.add('landmarkConfidence');
    if (!coreBodyPresence.passed) failed.add('coreBodyPresence');
    if (!bodyProportions.passed) failed.add('bodyProportions');
    if (!skeletalConnectivity.passed) failed.add('skeletalConnectivity');
    if (!spatialCoherence.passed) failed.add('spatialCoherence');
    if (temporalConsistency != null && !temporalConsistency!.passed) {
      failed.add('temporalConsistency');
    }
    if (bodyHeightConsistency != null && !bodyHeightConsistency!.passed) {
      failed.add('bodyHeightConsistency');
    }
    return failed;
  }

  /// Calculate weighted score from all checks
  double get weightedScore {
    // Weights for each check (sum to 1.0)
    const weights = (
      landmarkConfidence: 0.18,
      coreBodyPresence: 0.22,
      bodyProportions: 0.25,
      skeletalConnectivity: 0.15,
      spatialCoherence: 0.15,
      bodyHeightConsistency: 0.05, // Small weight, but acts as additional filter
    );

    double score = landmarkConfidence.score * weights.landmarkConfidence +
        coreBodyPresence.score * weights.coreBodyPresence +
        bodyProportions.score * weights.bodyProportions +
        skeletalConnectivity.score * weights.skeletalConnectivity +
        spatialCoherence.score * weights.spatialCoherence;

    // Body height consistency is optional (needs enough landmarks)
    if (bodyHeightConsistency != null) {
      score += bodyHeightConsistency!.score * weights.bodyHeightConsistency;
    } else {
      // If not available, redistribute weight to other checks
      score += 0.5 * weights.bodyHeightConsistency; // Neutral contribution
    }

    // Temporal consistency is optional (first frame has none)
    // When present, it acts as a multiplier (good consistency boosts, bad penalizes)
    if (temporalConsistency != null) {
      // Range: 0.7 to 1.0 multiplier
      final temporalMultiplier = 0.7 + (temporalConsistency!.score * 0.3);
      score *= temporalMultiplier;
    }

    return score.clamp(0.0, 1.0);
  }
}

/// Result of a single validation check
class CheckResult {
  /// Whether this check passed
  final bool passed;

  /// Score for this check (0.0 to 1.0)
  final double score;

  /// Details about the check (for debugging)
  final String? details;

  const CheckResult({
    required this.passed,
    required this.score,
    this.details,
  });

  factory CheckResult.pass({required double score, String? details}) {
    return CheckResult(passed: true, score: score, details: details);
  }

  factory CheckResult.fail({required double score, String? details}) {
    return CheckResult(passed: false, score: score, details: details);
  }

  @override
  String toString() => '${passed ? "PASS" : "FAIL"}(${(score * 100).toStringAsFixed(0)}%)${details != null ? ": $details" : ""}';
}
