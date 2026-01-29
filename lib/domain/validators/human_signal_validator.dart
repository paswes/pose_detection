import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/segmentation_result.dart';
import 'package:pose_detection/domain/models/validation_result.dart';
import 'package:pose_detection/domain/validators/human_sanity_checker.dart';

/// Configuration for the human signal validation
class HumanValidationConfig {
  /// Minimum segmentation confidence threshold for human detection
  final double minSegmentationConfidence;

  /// Minimum coverage of frame by foreground (0.0 to 1.0)
  /// Filters out distant or partial detections
  final double minForegroundCoverage;

  /// Maximum coverage - if too high, might be false positive or too close
  final double maxForegroundCoverage;

  /// Minimum IoU overlap between pose bounding box and human bounding box
  final double minPoseHumanOverlap;

  /// Minimum human likelihood score from biomechanical sanity checker
  final double minHumanLikelihood;

  const HumanValidationConfig({
    this.minSegmentationConfidence = 0.5,
    this.minForegroundCoverage = 0.02, // 2% of frame minimum
    this.maxForegroundCoverage = 0.95, // 95% max (avoid full-frame false positives)
    this.minPoseHumanOverlap = 0.3,
    this.minHumanLikelihood = 0.5,
  });

  /// Default strict configuration
  static const strict = HumanValidationConfig();

  /// Lenient configuration - lower thresholds
  static const lenient = HumanValidationConfig(
    minSegmentationConfidence: 0.3,
    minForegroundCoverage: 0.01,
    maxForegroundCoverage: 0.98,
    minPoseHumanOverlap: 0.2,
    minHumanLikelihood: 0.3,
  );
}

/// Domain-layer validator for human signals
///
/// This is the "biometric control center" - the single source of truth for
/// interpreting whether detected data represents a real human.
///
/// Key responsibilities (per Clean Architecture):
/// - All interpretation and validation logic lives here
/// - Decides biological and physical authenticity of data
/// - Uses various raw data signals (segmentation, poses) for decision making
/// - Completely agnostic of data acquisition (Core layer responsibility)
///
/// Flow: SegmentationResult -> HumanDetectionResult -> PoseValidation
class HumanSignalValidator {
  final HumanSanityChecker _sanityChecker;
  final HumanValidationConfig config;

  HumanSignalValidator({
    HumanSanityChecker? sanityChecker,
    this.config = const HumanValidationConfig(),
  }) : _sanityChecker = sanityChecker ?? HumanSanityChecker();

  /// Interpret segmentation results to determine human presence
  ///
  /// This is where the Domain layer applies human-specific knowledge
  /// to agnostic Core layer segmentation data.
  HumanDetectionResult interpretSegmentation(
    SegmentationResult segmentation,
  ) {
    // Check if there's sufficient foreground coverage
    final coverage = segmentation.foregroundCoverage;
    final confidence = segmentation.averageConfidence;

    // Validate coverage is within acceptable range
    final hasSufficientCoverage = coverage >= config.minForegroundCoverage &&
        coverage <= config.maxForegroundCoverage;

    // Validate confidence meets threshold
    final hasSufficientConfidence = confidence >= config.minSegmentationConfidence;

    // Human detected if both conditions are met
    final humanDetected = segmentation.hasForeground &&
        hasSufficientCoverage &&
        hasSufficientConfidence;

    return HumanDetectionResult(
      humanDetected: humanDetected,
      coverage: coverage,
      humanBounds: segmentation.foregroundBounds,
      confidence: confidence,
      detectionLatencyMs: segmentation.segmentationLatencyMs,
    );
  }

  /// Validate a detected pose using both segmentation and biomechanical checks
  ///
  /// This is the main validation pipeline that produces the "Human-Only Signal".
  PoseValidationResult validatePose({
    required TimestampedPose pose,
    required HumanDetectionResult humanDetection,
  }) {
    // Gate 1: Human detection check (from segmentation)
    bool passesHumanDetection = humanDetection.humanDetected;

    // Check pose-human bounding box overlap if we have bounds
    if (passesHumanDetection && humanDetection.humanBounds != null) {
      final poseBounds = _calculatePoseBounds(pose);
      if (poseBounds != null) {
        final overlap = humanDetection.humanBounds!.iou(poseBounds);
        if (overlap < config.minPoseHumanOverlap) {
          passesHumanDetection = false;
        }
      }
    }

    // Gate 2: Biomechanical sanity check
    SanityCheckResult sanityResult = _sanityChecker.validate(pose);

    // Apply minimum human likelihood threshold
    if (sanityResult.humanLikelihood < config.minHumanLikelihood) {
      sanityResult = SanityCheckResult(
        isValid: false,
        failedChecks: [
          ...sanityResult.failedChecks,
          if (!sanityResult.failedChecks.contains(
            RejectionReason.suspectedHallucination,
          ))
            RejectionReason.suspectedHallucination,
        ],
        humanLikelihood: sanityResult.humanLikelihood,
        checkScores: sanityResult.checkScores,
      );
    }

    // Determine overall validity
    final isValid = passesHumanDetection && sanityResult.isValid;

    return PoseValidationResult(
      pose: pose,
      isValid: isValid,
      humanDetection: humanDetection,
      sanityCheck: sanityResult,
    );
  }

  /// Quick check if human is present (without full pose validation)
  /// Use this to decide whether to run pose detection at all
  bool isHumanPresent(HumanDetectionResult humanDetection) {
    return humanDetection.humanDetected;
  }

  /// Calculate bounding box of pose from normalized landmarks
  NormalizedBoundingBox? _calculatePoseBounds(TimestampedPose pose) {
    if (pose.normalizedLandmarks.isEmpty) return null;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    int validCount = 0;
    for (final lm in pose.normalizedLandmarks) {
      // Only use confident landmarks for bounding box
      if (lm.likelihood >= 0.3) {
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
        if (lm.y < minY) minY = lm.y;
        if (lm.y > maxY) maxY = lm.y;
        validCount++;
      }
    }

    if (validCount < 4 || minX >= maxX || minY >= maxY) {
      return null;
    }

    return NormalizedBoundingBox(
      left: minX,
      top: minY,
      right: maxX,
      bottom: maxY,
    );
  }
}
