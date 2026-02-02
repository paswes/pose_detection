/// Central configuration for pose detection pipeline.
/// All magic numbers extracted here for clarity and testability.
class PoseDetectionConfig {
  /// Maximum poses to retain in ring buffer.
  /// At 30 FPS, 900 = 30 seconds of data.
  final int maxPosesInMemory;

  /// Maximum consecutive errors before stopping capture.
  final int maxConsecutiveErrors;

  /// Latency thresholds for performance categorization.
  final LatencyThresholds latencyThresholds;

  /// Number of landmarks expected from pose model.
  final int expectedLandmarkCount;

  const PoseDetectionConfig({
    this.maxPosesInMemory = 900,
    this.maxConsecutiveErrors = 10,
    this.latencyThresholds = const LatencyThresholds(),
    this.expectedLandmarkCount = 33,
  });

  /// Default configuration for ML Kit 33-landmark model
  static const mlKit33 = PoseDetectionConfig(
    expectedLandmarkCount: 33,
  );
}

/// Latency thresholds for performance categorization (milliseconds).
class LatencyThresholds {
  /// Excellent performance threshold (green)
  final double excellent;

  /// Acceptable performance threshold (yellow)
  final double acceptable;

  /// Warning threshold (orange). Above this = red.
  final double warning;

  const LatencyThresholds({
    this.excellent = 50.0,
    this.acceptable = 100.0,
    this.warning = 150.0,
  });
}
