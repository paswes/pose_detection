/// Represents the phases of a squat movement
enum SquatPhase {
  /// Upright position with knees nearly straight (knee angle > 150°)
  standing,

  /// Moving downward, knee angle decreasing
  descending,

  /// Lowest point of the squat, at or near minimum knee angle
  bottom,

  /// Moving upward back to standing, knee angle increasing
  ascending,
}

/// Extension methods for SquatPhase
extension SquatPhaseExtension on SquatPhase {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case SquatPhase.standing:
        return 'Standing';
      case SquatPhase.descending:
        return 'Going Down';
      case SquatPhase.bottom:
        return 'Bottom';
      case SquatPhase.ascending:
        return 'Coming Up';
    }
  }

  /// Whether this phase is part of active movement
  bool get isActive =>
      this == SquatPhase.descending || this == SquatPhase.ascending;

  /// Whether this phase represents the lowest position
  bool get isBottom => this == SquatPhase.bottom;
}
