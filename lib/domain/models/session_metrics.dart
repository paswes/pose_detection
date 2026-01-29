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

  /// Total poses that passed human validation (confirmed human, not false positive)
  final int totalValidatedPoses;

  /// Total poses rejected by human validation (likely non-human/false positive)
  final int totalRejectedPoses;

  /// Average validation confidence for accepted poses (0.0 to 1.0)
  final double averageValidationConfidence;

  /// Sum of validation confidences (for calculating running average)
  final double _totalValidationConfidence;

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
    this.totalValidatedPoses = 0,
    this.totalRejectedPoses = 0,
    this.averageValidationConfidence = 0.0,
    double totalValidationConfidence = 0.0,
    this.averageLatencyMs = 0.0,
    double totalLatencyMs = 0.0,
    this.averageEndToEndLatencyMs = 0.0,
    double totalEndToEndLatencyMs = 0.0,
    this.lastEndToEndLatencyMs = 0.0,
  })  : _totalLatencyMs = totalLatencyMs,
        _totalEndToEndLatencyMs = totalEndToEndLatencyMs,
        _totalValidationConfidence = totalValidationConfidence;

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

  /// Pose rejection rate as percentage (0.0 to 100.0)
  /// Indicates how many detected poses were rejected as non-human
  double get rejectionRate {
    if (totalPosesDetected == 0) return 0.0;
    return (totalRejectedPoses / totalPosesDetected) * 100.0;
  }

  /// Validation pass rate as percentage (0.0 to 100.0)
  double get validationPassRate {
    if (totalPosesDetected == 0) return 0.0;
    return (totalValidatedPoses / totalPosesDetected) * 100.0;
  }

  /// Update metrics with a new processed frame
  ///
  /// [latencyMs] - ML Kit processing time only
  /// [endToEndLatencyMs] - Optional total latency from frame capture to state emission
  /// [poseValidated] - Whether the detected pose passed human validation
  /// [validationConfidence] - Confidence score from validation (0.0 to 1.0)
  SessionMetrics withProcessedFrame({
    required bool poseDetected,
    required double latencyMs,
    double? endToEndLatencyMs,
    bool? poseValidated,
    double? validationConfidence,
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

    // Calculate validation metrics
    int newValidated = totalValidatedPoses;
    int newRejected = totalRejectedPoses;
    double newTotalValConf = _totalValidationConfidence;
    double newAvgValConf = averageValidationConfidence;

    if (poseDetected && poseValidated != null) {
      if (poseValidated) {
        newValidated++;
        if (validationConfidence != null) {
          newTotalValConf += validationConfidence;
          newAvgValConf = newTotalValConf / newValidated;
        }
      } else {
        newRejected++;
      }
    }

    return SessionMetrics(
      totalFramesReceived: totalFramesReceived,
      totalFramesProcessed: newProcessed,
      totalFramesDropped: totalFramesDropped,
      totalPosesDetected: newPoses,
      totalValidatedPoses: newValidated,
      totalRejectedPoses: newRejected,
      averageValidationConfidence: newAvgValConf,
      totalValidationConfidence: newTotalValConf,
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
      totalValidatedPoses: totalValidatedPoses,
      totalRejectedPoses: totalRejectedPoses,
      averageValidationConfidence: averageValidationConfidence,
      totalValidationConfidence: _totalValidationConfidence,
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
      totalValidatedPoses: totalValidatedPoses,
      totalRejectedPoses: totalRejectedPoses,
      averageValidationConfidence: averageValidationConfidence,
      totalValidationConfidence: _totalValidationConfidence,
      averageLatencyMs: averageLatencyMs,
      totalLatencyMs: _totalLatencyMs,
      averageEndToEndLatencyMs: averageEndToEndLatencyMs,
      totalEndToEndLatencyMs: _totalEndToEndLatencyMs,
      lastEndToEndLatencyMs: lastEndToEndLatencyMs,
    );
  }

  @override
  String toString() {
    return 'SessionMetrics(received: $totalFramesReceived, processed: $totalFramesProcessed, dropped: $totalFramesDropped, poses: $totalPosesDetected, validated: $totalValidatedPoses, rejected: $totalRejectedPoses, avgLatency: ${averageLatencyMs.toStringAsFixed(2)}ms, avgE2E: ${averageEndToEndLatencyMs.toStringAsFixed(2)}ms, dropRate: ${dropRate.toStringAsFixed(1)}%, rejectionRate: ${rejectionRate.toStringAsFixed(1)}%)';
  }
}
