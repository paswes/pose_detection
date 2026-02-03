import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/pose_sequence.dart';
import 'package:pose_detection/domain/motion/models/range_of_motion.dart';
import 'package:pose_detection/domain/motion/models/velocity.dart';
import 'package:pose_detection/domain/motion/services/angle_calculator.dart';
import 'package:pose_detection/domain/motion/services/range_of_motion_analyzer.dart';
import 'package:pose_detection/domain/motion/services/velocity_tracker.dart';

/// Configuration for the MotionAnalyzer.
///
/// Usage:
/// ```dart
/// // Default configuration
/// final config = MotionAnalyzerConfig.defaultConfig();
///
/// // Minimal (angles only)
/// final minimal = MotionAnalyzerConfig.minimal();
///
/// // Full analysis
/// final full = MotionAnalyzerConfig.fullAnalysis();
/// ```
class MotionAnalyzerConfig {
  /// Whether to track joint angles
  final bool trackAngles;

  /// Whether to track velocities
  final bool trackVelocities;

  /// Whether to track range of motion
  final bool trackRom;

  /// Whether to maintain pose history
  final bool maintainHistory;

  /// Maximum poses to keep in history
  final int historyCapacity;

  /// Whether to use 3D angle calculations (vs 2D)
  final bool use3DAngles;

  /// Minimum confidence for calculations
  final double minConfidence;

  /// Velocity smoothing factor
  final double velocitySmoothingFactor;

  const MotionAnalyzerConfig({
    this.trackAngles = true,
    this.trackVelocities = true,
    this.trackRom = true,
    this.maintainHistory = true,
    this.historyCapacity = 30,
    this.use3DAngles = true,
    this.minConfidence = 0.3,
    this.velocitySmoothingFactor = 0.3,
  });

  // ============================================
  // Factory Constructors (Dart 3 idiomatic)
  // ============================================

  /// Default configuration with all features enabled.
  factory MotionAnalyzerConfig.defaultConfig() => const MotionAnalyzerConfig();

  /// Minimal configuration - angles only, no history or velocities.
  /// Useful for simple angle monitoring with lower overhead.
  factory MotionAnalyzerConfig.minimal() => const MotionAnalyzerConfig(
        trackAngles: true,
        trackVelocities: false,
        trackRom: false,
        maintainHistory: false,
      );

  /// Full analysis configuration with extended history.
  /// Maximum tracking capability for detailed analysis.
  factory MotionAnalyzerConfig.fullAnalysis() => const MotionAnalyzerConfig(
        trackAngles: true,
        trackVelocities: true,
        trackRom: true,
        maintainHistory: true,
        historyCapacity: 60,
      );

  /// Configuration for ROM-focused tracking.
  /// Ideal for flexibility/mobility assessment.
  factory MotionAnalyzerConfig.romFocused() => const MotionAnalyzerConfig(
        trackAngles: true,
        trackVelocities: false,
        trackRom: true,
        maintainHistory: true,
        historyCapacity: 120, // Longer history for ROM tracking
      );

  /// Configuration for velocity-focused tracking.
  /// Ideal for speed/movement analysis.
  factory MotionAnalyzerConfig.velocityFocused() => const MotionAnalyzerConfig(
        trackAngles: true,
        trackVelocities: true,
        trackRom: false,
        maintainHistory: true,
        historyCapacity: 30,
        velocitySmoothingFactor: 0.2, // Less smoothing for responsiveness
      );

  /// Copy with modified values
  MotionAnalyzerConfig copyWith({
    bool? trackAngles,
    bool? trackVelocities,
    bool? trackRom,
    bool? maintainHistory,
    int? historyCapacity,
    bool? use3DAngles,
    double? minConfidence,
    double? velocitySmoothingFactor,
  }) {
    return MotionAnalyzerConfig(
      trackAngles: trackAngles ?? this.trackAngles,
      trackVelocities: trackVelocities ?? this.trackVelocities,
      trackRom: trackRom ?? this.trackRom,
      maintainHistory: maintainHistory ?? this.maintainHistory,
      historyCapacity: historyCapacity ?? this.historyCapacity,
      use3DAngles: use3DAngles ?? this.use3DAngles,
      minConfidence: minConfidence ?? this.minConfidence,
      velocitySmoothingFactor:
          velocitySmoothingFactor ?? this.velocitySmoothingFactor,
    );
  }
}

/// Result of motion analysis for a single frame
class MotionAnalysisResult {
  /// The analyzed pose
  final DetectedPose pose;

  /// Calculated joint angles
  final Map<String, JointAngle> angles;

  /// Calculated velocities
  final Map<int, Velocity> velocities;

  /// Calculated angular velocities
  final Map<String, AngularVelocity> angularVelocities;

  /// Current range of motion data
  final Map<String, RangeOfMotion> rangeOfMotion;

  /// Timestamp of analysis
  final int timestampMicros;

  const MotionAnalysisResult({
    required this.pose,
    required this.angles,
    required this.velocities,
    required this.angularVelocities,
    required this.rangeOfMotion,
    required this.timestampMicros,
  });

  /// Check if we have valid angle data
  bool get hasAngles => angles.isNotEmpty;

  /// Check if we have valid velocity data
  bool get hasVelocities => velocities.isNotEmpty;

  /// Check if the body is approximately stationary
  bool get isStationary {
    if (velocities.isEmpty) return true;
    double avgSpeed = 0;
    for (final v in velocities.values) {
      avgSpeed += v.speed;
    }
    avgSpeed /= velocities.length;
    return avgSpeed < 20.0;
  }

  /// Get angle for a specific joint
  JointAngle? getAngle(String jointId) => angles[jointId];

  /// Get velocity for a specific landmark
  Velocity? getVelocity(int landmarkId) => velocities[landmarkId];

  /// Get ROM for a specific joint
  RangeOfMotion? getRom(String jointId) => rangeOfMotion[jointId];
}

/// Facade service that orchestrates all motion analysis components.
///
/// Provides a unified interface for analyzing human motion from poses.
/// Exercise-agnostic - provides raw motion data without knowledge of
/// specific exercises or movements.
///
/// Usage:
/// ```dart
/// final analyzer = MotionAnalyzer();
/// final result = analyzer.analyze(pose);
///
/// // Access angles
/// final elbowAngle = result.angles['11_13_15']?.degrees;
///
/// // Access velocities
/// final handSpeed = result.velocities[15]?.speed;
///
/// // Access ROM
/// final kneeRom = result.rangeOfMotion['23_25_27']?.rangeDegrees;
/// ```
class MotionAnalyzer {
  final MotionAnalyzerConfig config;

  // Internal services
  late final AngleCalculator _angleCalculator;
  late final VelocityTracker _velocityTracker;
  late final RangeOfMotionAnalyzer _romAnalyzer;
  late final PoseSequence _poseSequence;

  // State
  bool _isActive = false;

  MotionAnalyzer({this.config = const MotionAnalyzerConfig()}) {
    _angleCalculator = AngleCalculator();
    _velocityTracker = VelocityTracker(
      smoothingFactor: config.velocitySmoothingFactor,
      minConfidence: config.minConfidence,
    );
    _romAnalyzer = RangeOfMotionAnalyzer(
      minConfidence: config.minConfidence,
    );
    _poseSequence = PoseSequence(capacity: config.historyCapacity);
  }

  /// Start a new analysis session
  void startSession() {
    _isActive = true;
    reset();
  }

  /// End the current analysis session
  void endSession() {
    _isActive = false;
  }

  /// Whether an analysis session is active
  bool get isActive => _isActive;

  /// Analyze a pose and return motion analysis results
  MotionAnalysisResult analyze(DetectedPose pose) {
    // Add to history
    if (config.maintainHistory) {
      _poseSequence.add(pose);
    }

    // Calculate angles
    Map<String, JointAngle> angles = {};
    if (config.trackAngles) {
      angles = _angleCalculator.calculateAllCommonAngles(
        pose: pose,
        use3D: config.use3DAngles,
        minConfidence: config.minConfidence,
      );
    }

    // Calculate velocities
    Map<int, Velocity> velocities = {};
    Map<String, AngularVelocity> angularVelocities = {};
    if (config.trackVelocities) {
      velocities = _velocityTracker.updatePose(pose);
      if (angles.isNotEmpty) {
        angularVelocities = _velocityTracker.updateAngles(
          angles,
          pose.timestampMicros,
        );
      }
    }

    // Update ROM
    Map<String, RangeOfMotion> rom = {};
    if (config.trackRom && angles.isNotEmpty) {
      rom = _romAnalyzer.updateAngles(angles);
    }

    return MotionAnalysisResult(
      pose: pose,
      angles: angles,
      velocities: velocities,
      angularVelocities: angularVelocities,
      rangeOfMotion: rom,
      timestampMicros: pose.timestampMicros,
    );
  }

  /// Get the angle calculator for advanced usage
  AngleCalculator get angleCalculator => _angleCalculator;

  /// Get the velocity tracker for advanced usage
  VelocityTracker get velocityTracker => _velocityTracker;

  /// Get the ROM analyzer for advanced usage
  RangeOfMotionAnalyzer get romAnalyzer => _romAnalyzer;

  /// Get the pose sequence for advanced usage
  PoseSequence get poseSequence => _poseSequence;

  /// Get current ROM summary
  RomSummary getRomSummary() => _romAnalyzer.getSummary();

  /// Get average body speed
  double get averageBodySpeed => _velocityTracker.averageBodySpeed;

  /// Check if body is stationary
  bool get isStationary => _velocityTracker.isStationary();

  /// Reset all analysis state
  void reset() {
    _velocityTracker.reset();
    _romAnalyzer.reset();
    _poseSequence.clear();
  }

  /// Dispose of resources
  void dispose() {
    reset();
    _isActive = false;
  }
}

/// Interface for motion analysis
abstract class IMotionAnalyzer {
  void startSession();
  void endSession();
  MotionAnalysisResult analyze(DetectedPose pose);
  RomSummary getRomSummary();
  void reset();
  void dispose();
}
