/// Central configuration for pose detection pipeline.
/// Contains error handling and performance thresholds.
class PoseDetectionConfig {
  /// Maximum consecutive errors before stopping capture.
  final int maxConsecutiveErrors;

  /// Latency thresholds for performance categorization.
  final LatencyThresholds latencyThresholds;

  const PoseDetectionConfig({
    this.maxConsecutiveErrors = 10,
    this.latencyThresholds = const LatencyThresholds(),
  });

  /// Default configuration
  static const defaultConfig = PoseDetectionConfig();
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
