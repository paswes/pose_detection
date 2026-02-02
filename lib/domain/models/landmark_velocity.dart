/// Speed category for movement classification
enum SpeedCategory {
  /// Almost no movement (< 0.1 normalized units/s)
  stationary,

  /// Slow movement (0.1 - 0.3 normalized units/s)
  slow,

  /// Moderate movement (0.3 - 0.7 normalized units/s)
  moderate,

  /// Fast movement (> 0.7 normalized units/s)
  fast,
}

/// Represents velocity of a single landmark between frames
class LandmarkVelocity {
  /// Landmark ID (0-32)
  final int landmarkId;

  /// X velocity component (normalized units per second)
  final double vx;

  /// Y velocity component (normalized units per second)
  final double vy;

  /// Speed magnitude (normalized units per second)
  final double speed;

  /// Movement direction in degrees
  /// 0° = right, 90° = down, 180° = left, 270° = up
  final double directionDegrees;

  /// Average confidence of the landmarks used for calculation
  final double confidence;

  /// Timestamp of the measurement (microseconds)
  final int timestampMicros;

  const LandmarkVelocity({
    required this.landmarkId,
    required this.vx,
    required this.vy,
    required this.speed,
    required this.directionDegrees,
    required this.confidence,
    required this.timestampMicros,
  });

  /// Classify speed into categories
  SpeedCategory get speedCategory {
    if (speed < 0.1) return SpeedCategory.stationary;
    if (speed < 0.3) return SpeedCategory.slow;
    if (speed < 0.7) return SpeedCategory.moderate;
    return SpeedCategory.fast;
  }

  /// Human-readable speed category
  String get speedLabel {
    switch (speedCategory) {
      case SpeedCategory.stationary:
        return 'Stationary';
      case SpeedCategory.slow:
        return 'Slow';
      case SpeedCategory.moderate:
        return 'Moderate';
      case SpeedCategory.fast:
        return 'Fast';
    }
  }

  @override
  String toString() =>
      'LandmarkVelocity($landmarkId: speed=${speed.toStringAsFixed(3)}, dir=${directionDegrees.toStringAsFixed(0)}°)';
}
