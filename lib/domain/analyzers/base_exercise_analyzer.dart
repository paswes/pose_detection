import 'package:pose_detection/domain/models/motion_data.dart';

/// Abstract base class for exercise analyzers
///
/// This interface enables extensibility for different exercise types
/// (squats, deadlifts, lunges, etc.) while maintaining a consistent
/// analysis pattern.
///
/// Type parameters:
/// - [TMetrics]: Real-time metrics type (e.g., SquatMetrics)
/// - [TRep]: Single rep data type (e.g., SquatRep)
/// - [TSession]: Complete session type (e.g., SquatSession)
abstract class BaseExerciseAnalyzer<TMetrics, TRep, TSession> {
  /// Process a new pose frame and return updated metrics
  ///
  /// [pose] - The new pose data to analyze
  /// [previousMetrics] - Metrics from the previous frame (null for first frame)
  ///
  /// Returns the updated metrics for this frame
  TMetrics analyzePose(TimestampedPose pose, TMetrics? previousMetrics);

  /// Check if a rep was completed between the previous and current metrics
  ///
  /// [currentMetrics] - Metrics from the current frame
  /// [previousMetrics] - Metrics from the previous frame
  ///
  /// Returns the completed rep data if a rep was finished, null otherwise
  TRep? checkRepCompletion(TMetrics currentMetrics, TMetrics previousMetrics);

  /// Get the current session summary including all completed reps
  TSession getSessionSummary();

  /// Reset the analyzer state for a new session
  void reset();

  /// Whether the analyzer is currently tracking an active rep
  bool get isTrackingRep;

  /// The number of completed reps in the current session
  int get completedRepCount;
}
