import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/detected_object.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

// Re-export NormalizedBoundingBox for backward compatibility
export 'package:pose_detection/domain/models/detected_object.dart'
    show NormalizedBoundingBox;

/// Reason why a pose was rejected during validation
enum RejectionReason {
  /// No human detected in the frame by object detector
  noHumanDetected,

  /// Human detected but bounding box too small (too far away or partial)
  humanTooSmall,

  /// Human bounding box doesn't overlap with pose bounding box
  poseOutsideHumanBounds,

  /// Multiple humans detected - ambiguous which pose belongs to whom
  multipleHumansDetected,

  /// Pose failed biomechanical constraints check
  biomechanicallyInvalid,

  /// Key landmarks missing or below confidence threshold
  insufficientLandmarkConfidence,

  /// Pose proportions are anatomically impossible
  anatomicallyImpossible,

  /// Landmark positions suggest non-human detection (e.g., on furniture)
  suspectedHallucination,
}

/// Result of human detection analysis (interpreted from raw object detection)
/// This is created by the Domain layer from agnostic ObjectDetectionResult
class HumanDetectionResult extends Equatable {
  /// Whether at least one human was detected
  final bool humanDetected;

  /// Number of humans detected in the frame
  final int humanCount;

  /// Bounding box of the primary (largest) human in normalized coordinates
  /// null if no human detected
  final NormalizedBoundingBox? primaryHumanBounds;

  /// Confidence score for the primary human detection (0.0 to 1.0)
  final double? primaryConfidence;

  /// Processing time for object detection in milliseconds
  final double detectionLatencyMs;

  const HumanDetectionResult({
    required this.humanDetected,
    required this.humanCount,
    this.primaryHumanBounds,
    this.primaryConfidence,
    required this.detectionLatencyMs,
  });

  @override
  List<Object?> get props => [
        humanDetected,
        humanCount,
        primaryHumanBounds,
        primaryConfidence,
        detectionLatencyMs,
      ];

  @override
  String toString() =>
      'HumanDetectionResult(detected: $humanDetected, count: $humanCount, '
      'confidence: ${primaryConfidence?.toStringAsFixed(2)}, '
      'latency: ${detectionLatencyMs.toStringAsFixed(2)}ms)';
}

/// Result of biomechanical sanity check
class SanityCheckResult extends Equatable {
  /// Whether the pose passed all sanity checks
  final bool isValid;

  /// List of specific checks that failed (empty if valid)
  final List<RejectionReason> failedChecks;

  /// Confidence score for this being a real human pose (0.0 to 1.0)
  /// Higher values indicate more confidence in validity
  final double humanLikelihood;

  /// Optional debug information about individual checks
  final Map<String, double>? checkScores;

  const SanityCheckResult({
    required this.isValid,
    required this.failedChecks,
    required this.humanLikelihood,
    this.checkScores,
  });

  /// Create a passing result
  const SanityCheckResult.valid({
    this.humanLikelihood = 1.0,
    this.checkScores,
  })  : isValid = true,
        failedChecks = const [];

  /// Create a failing result
  const SanityCheckResult.invalid({
    required this.failedChecks,
    this.humanLikelihood = 0.0,
    this.checkScores,
  }) : isValid = false;

  @override
  List<Object?> get props => [isValid, failedChecks, humanLikelihood];

  @override
  String toString() => 'SanityCheckResult(valid: $isValid, '
      'likelihood: ${humanLikelihood.toStringAsFixed(2)}, '
      'failed: ${failedChecks.map((r) => r.name).join(", ")})';
}

/// Complete validation result combining object detection and sanity checks
class PoseValidationResult extends Equatable {
  /// The original pose that was validated
  final TimestampedPose pose;

  /// Whether the pose passed all validation gates
  final bool isValid;

  /// Human detection result from object detector
  final HumanDetectionResult humanDetection;

  /// Biomechanical sanity check result
  final SanityCheckResult sanityCheck;

  /// Combined rejection reasons (empty if valid)
  List<RejectionReason> get rejectionReasons => [
        if (!humanDetection.humanDetected) RejectionReason.noHumanDetected,
        if (humanDetection.humanCount > 1)
          RejectionReason.multipleHumansDetected,
        ...sanityCheck.failedChecks,
      ];

  /// Total validation latency in milliseconds
  double get totalLatencyMs => humanDetection.detectionLatencyMs;

  const PoseValidationResult({
    required this.pose,
    required this.isValid,
    required this.humanDetection,
    required this.sanityCheck,
  });

  @override
  List<Object?> get props => [pose, isValid, humanDetection, sanityCheck];

  @override
  String toString() => 'PoseValidationResult(valid: $isValid, '
      'human: ${humanDetection.humanDetected}, '
      'sanity: ${sanityCheck.isValid}, '
      'reasons: ${rejectionReasons.map((r) => r.name).join(", ")})';
}

/// Validated pose - only created when a pose passes all validation
/// This type guarantees the pose has been verified as a real human
class ValidatedPose extends Equatable {
  final TimestampedPose pose;
  final PoseValidationResult validation;

  ValidatedPose({
    required this.pose,
    required this.validation,
  }) : assert(validation.isValid, 'ValidatedPose requires valid validation');

  /// Convenience accessors
  List<RawLandmark> get landmarks => pose.landmarks;
  List<NormalizedLandmark> get normalizedLandmarks => pose.normalizedLandmarks;
  int get frameIndex => pose.frameIndex;
  int get timestampMicros => pose.timestampMicros;
  int? get deltaTimeMicros => pose.deltaTimeMicros;

  @override
  List<Object?> get props => [pose, validation];
}
