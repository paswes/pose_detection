import 'package:pose_detection/core/config/inspection_config.dart';
import 'package:pose_detection/core/interfaces/angle_calculator_interface.dart';
import 'package:pose_detection/core/interfaces/velocity_tracker_interface.dart';
import 'package:pose_detection/core/interfaces/motion_analyzer_interface.dart';
import 'package:pose_detection/core/services/angle_calculator.dart';
import 'package:pose_detection/core/services/velocity_tracker.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/motion_metrics.dart';
import 'package:pose_detection/domain/models/body_region.dart';

/// Orchestrates motion analysis by combining angle calculator and velocity tracker
class MotionAnalyzer implements IMotionAnalyzer {
  final IAngleCalculator _angleCalculator;
  final IVelocityTracker _velocityTracker;
  final InspectionConfig _config;

  /// Body region landmark indices based on ML Kit 33-landmark schema
  /// Head: 0-10 (nose, eyes, ears, mouth)
  static const _headIndices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  /// Upper body: 11-22 (shoulders, elbows, wrists, hands)
  static const _upperIndices = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];

  /// Core: shoulders + hips (torso frame)
  static const _coreIndices = [11, 12, 23, 24];

  /// Lower body: 23-32 (hips, knees, ankles, feet)
  static const _lowerIndices = [23, 24, 25, 26, 27, 28, 29, 30, 31, 32];

  MotionAnalyzer({
    IAngleCalculator? angleCalculator,
    IVelocityTracker? velocityTracker,
    InspectionConfig? config,
  })  : _angleCalculator = angleCalculator ?? AngleCalculator(),
        _velocityTracker = velocityTracker ?? VelocityTracker(),
        _config = config ?? InspectionConfig.defaultConfig;

  @override
  MotionMetrics analyzeCurrentPose(TimestampedPose pose) {
    return MotionMetrics(
      jointAngles: _angleCalculator.calculateAllAngles(pose),
      velocities: [], // No velocity without history
      bodyRegions: getBodyRegions(pose),
      overallConfidence: pose.avgConfidence,
      timestampMicros: pose.timestampMicros,
    );
  }

  @override
  MotionMetrics analyzeWithHistory(
    TimestampedPose currentPose,
    List<TimestampedPose> recentHistory,
  ) {
    final angles = _angleCalculator.calculateAllAngles(currentPose);

    // Add current pose to history for velocity calculation
    final fullHistory = [...recentHistory, currentPose];
    final velocities = _velocityTracker.getSmoothedVelocities(
      fullHistory,
      _config.velocitySmoothingFrames,
    );

    return MotionMetrics(
      jointAngles: angles,
      velocities: velocities,
      bodyRegions: getBodyRegions(currentPose),
      overallConfidence: currentPose.avgConfidence,
      timestampMicros: currentPose.timestampMicros,
    );
  }

  @override
  BodyRegionBreakdown getBodyRegions(TimestampedPose pose) {
    final landmarks = pose.normalizedLandmarks;

    return BodyRegionBreakdown(
      head: BodyRegion(
        name: 'Head',
        confidence: _avgConfidence(landmarks, _headIndices),
        landmarkIndices: _headIndices,
      ),
      upperBody: BodyRegion(
        name: 'Upper Body',
        confidence: _avgConfidence(landmarks, _upperIndices),
        landmarkIndices: _upperIndices,
      ),
      core: BodyRegion(
        name: 'Core',
        confidence: _avgConfidence(landmarks, _coreIndices),
        landmarkIndices: _coreIndices,
      ),
      lowerBody: BodyRegion(
        name: 'Lower Body',
        confidence: _avgConfidence(landmarks, _lowerIndices),
        landmarkIndices: _lowerIndices,
      ),
      timestampMicros: pose.timestampMicros,
    );
  }

  /// Calculate average confidence for a set of landmark indices
  double _avgConfidence(List<NormalizedLandmark> landmarks, List<int> indices) {
    double sum = 0;
    int count = 0;
    for (final idx in indices) {
      if (idx < landmarks.length) {
        sum += landmarks[idx].likelihood;
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }
}
