import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Base class for squat analysis events
abstract class SquatAnalysisEvent extends Equatable {
  const SquatAnalysisEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start squat analysis
/// This should be dispatched when the user starts a squat session
class StartSquatAnalysisEvent extends SquatAnalysisEvent {
  const StartSquatAnalysisEvent();
}

/// Event to analyze a new pose frame
/// Dispatched for each frame from the pose detection stream
class AnalyzePoseEvent extends SquatAnalysisEvent {
  final TimestampedPose pose;

  const AnalyzePoseEvent(this.pose);

  @override
  List<Object?> get props => [pose.frameIndex, pose.timestampMicros];
}

/// Event to stop squat analysis
/// Dispatched when the user stops the session
class StopSquatAnalysisEvent extends SquatAnalysisEvent {
  const StopSquatAnalysisEvent();
}

/// Event to reset the analyzer for a new session
class ResetSquatAnalysisEvent extends SquatAnalysisEvent {
  const ResetSquatAnalysisEvent();
}
