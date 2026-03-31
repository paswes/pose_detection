/// Real-time detection metrics for UI display.
/// Simple, immutable metrics updated per frame.
class DetectionMetrics {
  /// Current frames per second
  final double fps;

  /// Current end-to-end latency in milliseconds
  final double latencyMs;

  const DetectionMetrics({
    this.fps = 0.0,
    this.latencyMs = 0.0,
  });

  DetectionMetrics copyWith({
    double? fps,
    double? latencyMs,
  }) {
    return DetectionMetrics(
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }
}
