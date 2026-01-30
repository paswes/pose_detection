import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/squat_metrics.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';
import 'package:pose_detection/domain/models/squat_session.dart';

/// Base class for squat analysis states
abstract class SquatAnalysisState extends Equatable {
  const SquatAnalysisState();

  @override
  List<Object?> get props => [];
}

/// Initial state before analysis starts
class SquatAnalysisInitial extends SquatAnalysisState {
  const SquatAnalysisInitial();
}

/// State during active squat analysis
class SquatAnalyzing extends SquatAnalysisState {
  /// Current real-time metrics
  final SquatMetrics currentMetrics;

  /// Current session data including completed reps
  final SquatSession session;

  /// Last completed rep (for triggering UI animations)
  /// Only non-null on the frame when a rep completes
  final SquatRep? lastCompletedRep;

  const SquatAnalyzing({
    required this.currentMetrics,
    required this.session,
    this.lastCompletedRep,
  });

  @override
  List<Object?> get props => [
        currentMetrics.currentPhase,
        currentMetrics.currentKneeAngle,
        currentMetrics.totalReps,
        session.totalReps,
        lastCompletedRep?.repNumber,
      ];

  /// Create a copy with updated values
  SquatAnalyzing copyWith({
    SquatMetrics? currentMetrics,
    SquatSession? session,
    SquatRep? lastCompletedRep,
    bool clearLastRep = false,
  }) {
    return SquatAnalyzing(
      currentMetrics: currentMetrics ?? this.currentMetrics,
      session: session ?? this.session,
      lastCompletedRep: clearLastRep ? null : (lastCompletedRep ?? this.lastCompletedRep),
    );
  }
}

/// State when analysis is complete (session ended)
class SquatAnalysisCompleted extends SquatAnalysisState {
  /// Final session data with all reps
  final SquatSession finalSession;

  const SquatAnalysisCompleted({required this.finalSession});

  @override
  List<Object?> get props => [
        finalSession.totalReps,
        finalSession.overallFormScore,
        finalSession.endTime,
      ];
}

/// Error state
class SquatAnalysisError extends SquatAnalysisState {
  final String message;

  const SquatAnalysisError(this.message);

  @override
  List<Object?> get props => [message];
}
