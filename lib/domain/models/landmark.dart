/// A single landmark from ML Kit pose detection.
/// Contains only essential data for rendering and analysis.
class Landmark {
  /// Landmark ID (0-32 for ML Kit's 33 body landmarks)
  final int id;

  /// X coordinate in image space (pixels)
  final double x;

  /// Y coordinate in image space (pixels)
  final double y;

  /// Z coordinate - depth relative to hip midpoint
  final double z;

  /// ML model confidence (0.0 to 1.0)
  final double confidence;

  const Landmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  @override
  String toString() =>
      'Landmark($id: $x, $y, $z @ ${confidence.toStringAsFixed(2)})';
}
