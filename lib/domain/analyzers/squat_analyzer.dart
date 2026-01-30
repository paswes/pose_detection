import 'dart:math' as math;

import 'package:pose_detection/domain/analyzers/angle_calculator.dart';
import 'package:pose_detection/domain/analyzers/base_exercise_analyzer.dart';
import 'package:pose_detection/domain/analyzers/squat_phase.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/squat_metrics.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';
import 'package:pose_detection/domain/models/squat_session.dart';

/// Analyzes squat form from pose data
///
/// Detects squat phases, counts reps, and calculates form scores
/// based on knee tracking, trunk angle, and symmetry.
class SquatAnalyzer
    extends BaseExerciseAnalyzer<SquatMetrics, SquatRep, SquatSession> {
  // === Configuration Thresholds ===

  /// Knee angle above which we consider standing position
  static const double standingKneeAngle = 150.0;

  /// Knee angle at parallel squat position
  static const double parallelKneeAngle = 90.0;

  /// Minimum angle change to detect phase transition
  static const double phaseTransitionThreshold = 8.0;

  /// Number of frames to confirm bottom position (reduces noise)
  static const int bottomConfirmationFrames = 2;

  /// Target trunk angle (degrees from vertical) - typical squat form
  static const double idealTrunkAngle = 30.0;

  /// Maximum acceptable trunk angle deviation
  static const double maxTrunkAngleDeviation = 25.0;

  /// Maximum acceptable knee valgus before penalty
  static const double maxAcceptableValgus = 15.0;

  /// Maximum acceptable asymmetry before penalty
  static const double maxAcceptableAsymmetry = 20.0;

  // === State Tracking ===

  SquatPhase _currentPhase = SquatPhase.standing;
  int _repCount = 0;
  final List<SquatRep> _completedReps = [];
  DateTime _sessionStartTime = DateTime.now();

  // Current rep tracking
  int? _repStartFrameIndex;
  int? _repStartTimestampMicros;
  double _lowestKneeAngle = 180.0;
  double _maxTrunkAngle = 0.0;
  final List<double> _kneeValgusReadings = [];
  final List<double> _leftKneeAngles = [];
  final List<double> _rightKneeAngles = [];

  // Phase timing
  int? _descentStartMicros;
  int? _bottomStartMicros;
  int? _ascentStartMicros;
  int _bottomFrameCount = 0;

  // Previous frame data for comparison
  double? _previousKneeAngle;
  SquatPhase? _previousPhase;

  // Angle smoothing (simple moving average)
  final List<double> _kneeAngleHistory = [];
  static const int _smoothingWindow = 3;

  @override
  SquatMetrics analyzePose(TimestampedPose pose, SquatMetrics? previousMetrics) {
    // Calculate current angles
    final rawKneeAngle = AngleCalculator.calculateAverageKneeAngle(pose);
    final trunkAngle = AngleCalculator.calculateTrunkAngle(pose);
    final hipAngle = AngleCalculator.calculateAverageHipAngle(pose);
    final kneeValgus = AngleCalculator.calculateAverageKneeValgus(pose);
    final confidence = AngleCalculator.getSquatLandmarkConfidence(pose);

    // If we can't detect key landmarks, return previous metrics or initial
    if (rawKneeAngle == null || confidence == null || confidence < 0.5) {
      return previousMetrics ?? SquatMetrics.initial();
    }

    // Smooth the knee angle to reduce jitter
    final kneeAngle = _smoothAngle(rawKneeAngle);

    // Calculate symmetry
    final leftKnee = AngleCalculator.calculateKneeAngle(pose, isLeft: true);
    final rightKnee = AngleCalculator.calculateKneeAngle(pose, isLeft: false);
    final symmetryStatus = _calculateSymmetryStatus(leftKnee, rightKnee);

    // Detect phase transition
    final newPhase = _detectPhase(kneeAngle, pose.timestampMicros);

    // Handle phase transitions
    _handlePhaseTransition(newPhase, pose, kneeAngle);

    // Track rep data if in progress
    if (_repStartFrameIndex != null) {
      if (kneeAngle < _lowestKneeAngle) {
        _lowestKneeAngle = kneeAngle;
      }
      if (trunkAngle != null && trunkAngle > _maxTrunkAngle) {
        _maxTrunkAngle = trunkAngle;
      }
      if (kneeValgus != null) {
        _kneeValgusReadings.add(kneeValgus);
      }
      if (leftKnee != null) _leftKneeAngles.add(leftKnee);
      if (rightKnee != null) _rightKneeAngles.add(rightKnee);
    }

    // Calculate real-time form scores
    final kneeTrackingScore = _calculateKneeTrackingScore(kneeValgus);
    final trunkScore = _calculateTrunkScore(trunkAngle);
    final symmetryScore = _calculateSymmetryScore(leftKnee, rightKnee);
    final currentFormScore =
        _calculateOverallFormScore(kneeTrackingScore, trunkScore, symmetryScore);

    // Calculate depth percentage
    final depthPercentage = _calculateDepthPercentage(kneeAngle);

    // Calculate current rep duration
    Duration? currentRepDuration;
    if (_repStartTimestampMicros != null) {
      currentRepDuration = Duration(
        microseconds: pose.timestampMicros - _repStartTimestampMicros!,
      );
    }

    // Update state
    _previousKneeAngle = kneeAngle;
    _previousPhase = _currentPhase;
    _currentPhase = newPhase;

    // Build metrics
    return SquatMetrics(
      currentPhase: newPhase,
      currentKneeAngle: kneeAngle,
      currentTrunkAngle: trunkAngle ?? 0.0,
      currentHipAngle: hipAngle ?? 170.0,
      currentFormScore: currentFormScore,
      kneeTrackingStatus: kneeValgus ?? 0.0,
      symmetryStatus: symmetryStatus,
      currentDepthPercentage: depthPercentage,
      totalReps: _repCount,
      averageFormScore: _calculateAverageFormScore(),
      averageDepth: _calculateAverageDepth(),
      bestFormScore: _calculateBestFormScore(),
      deepestKneeAngle: _calculateDeepestKneeAngle(),
      currentRepDuration: currentRepDuration,
      averageRepDuration: _calculateAverageRepDuration(),
      landmarkConfidence: confidence,
    );
  }

  @override
  SquatRep? checkRepCompletion(
    SquatMetrics currentMetrics,
    SquatMetrics previousMetrics,
  ) {
    // Rep completes when transitioning from ascending to standing
    if (_previousPhase == SquatPhase.ascending &&
        currentMetrics.currentPhase == SquatPhase.standing &&
        _repStartFrameIndex != null) {
      return _completeRep(currentMetrics);
    }
    return null;
  }

  @override
  SquatSession getSessionSummary() {
    return SquatSession(
      startTime: _sessionStartTime,
      endTime: null,
      completedReps: List.unmodifiable(_completedReps),
      currentMetrics: SquatMetrics(
        currentPhase: _currentPhase,
        currentKneeAngle: _previousKneeAngle ?? 170.0,
        currentTrunkAngle: 0.0,
        currentHipAngle: 170.0,
        currentFormScore: 1.0,
        kneeTrackingStatus: 0.0,
        symmetryStatus: 1.0,
        currentDepthPercentage: 0.0,
        totalReps: _repCount,
        averageFormScore: _calculateAverageFormScore(),
        averageDepth: _calculateAverageDepth(),
        bestFormScore: _calculateBestFormScore(),
        deepestKneeAngle: _calculateDeepestKneeAngle(),
        currentRepDuration: null,
        averageRepDuration: _calculateAverageRepDuration(),
        landmarkConfidence: null,
      ),
    );
  }

  @override
  void reset() {
    _currentPhase = SquatPhase.standing;
    _repCount = 0;
    _completedReps.clear();
    _sessionStartTime = DateTime.now();
    _repStartFrameIndex = null;
    _repStartTimestampMicros = null;
    _lowestKneeAngle = 180.0;
    _maxTrunkAngle = 0.0;
    _kneeValgusReadings.clear();
    _leftKneeAngles.clear();
    _rightKneeAngles.clear();
    _descentStartMicros = null;
    _bottomStartMicros = null;
    _ascentStartMicros = null;
    _bottomFrameCount = 0;
    _previousKneeAngle = null;
    _previousPhase = null;
    _kneeAngleHistory.clear();
  }

  @override
  bool get isTrackingRep => _repStartFrameIndex != null;

  @override
  int get completedRepCount => _repCount;

  // === Private Methods ===

  /// Smooth angle using moving average to reduce noise
  double _smoothAngle(double rawAngle) {
    _kneeAngleHistory.add(rawAngle);
    if (_kneeAngleHistory.length > _smoothingWindow) {
      _kneeAngleHistory.removeAt(0);
    }

    return _kneeAngleHistory.reduce((a, b) => a + b) / _kneeAngleHistory.length;
  }

  /// Detect the current squat phase based on knee angle and movement
  SquatPhase _detectPhase(double kneeAngle, int timestampMicros) {
    // Standing: knee angle above threshold
    if (kneeAngle >= standingKneeAngle) {
      _bottomFrameCount = 0;
      return SquatPhase.standing;
    }

    // Get previous knee angle for direction detection
    if (_previousKneeAngle == null) {
      return SquatPhase.standing;
    }

    final angleChange = kneeAngle - _previousKneeAngle!;

    // Determine direction of movement
    switch (_currentPhase) {
      case SquatPhase.standing:
        // From standing, can only go to descending
        if (angleChange < -phaseTransitionThreshold) {
          _descentStartMicros = timestampMicros;
          return SquatPhase.descending;
        }
        return SquatPhase.standing;

      case SquatPhase.descending:
        // From descending, can go to bottom (stopped) or continue descending
        if (angleChange.abs() < phaseTransitionThreshold / 2) {
          _bottomFrameCount++;
          if (_bottomFrameCount >= bottomConfirmationFrames) {
            _bottomStartMicros = timestampMicros;
            return SquatPhase.bottom;
          }
        } else {
          _bottomFrameCount = 0;
        }

        if (angleChange > phaseTransitionThreshold) {
          _ascentStartMicros = timestampMicros;
          return SquatPhase.ascending;
        }
        return SquatPhase.descending;

      case SquatPhase.bottom:
        // From bottom, can only go to ascending
        if (angleChange > phaseTransitionThreshold) {
          _ascentStartMicros = timestampMicros;
          return SquatPhase.ascending;
        }
        return SquatPhase.bottom;

      case SquatPhase.ascending:
        // From ascending, can go to standing or back to descending
        if (kneeAngle >= standingKneeAngle) {
          return SquatPhase.standing;
        }
        if (angleChange < -phaseTransitionThreshold) {
          // Going back down - unusual but possible
          _descentStartMicros = timestampMicros;
          return SquatPhase.descending;
        }
        return SquatPhase.ascending;
    }
  }

  /// Handle phase transition events
  void _handlePhaseTransition(
    SquatPhase newPhase,
    TimestampedPose pose,
    double kneeAngle,
  ) {
    // Starting a new rep (standing -> descending)
    if (_currentPhase == SquatPhase.standing &&
        newPhase == SquatPhase.descending) {
      _startNewRep(pose);
    }
  }

  /// Start tracking a new rep
  void _startNewRep(TimestampedPose pose) {
    _repStartFrameIndex = pose.frameIndex;
    _repStartTimestampMicros = pose.timestampMicros;
    _lowestKneeAngle = 180.0;
    _maxTrunkAngle = 0.0;
    _kneeValgusReadings.clear();
    _leftKneeAngles.clear();
    _rightKneeAngles.clear();
    _descentStartMicros = pose.timestampMicros;
    _bottomStartMicros = null;
    _ascentStartMicros = null;
  }

  /// Complete the current rep and return the data
  SquatRep _completeRep(SquatMetrics metrics) {
    _repCount++;

    final endTimestamp = metrics.currentRepDuration != null
        ? _repStartTimestampMicros! + metrics.currentRepDuration!.inMicroseconds
        : _repStartTimestampMicros! + 1000000; // Fallback 1 second

    // Calculate phase durations
    final descentDuration = _bottomStartMicros != null && _descentStartMicros != null
        ? Duration(microseconds: _bottomStartMicros! - _descentStartMicros!)
        : const Duration(milliseconds: 500);

    final bottomDuration = _ascentStartMicros != null && _bottomStartMicros != null
        ? Duration(microseconds: _ascentStartMicros! - _bottomStartMicros!)
        : Duration.zero;

    final ascentDuration = _ascentStartMicros != null
        ? Duration(microseconds: endTimestamp - _ascentStartMicros!)
        : const Duration(milliseconds: 500);

    // Calculate average form scores for the rep
    final avgKneeValgus = _kneeValgusReadings.isNotEmpty
        ? _kneeValgusReadings.reduce((a, b) => a + b) / _kneeValgusReadings.length
        : 0.0;

    final kneeTrackingScore = _calculateKneeTrackingScore(avgKneeValgus);
    final trunkScore = _calculateTrunkScore(_maxTrunkAngle);
    final symmetryScore = _calculateRepSymmetryScore();
    final overallFormScore =
        _calculateOverallFormScore(kneeTrackingScore, trunkScore, symmetryScore);

    // Calculate depth
    final depthPercentage = _calculateDepthPercentage(_lowestKneeAngle);
    final reachedParallel = _lowestKneeAngle <= parallelKneeAngle;

    final rep = SquatRep(
      repNumber: _repCount,
      startFrameIndex: _repStartFrameIndex!,
      endFrameIndex: metrics.currentPhase == SquatPhase.standing
          ? _repStartFrameIndex! + 30 // Estimate
          : _repStartFrameIndex! + 30,
      startTimestampMicros: _repStartTimestampMicros!,
      endTimestampMicros: endTimestamp,
      lowestKneeAngle: _lowestKneeAngle,
      depthPercentage: depthPercentage,
      reachedParallel: reachedParallel,
      descentDuration: descentDuration,
      bottomDuration: bottomDuration,
      ascentDuration: ascentDuration,
      kneeTrackingScore: kneeTrackingScore,
      trunkAngleScore: trunkScore,
      symmetryScore: symmetryScore,
      overallFormScore: overallFormScore,
      maxTrunkAngle: _maxTrunkAngle,
      avgKneeValgusAngle: avgKneeValgus,
      phaseDurations: {
        SquatPhase.descending: descentDuration,
        SquatPhase.bottom: bottomDuration,
        SquatPhase.ascending: ascentDuration,
      },
    );

    _completedReps.add(rep);

    // Reset rep tracking
    _repStartFrameIndex = null;
    _repStartTimestampMicros = null;

    return rep;
  }

  /// Calculate knee tracking score (0-1)
  double _calculateKneeTrackingScore(double? valgus) {
    if (valgus == null) return 1.0;

    final absValgus = valgus.abs();
    return (1.0 - (absValgus / maxAcceptableValgus)).clamp(0.0, 1.0);
  }

  /// Calculate trunk angle score (0-1)
  double _calculateTrunkScore(double? trunkAngle) {
    if (trunkAngle == null) return 1.0;

    final deviation = (trunkAngle - idealTrunkAngle).abs();
    return (1.0 - (deviation / maxTrunkAngleDeviation)).clamp(0.0, 1.0);
  }

  /// Calculate symmetry score (0-1)
  double _calculateSymmetryScore(double? leftKnee, double? rightKnee) {
    if (leftKnee == null || rightKnee == null) return 1.0;

    final asymmetry = (leftKnee - rightKnee).abs();
    return (1.0 - (asymmetry / maxAcceptableAsymmetry)).clamp(0.0, 1.0);
  }

  /// Calculate symmetry score for a completed rep using stored readings
  double _calculateRepSymmetryScore() {
    if (_leftKneeAngles.isEmpty || _rightKneeAngles.isEmpty) return 1.0;

    final length = math.min(_leftKneeAngles.length, _rightKneeAngles.length);
    var totalAsymmetry = 0.0;

    for (var i = 0; i < length; i++) {
      totalAsymmetry += (_leftKneeAngles[i] - _rightKneeAngles[i]).abs();
    }

    final avgAsymmetry = totalAsymmetry / length;
    return (1.0 - (avgAsymmetry / maxAcceptableAsymmetry)).clamp(0.0, 1.0);
  }

  /// Calculate symmetry status for display (-1 to 1)
  double _calculateSymmetryStatus(double? leftKnee, double? rightKnee) {
    if (leftKnee == null || rightKnee == null) return 1.0;

    final asymmetry = (leftKnee - rightKnee).abs();
    return (1.0 - (asymmetry / maxAcceptableAsymmetry)).clamp(0.0, 1.0);
  }

  /// Calculate overall form score with weights
  double _calculateOverallFormScore(
    double kneeTracking,
    double trunk,
    double symmetry,
  ) {
    // Weights: knee tracking 40%, trunk 30%, symmetry 30%
    return (kneeTracking * 0.4) + (trunk * 0.3) + (symmetry * 0.3);
  }

  /// Calculate depth percentage (0-100+)
  double _calculateDepthPercentage(double kneeAngle) {
    // Standing (170°) = 0%, Parallel (90°) = 100%
    final range = standingKneeAngle - parallelKneeAngle; // 60°
    final depth = standingKneeAngle - kneeAngle;
    return (depth / range * 100).clamp(0.0, 150.0);
  }

  /// Calculate average form score across completed reps
  double _calculateAverageFormScore() {
    if (_completedReps.isEmpty) return 0.0;
    return _completedReps.fold<double>(
          0.0,
          (sum, rep) => sum + rep.overallFormScore,
        ) /
        _completedReps.length;
  }

  /// Calculate average depth across completed reps
  double _calculateAverageDepth() {
    if (_completedReps.isEmpty) return 0.0;
    return _completedReps.fold<double>(
          0.0,
          (sum, rep) => sum + rep.depthPercentage,
        ) /
        _completedReps.length;
  }

  /// Calculate best form score across completed reps
  double _calculateBestFormScore() {
    if (_completedReps.isEmpty) return 0.0;
    return _completedReps.fold<double>(
      0.0,
      (best, rep) => rep.overallFormScore > best ? rep.overallFormScore : best,
    );
  }

  /// Calculate deepest knee angle across completed reps
  double _calculateDeepestKneeAngle() {
    if (_completedReps.isEmpty) return 170.0;
    return _completedReps.fold<double>(
      170.0,
      (deepest, rep) =>
          rep.lowestKneeAngle < deepest ? rep.lowestKneeAngle : deepest,
    );
  }

  /// Calculate average rep duration
  Duration? _calculateAverageRepDuration() {
    if (_completedReps.isEmpty) return null;
    final totalMicros = _completedReps.fold<int>(
      0,
      (sum, rep) => sum + rep.totalDuration.inMicroseconds,
    );
    return Duration(microseconds: totalMicros ~/ _completedReps.length);
  }
}
