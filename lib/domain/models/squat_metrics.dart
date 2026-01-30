import 'package:pose_detection/domain/analyzers/squat_phase.dart';

/// Real-time metrics for squat analysis during capture
/// Updated every frame with current pose data
class SquatMetrics {
  // === Current State ===

  /// Current phase of the squat movement
  final SquatPhase currentPhase;

  /// Current knee angle (average of left and right)
  /// Standing ~170°, parallel ~90°
  final double currentKneeAngle;

  /// Current trunk angle relative to vertical (degrees)
  /// 0° = upright, positive = forward lean
  final double currentTrunkAngle;

  /// Current hip angle (average of left and right)
  final double currentHipAngle;

  // === Real-time Form Indicators ===

  /// Running form score for the current rep (0.0 to 1.0)
  /// Updated continuously during the rep
  final double currentFormScore;

  /// Current knee tracking status (-1 to 1)
  /// Negative = valgus (knees caving in)
  /// Positive = varus (knees bowing out)
  /// Zero = tracking well over toes
  final double kneeTrackingStatus;

  /// Current symmetry status (0.0 to 1.0)
  /// 1.0 = perfect symmetry between left and right
  final double symmetryStatus;

  /// Current depth as percentage toward parallel (0-100+)
  /// 0% = standing, 100% = parallel, >100% = below parallel
  final double currentDepthPercentage;

  // === Session Aggregates ===

  /// Total completed reps in this session
  final int totalReps;

  /// Average form score across all completed reps
  final double averageFormScore;

  /// Average depth percentage across all completed reps
  final double averageDepth;

  /// Best (highest) form score achieved in any rep
  final double bestFormScore;

  /// Deepest rep (lowest knee angle achieved)
  final double deepestKneeAngle;

  // === Timing ===

  /// Duration of the current rep so far (if in progress)
  final Duration? currentRepDuration;

  /// Average rep duration across completed reps
  final Duration? averageRepDuration;

  /// Minimum confidence of key squat landmarks (0.0 to 1.0)
  /// null if landmarks are missing
  final double? landmarkConfidence;

  const SquatMetrics({
    required this.currentPhase,
    required this.currentKneeAngle,
    required this.currentTrunkAngle,
    required this.currentHipAngle,
    required this.currentFormScore,
    required this.kneeTrackingStatus,
    required this.symmetryStatus,
    required this.currentDepthPercentage,
    required this.totalReps,
    required this.averageFormScore,
    required this.averageDepth,
    required this.bestFormScore,
    required this.deepestKneeAngle,
    this.currentRepDuration,
    this.averageRepDuration,
    this.landmarkConfidence,
  });

  /// Create initial metrics with default values
  factory SquatMetrics.initial() {
    return const SquatMetrics(
      currentPhase: SquatPhase.standing,
      currentKneeAngle: 170.0,
      currentTrunkAngle: 0.0,
      currentHipAngle: 170.0,
      currentFormScore: 1.0,
      kneeTrackingStatus: 0.0,
      symmetryStatus: 1.0,
      currentDepthPercentage: 0.0,
      totalReps: 0,
      averageFormScore: 0.0,
      averageDepth: 0.0,
      bestFormScore: 0.0,
      deepestKneeAngle: 170.0,
      currentRepDuration: null,
      averageRepDuration: null,
      landmarkConfidence: null,
    );
  }

  /// Create a copy with updated values
  SquatMetrics copyWith({
    SquatPhase? currentPhase,
    double? currentKneeAngle,
    double? currentTrunkAngle,
    double? currentHipAngle,
    double? currentFormScore,
    double? kneeTrackingStatus,
    double? symmetryStatus,
    double? currentDepthPercentage,
    int? totalReps,
    double? averageFormScore,
    double? averageDepth,
    double? bestFormScore,
    double? deepestKneeAngle,
    Duration? currentRepDuration,
    Duration? averageRepDuration,
    double? landmarkConfidence,
  }) {
    return SquatMetrics(
      currentPhase: currentPhase ?? this.currentPhase,
      currentKneeAngle: currentKneeAngle ?? this.currentKneeAngle,
      currentTrunkAngle: currentTrunkAngle ?? this.currentTrunkAngle,
      currentHipAngle: currentHipAngle ?? this.currentHipAngle,
      currentFormScore: currentFormScore ?? this.currentFormScore,
      kneeTrackingStatus: kneeTrackingStatus ?? this.kneeTrackingStatus,
      symmetryStatus: symmetryStatus ?? this.symmetryStatus,
      currentDepthPercentage:
          currentDepthPercentage ?? this.currentDepthPercentage,
      totalReps: totalReps ?? this.totalReps,
      averageFormScore: averageFormScore ?? this.averageFormScore,
      averageDepth: averageDepth ?? this.averageDepth,
      bestFormScore: bestFormScore ?? this.bestFormScore,
      deepestKneeAngle: deepestKneeAngle ?? this.deepestKneeAngle,
      currentRepDuration: currentRepDuration ?? this.currentRepDuration,
      averageRepDuration: averageRepDuration ?? this.averageRepDuration,
      landmarkConfidence: landmarkConfidence ?? this.landmarkConfidence,
    );
  }

  /// Whether the current phase is active movement (descending or ascending)
  bool get isMoving => currentPhase.isActive;

  /// Whether currently at the bottom of a squat
  bool get isAtBottom => currentPhase.isBottom;

  /// Whether currently in a rep (not standing)
  bool get isInRep => currentPhase != SquatPhase.standing;

  /// Human-readable depth description
  String get depthDescription {
    if (currentKneeAngle >= 160) return 'Standing';
    if (currentKneeAngle >= 120) return 'Quarter Squat';
    if (currentKneeAngle >= 100) return 'Half Squat';
    if (currentKneeAngle >= 90) return 'Parallel';
    return 'Below Parallel';
  }

  /// Human-readable knee tracking feedback
  String get kneeTrackingFeedback {
    if (kneeTrackingStatus < -5) return 'Knees caving in!';
    if (kneeTrackingStatus < -2) return 'Watch your knees';
    if (kneeTrackingStatus > 5) return 'Knees too wide';
    if (kneeTrackingStatus > 2) return 'Knees slightly wide';
    return 'Good tracking';
  }

  @override
  String toString() =>
      'SquatMetrics(phase: ${currentPhase.displayName}, '
      'knee: ${currentKneeAngle.toStringAsFixed(1)}°, '
      'reps: $totalReps, form: ${(currentFormScore * 100).toStringAsFixed(0)}%)';
}
