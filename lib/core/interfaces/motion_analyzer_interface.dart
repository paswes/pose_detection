import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/motion_metrics.dart';
import 'package:pose_detection/domain/models/body_region.dart';

/// Unified facade for motion analysis
/// Orchestrates angle calculation, velocity tracking, and body region analysis
abstract class IMotionAnalyzer {
  /// Analyze a single pose and return motion metrics
  /// Velocity will be empty without pose history
  MotionMetrics analyzeCurrentPose(TimestampedPose pose);

  /// Analyze with temporal context (for velocity calculations)
  /// [recentHistory] should contain recent poses BEFORE currentPose
  MotionMetrics analyzeWithHistory(
    TimestampedPose currentPose,
    List<TimestampedPose> recentHistory,
  );

  /// Get body region breakdown for a pose
  BodyRegionBreakdown getBodyRegions(TimestampedPose pose);
}
