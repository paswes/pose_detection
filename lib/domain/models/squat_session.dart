import 'package:pose_detection/domain/models/squat_metrics.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';

/// Complete squat session data with all reps and aggregate statistics
class SquatSession {
  /// Session start time
  final DateTime startTime;

  /// Session end time (null if session is still active)
  final DateTime? endTime;

  /// List of all completed reps in order
  final List<SquatRep> completedReps;

  /// Current real-time metrics (last known state)
  final SquatMetrics currentMetrics;

  const SquatSession({
    required this.startTime,
    this.endTime,
    required this.completedReps,
    required this.currentMetrics,
  });

  /// Create an initial empty session
  factory SquatSession.start() {
    return SquatSession(
      startTime: DateTime.now(),
      endTime: null,
      completedReps: const [],
      currentMetrics: SquatMetrics.initial(),
    );
  }

  /// Create a copy with updated values
  SquatSession copyWith({
    DateTime? startTime,
    DateTime? endTime,
    List<SquatRep>? completedReps,
    SquatMetrics? currentMetrics,
  }) {
    return SquatSession(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      completedReps: completedReps ?? this.completedReps,
      currentMetrics: currentMetrics ?? this.currentMetrics,
    );
  }

  /// Add a completed rep to the session
  SquatSession withCompletedRep(SquatRep rep) {
    return copyWith(
      completedReps: [...completedReps, rep],
    );
  }

  /// End the session
  SquatSession finish() {
    return copyWith(endTime: DateTime.now());
  }

  // === Computed Session Statistics ===

  /// Whether the session is still active
  bool get isActive => endTime == null;

  /// Total number of completed reps
  int get totalReps => completedReps.length;

  /// Total session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Total active time (sum of all rep durations)
  Duration get totalActiveTime {
    if (completedReps.isEmpty) return Duration.zero;

    return completedReps.fold(
      Duration.zero,
      (total, rep) => total + rep.totalDuration,
    );
  }

  /// Average rest time between reps
  Duration? get averageRestTime {
    if (completedReps.length < 2) return null;

    var totalRest = Duration.zero;
    for (var i = 1; i < completedReps.length; i++) {
      final restMicros = completedReps[i].startTimestampMicros -
          completedReps[i - 1].endTimestampMicros;
      totalRest += Duration(microseconds: restMicros);
    }

    return Duration(
      microseconds: totalRest.inMicroseconds ~/ (completedReps.length - 1),
    );
  }

  /// Overall form score (weighted average of all reps)
  double get overallFormScore {
    if (completedReps.isEmpty) return 0.0;

    final total = completedReps.fold<double>(
      0.0,
      (sum, rep) => sum + rep.overallFormScore,
    );
    return total / completedReps.length;
  }

  /// Consistency score - how consistent the form is across reps
  /// Based on standard deviation of form scores
  /// 1.0 = perfectly consistent, lower = more variation
  double get consistencyScore {
    if (completedReps.length < 2) return 1.0;

    final mean = overallFormScore;
    final variance = completedReps.fold<double>(
      0.0,
      (sum, rep) => sum + (rep.overallFormScore - mean) * (rep.overallFormScore - mean),
    ) / completedReps.length;

    final stdDev = variance > 0 ? variance * variance : 0.0;

    // Convert standard deviation to a 0-1 score
    // stdDev of 0.1 (10% variation) maps to score of 0.5
    return (1.0 - (stdDev * 5)).clamp(0.0, 1.0);
  }

  /// Average depth percentage across all reps
  double get averageDepth {
    if (completedReps.isEmpty) return 0.0;

    final total = completedReps.fold<double>(
      0.0,
      (sum, rep) => sum + rep.depthPercentage,
    );
    return total / completedReps.length;
  }

  /// Best form score achieved
  double get bestFormScore {
    if (completedReps.isEmpty) return 0.0;

    return completedReps.fold<double>(
      0.0,
      (best, rep) => rep.overallFormScore > best ? rep.overallFormScore : best,
    );
  }

  /// Best rep (highest form score)
  SquatRep? get bestRep {
    if (completedReps.isEmpty) return null;

    return completedReps.reduce(
      (best, rep) => rep.overallFormScore > best.overallFormScore ? rep : best,
    );
  }

  /// Deepest knee angle achieved (lowest value)
  double get deepestKneeAngle {
    if (completedReps.isEmpty) return 170.0;

    return completedReps.fold<double>(
      170.0,
      (deepest, rep) =>
          rep.lowestKneeAngle < deepest ? rep.lowestKneeAngle : deepest,
    );
  }

  /// Average rep duration
  Duration? get averageRepDuration {
    if (completedReps.isEmpty) return null;

    final totalMicros = completedReps.fold<int>(
      0,
      (sum, rep) => sum + rep.totalDuration.inMicroseconds,
    );
    return Duration(microseconds: totalMicros ~/ completedReps.length);
  }

  /// Form score trend (list of form scores per rep for charting)
  List<double> get formScoreTrend {
    return completedReps.map((rep) => rep.overallFormScore).toList();
  }

  /// Depth trend (list of depth percentages per rep for charting)
  List<double> get depthTrend {
    return completedReps.map((rep) => rep.depthPercentage).toList();
  }

  /// Number of reps that reached parallel or below
  int get repsAtParallel {
    return completedReps.where((rep) => rep.reachedParallel).length;
  }

  /// Percentage of reps that reached parallel
  double get parallelPercentage {
    if (completedReps.isEmpty) return 0.0;
    return repsAtParallel / completedReps.length * 100;
  }

  @override
  String toString() =>
      'SquatSession(reps: $totalReps, form: ${(overallFormScore * 100).toStringAsFixed(0)}%, '
      'duration: ${duration.inSeconds}s, active: $isActive)';
}
