import 'session_metrics.dart';
import 'motion_metrics.dart';
import 'motion_data.dart';

/// Combined snapshot of all inspection data
/// Separates Performance (pipeline health) from Motion (pose analysis)
class InspectionSnapshot {
  // === PERFORMANCE METRICS (Pipeline Health) ===

  /// Session metrics from the pose detection pipeline
  final SessionMetrics performanceMetrics;

  /// Current session duration
  final Duration sessionDuration;

  // === MOTION METRICS (Pose Analysis) ===

  /// Motion analysis results (angles, velocity, body regions)
  final MotionMetrics motionMetrics;

  /// Current raw pose data (for detailed inspection)
  final TimestampedPose? currentPose;

  // === CHART DATA (Rolling history) ===

  /// FPS history for rolling chart
  final List<double> fpsHistory;

  /// Latency history for rolling chart (ms)
  final List<double> latencyHistory;

  /// Confidence history for rolling chart
  final List<double> confidenceHistory;

  const InspectionSnapshot({
    required this.performanceMetrics,
    required this.sessionDuration,
    required this.motionMetrics,
    this.currentPose,
    this.fpsHistory = const [],
    this.latencyHistory = const [],
    this.confidenceHistory = const [],
  });

  /// Current effective FPS
  double get currentFps => performanceMetrics.effectiveFps(sessionDuration);

  /// Current end-to-end latency
  double get currentLatency => performanceMetrics.lastEndToEndLatencyMs;

  /// Average ML processing latency
  double get averageLatency => performanceMetrics.averageLatencyMs;

  /// Frame drop rate percentage
  double get dropRate => performanceMetrics.dropRate;

  /// Detection rate percentage
  double get detectionRate => performanceMetrics.detectionRate;

  /// Is pose currently being detected?
  bool get isDetecting => currentPose != null;

  /// Total poses captured in session
  int get totalPoses => performanceMetrics.totalPosesDetected;

  /// Total frames processed
  int get totalFrames => performanceMetrics.totalFramesProcessed;

  /// Session duration formatted as MM:SS
  String get durationFormatted {
    final minutes = sessionDuration.inMinutes;
    final seconds = sessionDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Empty snapshot for initial state
  static const empty = InspectionSnapshot(
    performanceMetrics: SessionMetrics(),
    sessionDuration: Duration.zero,
    motionMetrics: MotionMetrics.empty,
  );
}
