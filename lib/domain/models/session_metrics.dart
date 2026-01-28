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

  const SessionMetrics({
    this.totalFramesReceived = 0,
    this.totalFramesProcessed = 0,
    this.totalFramesDropped = 0,
    this.totalPosesDetected = 0,
    this.averageLatencyMs = 0.0,
    double totalLatencyMs = 0.0,
  }) : _totalLatencyMs = totalLatencyMs;

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

  /// Update metrics with a new processed frame
  SessionMetrics withProcessedFrame({
    required bool poseDetected,
    required double latencyMs,
  }) {
    final newProcessed = totalFramesProcessed + 1;
    final newPoses = poseDetected ? totalPosesDetected + 1 : totalPosesDetected;
    final newTotalLatency = _totalLatencyMs + latencyMs;
    final newAverage = newTotalLatency / newProcessed;

    return SessionMetrics(
      totalFramesReceived: totalFramesReceived,
      totalFramesProcessed: newProcessed,
      totalFramesDropped: totalFramesDropped,
      totalPosesDetected: newPoses,
      averageLatencyMs: newAverage,
      totalLatencyMs: newTotalLatency,
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
    );
  }

  @override
  String toString() {
    return 'SessionMetrics(received: $totalFramesReceived, processed: $totalFramesProcessed, dropped: $totalFramesDropped, poses: $totalPosesDetected, avgLatency: ${averageLatencyMs.toStringAsFixed(2)}ms, dropRate: ${dropRate.toStringAsFixed(1)}%)';
  }
}
