import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/data_structures/pose_buffer.dart';
import 'package:pose_detection/core/interfaces/pose_buffer_interface.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/domain/models/session_metrics.dart';

/// Manages capture session state and pose history.
/// Handles ring buffer, frame indexing, and session lifecycle.
class SessionManager {
  final PoseDetectionConfig _config;

  PoseSession? _currentSession;
  PoseSession? _lastSession;
  late IPoseBuffer _poseBuffer;
  int _frameIndex = 0;
  int? _previousTimestampMicros;
  SessionMetrics _currentMetrics = const SessionMetrics();

  SessionManager({required PoseDetectionConfig config}) : _config = config {
    _poseBuffer = PoseBuffer(capacity: _config.maxPosesInMemory);
  }

  /// Current active session
  PoseSession? get currentSession => _currentSession;

  /// Last completed session
  PoseSession? get lastSession => _lastSession;

  /// Current frame index
  int get frameIndex => _frameIndex;

  /// Previous frame timestamp for delta calculation
  int? get previousTimestampMicros => _previousTimestampMicros;

  /// Whether a session is active
  bool get hasActiveSession => _currentSession != null;

  /// Current metrics
  SessionMetrics get currentMetrics => _currentMetrics;

  /// Start a new capture session
  void startSession() {
    _frameIndex = 0;
    _previousTimestampMicros = null;
    _poseBuffer.clear();
    _currentMetrics = const SessionMetrics();

    _currentSession = PoseSession(
      startTime: DateTime.now(),
      capturedPoses: [],
      metrics: _currentMetrics,
    );
  }

  /// End the current session
  void endSession() {
    if (_currentSession == null) return;

    _lastSession = PoseSession(
      startTime: _currentSession!.startTime,
      endTime: DateTime.now(),
      capturedPoses: _poseBuffer.poses,
      metrics: _currentMetrics,
    );
    _currentSession = null;
  }

  /// Add a pose to the session
  void addPose(TimestampedPose pose) {
    _poseBuffer.add(pose);
    _previousTimestampMicros = pose.timestampMicros;
  }

  /// Get and increment frame index
  int nextFrameIndex() => _frameIndex++;

  /// Update metrics for a received frame
  void recordReceivedFrame() {
    _currentMetrics = _currentMetrics.withReceivedFrame();
  }

  /// Update metrics for a processed frame
  void recordProcessedFrame({
    required bool poseDetected,
    required double latencyMs,
    required double endToEndLatencyMs,
  }) {
    _currentMetrics = _currentMetrics.withProcessedFrame(
      poseDetected: poseDetected,
      latencyMs: latencyMs,
      endToEndLatencyMs: endToEndLatencyMs,
    );
  }

  /// Update metrics for a dropped frame
  void recordDroppedFrame() {
    _currentMetrics = _currentMetrics.withDroppedFrame();
  }

  /// Get current session with updated data
  PoseSession? getCurrentSessionSnapshot() {
    if (_currentSession == null) return null;

    return PoseSession(
      startTime: _currentSession!.startTime,
      capturedPoses: _poseBuffer.poses,
      metrics: _currentMetrics,
    );
  }

  /// Reset all state
  void reset() {
    _currentSession = null;
    _frameIndex = 0;
    _previousTimestampMicros = null;
    _poseBuffer.clear();
    _currentMetrics = const SessionMetrics();
  }
}
