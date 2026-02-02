/// Real-time pipeline metrics for observability and performance monitoring
class SessionMetrics {
  /// Total camera frames received by the pipeline
  final int totalFramesReceived;

  /// Total frames successfully processed through ML Kit
  final int totalFramesProcessed;

  /// Total frames dropped due to back-pressure (processing too slow)
  final int totalFramesDropped;

  /// Total poses successfully detected (frames may have 0 poses if no person visible)
  final int totalPosesDetected;

  /// Average processing latency in milliseconds
  /// Time from ML Kit processImage start to completion
  final double averageLatencyMs;

  /// Sum of all latencies (for calculating running average)
  final double _totalLatencyMs;

  /// Average end-to-end latency in milliseconds
  /// Time from camera frame capture (timestamp) to state emission
  /// This is the "visual lag" the user perceives
  final double averageEndToEndLatencyMs;

  /// Sum of all end-to-end latencies (for calculating running average)
  final double _totalEndToEndLatencyMs;

  /// Last measured end-to-end latency (for real-time display)
  final double lastEndToEndLatencyMs;

  const SessionMetrics({
    this.totalFramesReceived = 0,
    this.totalFramesProcessed = 0,
    this.totalFramesDropped = 0,
    this.totalPosesDetected = 0,
    this.averageLatencyMs = 0.0,
    double totalLatencyMs = 0.0,
    this.averageEndToEndLatencyMs = 0.0,
    double totalEndToEndLatencyMs = 0.0,
    this.lastEndToEndLatencyMs = 0.0,
  })  : _totalLatencyMs = totalLatencyMs,
        _totalEndToEndLatencyMs = totalEndToEndLatencyMs;

  /// Effective frames per second (based on processed frames)
  double effectiveFps(Duration sessionDuration) {
    if (sessionDuration.inMilliseconds == 0) return 0.0;
    return totalFramesProcessed / (sessionDuration.inMilliseconds / 1000.0);
  }

  /// Frame drop rate as percentage (0.0 to 100.0)
  double get dropRate {
    if (totalFramesReceived == 0) return 0.0;
    return (totalFramesDropped / totalFramesReceived) * 100.0;
  }

  /// Detection rate as percentage (0.0 to 100.0)
  /// Percentage of processed frames where a pose was detected
  double get detectionRate {
    if (totalFramesProcessed == 0) return 0.0;
    return (totalPosesDetected / totalFramesProcessed) * 100.0;
  }

  /// Update metrics with a new processed frame
  ///
  /// [latencyMs] - ML Kit processing time only
  /// [endToEndLatencyMs] - Optional total latency from frame capture to state emission
  SessionMetrics withProcessedFrame({
    required bool poseDetected,
    required double latencyMs,
    double? endToEndLatencyMs,
  }) {
    final newProcessed = totalFramesProcessed + 1;
    final newPoses = poseDetected ? totalPosesDetected + 1 : totalPosesDetected;
    final newTotalLatency = _totalLatencyMs + latencyMs;
    final newAverage = newTotalLatency / newProcessed;

    // Calculate end-to-end metrics if provided
    final newTotalE2E = endToEndLatencyMs != null
        ? _totalEndToEndLatencyMs + endToEndLatencyMs
        : _totalEndToEndLatencyMs;
    final newAverageE2E = endToEndLatencyMs != null
        ? newTotalE2E / newProcessed
        : averageEndToEndLatencyMs;
    final newLastE2E = endToEndLatencyMs ?? lastEndToEndLatencyMs;

    return SessionMetrics(
      totalFramesReceived: totalFramesReceived,
      totalFramesProcessed: newProcessed,
      totalFramesDropped: totalFramesDropped,
      totalPosesDetected: newPoses,
      averageLatencyMs: newAverage,
      totalLatencyMs: newTotalLatency,
      averageEndToEndLatencyMs: newAverageE2E,
      totalEndToEndLatencyMs: newTotalE2E,
      lastEndToEndLatencyMs: newLastE2E,
    );
  }

  /// Update metrics when a frame is received
  SessionMetrics withReceivedFrame() {
    return SessionMetrics(
      totalFramesReceived: totalFramesReceived + 1,
      totalFramesProcessed: totalFramesProcessed,
      totalFramesDropped: totalFramesDropped,
      totalPosesDetected: totalPosesDetected,
      averageLatencyMs: averageLatencyMs,
      totalLatencyMs: _totalLatencyMs,
      averageEndToEndLatencyMs: averageEndToEndLatencyMs,
      totalEndToEndLatencyMs: _totalEndToEndLatencyMs,
      lastEndToEndLatencyMs: lastEndToEndLatencyMs,
    );
  }

  /// Update metrics when a frame is dropped
  SessionMetrics withDroppedFrame() {
    return SessionMetrics(
      totalFramesReceived: totalFramesReceived + 1,
      totalFramesProcessed: totalFramesProcessed,
      totalFramesDropped: totalFramesDropped + 1,
      totalPosesDetected: totalPosesDetected,
      averageLatencyMs: averageLatencyMs,
      totalLatencyMs: _totalLatencyMs,
      averageEndToEndLatencyMs: averageEndToEndLatencyMs,
      totalEndToEndLatencyMs: _totalEndToEndLatencyMs,
      lastEndToEndLatencyMs: lastEndToEndLatencyMs,
    );
  }

  @override
  String toString() {
    return 'SessionMetrics(received: $totalFramesReceived, processed: $totalFramesProcessed, dropped: $totalFramesDropped, poses: $totalPosesDetected, avgLatency: ${averageLatencyMs.toStringAsFixed(2)}ms, avgE2E: ${averageEndToEndLatencyMs.toStringAsFixed(2)}ms, dropRate: ${dropRate.toStringAsFixed(1)}%)';
  }
}
