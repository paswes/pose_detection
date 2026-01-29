Human Pose Validation Solution - Summary

I've implemented a comprehensive human pose validation system that filters out
false positive detections from ML Kit. Here's what was created:

Architecture

domain/validation/ ├── pose_validation_result.dart # Result models with detailed
check breakdown ├── pose_landmark_ids.dart # Type-safe landmark ID constants &
bone segments ├── human_pose_validator.dart # Core validation logic with 6
checks └── validation.dart # Barrel export

Key Design Decision: The validator lives in the domain layer as a pure business
logic component. It's injected into the BLoC (presentation layer) for
orchestration, keeping the core service agnostic.

Validation Strategy (6 Checks)

1. Landmark Confidence - Ensures key landmarks (shoulders, hips, nose) have
   sufficient ML confidence (≥50%)
2. Core Body Presence - Verifies the fundamental torso structure (4 corners:
   shoulders + hips) with at least 3 visible
3. Body Proportions - Validates anatomical ratios: - Shoulder-to-hip width ratio
   (0.7-2.0) - Upper arm to forearm ratio (0.6-1.6) - Thigh to shin ratio
   (0.7-1.5) - Lateral symmetry (≤40% asymmetry)
4. Skeletal Connectivity - Ensures connected body parts are actually near each
   other (not scattered points)
5. Spatial Coherence - Validates vertical ordering (head above shoulders above
   hips) and horizontal separation
6. Temporal Consistency - Tracks poses across frames to detect "teleporting"
   (max 15% screen movement per frame)

Performance Considerations

- All checks use only pose landmarks (no additional ML models)
- Lightweight math operations (distance calculations, ratio comparisons)
- Temporal window of 5 frames for consistency tracking
- Validation adds minimal overhead to the existing pipeline

Integration Points

BLoC (pose_detection_bloc.dart):

- Validator injected via constructor (configurable)
- Validates each detected pose before storing
- Only valid poses are added to the session's ring buffer
- Invalid poses still emitted for UI feedback (shown in red)

SessionMetrics:

- New fields: totalValidatedPoses, totalRejectedPoses,
  averageValidationConfidence
- New properties: rejectionRate, validationPassRate

UI:

- PosePainter shows valid poses in cyan, invalid in red
- Top bar displays "Valid" and "Rejected" counts
- Validation indicator shows status + rejection reason

Configuration

// Default (balanced) HumanPoseValidatorConfig()

// Strict (fewer false positives, may miss some valid poses)
HumanPoseValidatorConfig.strict()

// Lenient (more permissive, catches more valid poses)
HumanPoseValidatorConfig.lenient()

// Or customize individual thresholds: HumanPoseValidatorConfig(
minHighPriorityConfidence: 0.6, validationThreshold: 0.7, maxFrameMovement:
0.10, )

Files Modified

- lib/domain/models/session_metrics.dart - Added validation metrics
- lib/presentation/bloc/pose_detection_bloc.dart - Integrated validator
- lib/presentation/bloc/pose_detection_state.dart - Added validation result to
  Detecting state
- lib/presentation/pages/capture_page.dart - Added validation UI indicators
- lib/presentation/widgets/pose_painter.dart - Color-coded valid/invalid poses

Files Created

- lib/domain/validation/pose_validation_result.dart
- lib/domain/validation/pose_landmark_ids.dart
- lib/domain/validation/human_pose_validator.dart
- lib/domain/validation/validation.dart
