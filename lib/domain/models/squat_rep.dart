import 'package:pose_detection/domain/analyzers/squat_phase.dart';

/// Represents a single completed squat repetition with form analysis data
class SquatRep {
  /// Sequential rep number in the session (1-indexed)
  final int repNumber;

  /// Frame index when the rep started (descending began)
  final int startFrameIndex;

  /// Frame index when the rep ended (returned to standing)
  final int endFrameIndex;

  /// Timestamp when the rep started (microseconds)
  final int startTimestampMicros;

  /// Timestamp when the rep ended (microseconds)
  final int endTimestampMicros;

  // === Depth Metrics ===

  /// Lowest knee angle achieved during the rep (lower = deeper squat)
  /// Standing is ~170°, parallel is ~90°, deep squat is <90°
  final double lowestKneeAngle;

  /// Depth as a percentage (0-100%)
  /// 0% = standing, 100% = parallel or below
  final double depthPercentage;

  /// Whether the squat reached parallel (hip crease at or below knee level)
  final bool reachedParallel;

  // === Timing Metrics ===

  /// Duration of the descent phase
  final Duration descentDuration;

  /// Duration at the bottom position (pause time)
  final Duration bottomDuration;

  /// Duration of the ascent phase
  final Duration ascentDuration;

  /// Total duration of the rep
  Duration get totalDuration => Duration(
        microseconds: endTimestampMicros - startTimestampMicros,
      );

  // === Form Scores (0.0 to 1.0) ===

  /// Knee tracking score - penalizes knee valgus (cave in)
  /// 1.0 = perfect tracking, 0.0 = severe valgus
  final double kneeTrackingScore;

  /// Trunk angle score - penalizes excessive forward lean
  /// 1.0 = ideal lean angle, 0.0 = too upright or too forward
  final double trunkAngleScore;

  /// Symmetry score - compares left/right side movement
  /// 1.0 = perfect symmetry, 0.0 = significant asymmetry
  final double symmetryScore;

  /// Overall form score (weighted composite)
  /// Weights: knee tracking 40%, trunk 30%, symmetry 30%
  final double overallFormScore;

  // === Raw Angle Data ===

  /// Most forward trunk lean angle during the rep (degrees from vertical)
  final double maxTrunkAngle;

  /// Average knee valgus angle during descent and ascent (degrees)
  /// Positive = valgus (knee cave), negative = varus
  final double avgKneeValgusAngle;

  /// Time spent in each phase
  final Map<SquatPhase, Duration> phaseDurations;

  const SquatRep({
    required this.repNumber,
    required this.startFrameIndex,
    required this.endFrameIndex,
    required this.startTimestampMicros,
    required this.endTimestampMicros,
    required this.lowestKneeAngle,
    required this.depthPercentage,
    required this.reachedParallel,
    required this.descentDuration,
    required this.bottomDuration,
    required this.ascentDuration,
    required this.kneeTrackingScore,
    required this.trunkAngleScore,
    required this.symmetryScore,
    required this.overallFormScore,
    required this.maxTrunkAngle,
    required this.avgKneeValgusAngle,
    required this.phaseDurations,
  });

  /// Create a copy with updated values
  SquatRep copyWith({
    int? repNumber,
    int? startFrameIndex,
    int? endFrameIndex,
    int? startTimestampMicros,
    int? endTimestampMicros,
    double? lowestKneeAngle,
    double? depthPercentage,
    bool? reachedParallel,
    Duration? descentDuration,
    Duration? bottomDuration,
    Duration? ascentDuration,
    double? kneeTrackingScore,
    double? trunkAngleScore,
    double? symmetryScore,
    double? overallFormScore,
    double? maxTrunkAngle,
    double? avgKneeValgusAngle,
    Map<SquatPhase, Duration>? phaseDurations,
  }) {
    return SquatRep(
      repNumber: repNumber ?? this.repNumber,
      startFrameIndex: startFrameIndex ?? this.startFrameIndex,
      endFrameIndex: endFrameIndex ?? this.endFrameIndex,
      startTimestampMicros: startTimestampMicros ?? this.startTimestampMicros,
      endTimestampMicros: endTimestampMicros ?? this.endTimestampMicros,
      lowestKneeAngle: lowestKneeAngle ?? this.lowestKneeAngle,
      depthPercentage: depthPercentage ?? this.depthPercentage,
      reachedParallel: reachedParallel ?? this.reachedParallel,
      descentDuration: descentDuration ?? this.descentDuration,
      bottomDuration: bottomDuration ?? this.bottomDuration,
      ascentDuration: ascentDuration ?? this.ascentDuration,
      kneeTrackingScore: kneeTrackingScore ?? this.kneeTrackingScore,
      trunkAngleScore: trunkAngleScore ?? this.trunkAngleScore,
      symmetryScore: symmetryScore ?? this.symmetryScore,
      overallFormScore: overallFormScore ?? this.overallFormScore,
      maxTrunkAngle: maxTrunkAngle ?? this.maxTrunkAngle,
      avgKneeValgusAngle: avgKneeValgusAngle ?? this.avgKneeValgusAngle,
      phaseDurations: phaseDurations ?? this.phaseDurations,
    );
  }

  /// Get a human-readable depth description
  String get depthDescription {
    if (lowestKneeAngle < 70) return 'Deep';
    if (lowestKneeAngle < 90) return 'Below Parallel';
    if (lowestKneeAngle < 100) return 'Parallel';
    if (lowestKneeAngle < 120) return 'Above Parallel';
    return 'Partial';
  }

  /// Get a grade for the form score
  String get formGrade {
    if (overallFormScore >= 0.9) return 'A';
    if (overallFormScore >= 0.8) return 'B';
    if (overallFormScore >= 0.7) return 'C';
    if (overallFormScore >= 0.6) return 'D';
    return 'F';
  }

  @override
  String toString() =>
      'SquatRep(#$repNumber, form: ${(overallFormScore * 100).toStringAsFixed(0)}%, '
      'depth: ${depthPercentage.toStringAsFixed(0)}%, '
      'duration: ${totalDuration.inMilliseconds}ms)';
}
