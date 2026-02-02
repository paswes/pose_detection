/// Configuration for the inspection tool and motion analysis
class InspectionConfig {
  /// Rolling window duration for charts (seconds)
  final int chartWindowSeconds;

  /// Sample rate for chart updates (Hz)
  final int chartSampleRateHz;

  /// Minimum confidence threshold for angle calculations
  /// Angles are not calculated if any landmark in the triplet is below this
  final double minConfidenceForAngle;

  /// Number of frames to average for velocity smoothing
  final int velocitySmoothingFrames;

  /// Thresholds for body region quality assessment
  final BodyRegionThresholds bodyRegionThresholds;

  const InspectionConfig({
    this.chartWindowSeconds = 10,
    this.chartSampleRateHz = 10,
    this.minConfidenceForAngle = 0.5,
    this.velocitySmoothingFrames = 3,
    this.bodyRegionThresholds = const BodyRegionThresholds(),
  });

  static const defaultConfig = InspectionConfig();
}

/// Thresholds for categorizing body region confidence quality
class BodyRegionThresholds {
  /// Confidence above this is "excellent"
  final double excellent;

  /// Confidence above this is "good"
  final double good;

  /// Confidence above this is "acceptable", below is "poor"
  final double acceptable;

  const BodyRegionThresholds({
    this.excellent = 0.8,
    this.good = 0.6,
    this.acceptable = 0.4,
  });
}
