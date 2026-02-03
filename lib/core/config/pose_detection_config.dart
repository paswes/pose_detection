/// Central configuration for pose detection pipeline.
/// All parameters are configurable with sensible defaults.
///
/// Usage:
/// ```dart
/// // Default configuration
/// final config = PoseDetectionConfig.defaultConfig();
///
/// // Smooth visuals (more smoothing, more lag)
/// final smooth = PoseDetectionConfig.smoothVisuals();
///
/// // Custom configuration
/// final custom = PoseDetectionConfig(
///   smoothingEnabled: true,
///   smoothingMinCutoff: 0.8,
/// );
/// ```
class PoseDetectionConfig {
  // ============================================
  // Error Handling
  // ============================================

  /// Maximum consecutive errors before stopping capture.
  final int maxConsecutiveErrors;

  // ============================================
  // Latency Thresholds
  // ============================================

  /// Latency thresholds for performance categorization.
  final LatencyThresholds latencyThresholds;

  // ============================================
  // Smoothing Configuration (OneEuroFilter)
  // ============================================

  /// Whether landmark smoothing is enabled.
  /// When enabled, reduces jitter in landmark positions.
  final bool smoothingEnabled;

  /// Minimum cutoff frequency for the filter.
  /// Lower values = more smoothing but more lag.
  /// Range: 0.1 - 10.0, Default: 1.0
  final double smoothingMinCutoff;

  /// Speed coefficient - how much speed affects cutoff.
  /// Higher values = less lag during fast movements.
  /// Range: 0.0 - 1.0, Default: 0.007
  final double smoothingBeta;

  /// Derivative cutoff frequency.
  /// Controls smoothing of the speed estimation.
  /// Range: 0.1 - 10.0, Default: 1.0
  final double smoothingDerivativeCutoff;

  // ============================================
  // Confidence Thresholds
  // ============================================

  /// Threshold for high confidence landmarks.
  /// Landmarks above this are considered reliable.
  final double highConfidenceThreshold;

  /// Threshold for low confidence landmarks.
  /// Landmarks below this may be unreliable.
  final double lowConfidenceThreshold;

  /// Minimum confidence required to include a landmark.
  /// Landmarks below this are filtered out (if filtering enabled).
  final double minConfidenceThreshold;

  /// Whether to filter out low confidence landmarks.
  final bool filterLowConfidenceLandmarks;

  // ============================================
  // FPS & Metrics
  // ============================================

  /// Window size for FPS calculation in milliseconds.
  final int fpsWindowMs;

  /// Maximum frames to track for FPS calculation.
  final int fpsBufferSize;

  const PoseDetectionConfig({
    // Error handling
    this.maxConsecutiveErrors = 10,
    this.latencyThresholds = const LatencyThresholds(),
    // Smoothing
    this.smoothingEnabled = true,
    this.smoothingMinCutoff = 1.0,
    this.smoothingBeta = 0.007,
    this.smoothingDerivativeCutoff = 1.0,
    // Confidence
    this.highConfidenceThreshold = 0.8,
    this.lowConfidenceThreshold = 0.5,
    this.minConfidenceThreshold = 0.3,
    this.filterLowConfidenceLandmarks = false,
    // FPS
    this.fpsWindowMs = 1000,
    this.fpsBufferSize = 60,
  });

  // ============================================
  // Factory Constructors (Dart 3 idiomatic)
  // ============================================

  /// Default configuration with sensible values for general use.
  factory PoseDetectionConfig.defaultConfig() => const PoseDetectionConfig();

  /// Configuration optimized for smooth visuals.
  /// More smoothing, slightly more lag - ideal for UI presentation.
  factory PoseDetectionConfig.smoothVisuals() => const PoseDetectionConfig(
        smoothingEnabled: true,
        smoothingMinCutoff: 0.5,
        smoothingBeta: 0.005,
        smoothingDerivativeCutoff: 0.5,
      );

  /// Configuration optimized for responsive tracking.
  /// Less smoothing, minimal lag - ideal for real-time feedback.
  factory PoseDetectionConfig.responsive() => const PoseDetectionConfig(
        smoothingEnabled: true,
        smoothingMinCutoff: 2.0,
        smoothingBeta: 0.01,
        smoothingDerivativeCutoff: 1.5,
      );

  /// Configuration with smoothing disabled.
  /// Raw ML output - useful for debugging or custom processing.
  factory PoseDetectionConfig.raw() => const PoseDetectionConfig(
        smoothingEnabled: false,
      );

  /// Configuration optimized for high precision applications.
  /// Higher confidence thresholds, more aggressive filtering.
  factory PoseDetectionConfig.highPrecision() => const PoseDetectionConfig(
        smoothingEnabled: true,
        smoothingMinCutoff: 0.8,
        smoothingBeta: 0.005,
        highConfidenceThreshold: 0.9,
        lowConfidenceThreshold: 0.6,
        minConfidenceThreshold: 0.5,
        filterLowConfidenceLandmarks: true,
      );

  /// Create a copy with modified values
  PoseDetectionConfig copyWith({
    int? maxConsecutiveErrors,
    LatencyThresholds? latencyThresholds,
    bool? smoothingEnabled,
    double? smoothingMinCutoff,
    double? smoothingBeta,
    double? smoothingDerivativeCutoff,
    double? highConfidenceThreshold,
    double? lowConfidenceThreshold,
    double? minConfidenceThreshold,
    bool? filterLowConfidenceLandmarks,
    int? fpsWindowMs,
    int? fpsBufferSize,
  }) {
    return PoseDetectionConfig(
      maxConsecutiveErrors: maxConsecutiveErrors ?? this.maxConsecutiveErrors,
      latencyThresholds: latencyThresholds ?? this.latencyThresholds,
      smoothingEnabled: smoothingEnabled ?? this.smoothingEnabled,
      smoothingMinCutoff: smoothingMinCutoff ?? this.smoothingMinCutoff,
      smoothingBeta: smoothingBeta ?? this.smoothingBeta,
      smoothingDerivativeCutoff:
          smoothingDerivativeCutoff ?? this.smoothingDerivativeCutoff,
      highConfidenceThreshold:
          highConfidenceThreshold ?? this.highConfidenceThreshold,
      lowConfidenceThreshold:
          lowConfidenceThreshold ?? this.lowConfidenceThreshold,
      minConfidenceThreshold:
          minConfidenceThreshold ?? this.minConfidenceThreshold,
      filterLowConfidenceLandmarks:
          filterLowConfidenceLandmarks ?? this.filterLowConfidenceLandmarks,
      fpsWindowMs: fpsWindowMs ?? this.fpsWindowMs,
      fpsBufferSize: fpsBufferSize ?? this.fpsBufferSize,
    );
  }
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
