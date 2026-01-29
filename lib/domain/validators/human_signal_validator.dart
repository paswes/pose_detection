import 'package:pose_detection/domain/models/detected_object.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/validation_result.dart';
import 'package:pose_detection/domain/validators/human_sanity_checker.dart';

/// Configuration for the human signal validation
class HumanValidationConfig {
  /// Minimum confidence threshold for human detection
  final double minHumanConfidence;

  /// Minimum bounding box area (normalized) to consider a valid human
  /// Filters out distant or partial detections
  final double minBoundingBoxArea;

  /// Minimum IoU overlap between pose bounding box and human bounding box
  final double minPoseHumanOverlap;

  /// Whether to allow poses when multiple humans are detected
  /// If false, poses are rejected when multiple humans are present
  final bool allowMultipleHumans;

  /// Minimum human likelihood score from biomechanical sanity checker
  final double minHumanLikelihood;

  /// Labels that identify a human in object detection results
  final List<String> humanLabels;

  const HumanValidationConfig({
    this.minHumanConfidence = 0.5,
    this.minBoundingBoxArea = 0.02, // 2% of frame
    this.minPoseHumanOverlap = 0.3,
    this.allowMultipleHumans = false,
    this.minHumanLikelihood = 0.5,
    this.humanLabels = const ['person', 'human', 'man', 'woman'],
  });

  /// Default strict configuration
  static const strict = HumanValidationConfig();

  /// Lenient configuration - lower thresholds
  static const lenient = HumanValidationConfig(
    minHumanConfidence: 0.3,
    minBoundingBoxArea: 0.01,
    minPoseHumanOverlap: 0.2,
    minHumanLikelihood: 0.3,
    allowMultipleHumans: true,
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
/// - Uses various raw data signals (objects, poses) for decision making
/// - Completely agnostic of data acquisition (Core layer responsibility)
///
/// Flow: ObjectDetectionResult -> HumanDetectionResult -> PoseValidation
class HumanSignalValidator {
  final HumanSanityChecker _sanityChecker;
  final HumanValidationConfig config;

  HumanSignalValidator({
    HumanSanityChecker? sanityChecker,
    this.config = const HumanValidationConfig(),
  }) : _sanityChecker = sanityChecker ?? HumanSanityChecker();

  /// Interpret raw object detection results to determine human presence
  ///
  /// This is where the Domain layer applies human-specific knowledge
  /// to agnostic Core layer data.
  HumanDetectionResult interpretObjectDetection(
    ObjectDetectionResult objectDetection,
  ) {
    // Filter objects for human labels (case-insensitive)
    final humanObjects = <DetectedObjectData>[];

    for (final obj in objectDetection.objects) {
      for (final label in obj.labels) {
        final labelLower = label.text.toLowerCase();
        if (config.humanLabels.contains(labelLower) &&
            label.confidence >= config.minHumanConfidence) {
          humanObjects.add(obj);
          break; // Object already identified as human
        }
      }
    }

    // Filter by minimum bounding box area
    final validHumans = humanObjects
        .where((obj) => obj.bounds.area >= config.minBoundingBoxArea)
        .toList();

    if (validHumans.isEmpty) {
      return HumanDetectionResult(
        humanDetected: false,
        humanCount: 0,
        detectionLatencyMs: objectDetection.detectionLatencyMs,
      );
    }

    // Sort by area (largest first) to find primary human
    validHumans.sort((a, b) => b.bounds.area.compareTo(a.bounds.area));
    final primary = validHumans.first;

    // Get the highest confidence for human labels
    double primaryConfidence = 0.0;
    for (final label in primary.labels) {
      final labelLower = label.text.toLowerCase();
      if (config.humanLabels.contains(labelLower) &&
          label.confidence > primaryConfidence) {
        primaryConfidence = label.confidence;
      }
    }

    return HumanDetectionResult(
      humanDetected: true,
      humanCount: validHumans.length,
      primaryHumanBounds: primary.bounds,
      primaryConfidence: primaryConfidence,
      detectionLatencyMs: objectDetection.detectionLatencyMs,
    );
  }

  /// Validate a detected pose using both object detection and biomechanical checks
  ///
  /// This is the main validation pipeline that produces the "Human-Only Signal".
  PoseValidationResult validatePose({
    required TimestampedPose pose,
    required HumanDetectionResult humanDetection,
  }) {
    // Gate 1: Human detection check
    bool passesHumanDetection = humanDetection.humanDetected;

    // Check for multiple humans if not allowed
    if (passesHumanDetection &&
        !config.allowMultipleHumans &&
        humanDetection.humanCount > 1) {
      passesHumanDetection = false;
    }

    // Check pose-human bounding box overlap
    if (passesHumanDetection && humanDetection.primaryHumanBounds != null) {
      final poseBounds = _calculatePoseBounds(pose);
      if (poseBounds != null) {
        final overlap = humanDetection.primaryHumanBounds!.iou(poseBounds);
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
          if (!sanityResult.failedChecks.contains(RejectionReason.suspectedHallucination))
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
    if (!humanDetection.humanDetected) return false;

    // If multiple humans not allowed, check count
    if (!config.allowMultipleHumans && humanDetection.humanCount > 1) {
      return false;
    }

    return true;
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
