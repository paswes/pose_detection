/// A single pose landmark from ML Kit pose detection.
///
/// Maps to ML Kit's [PoseLandmark] with simplified types:
/// - [id] corresponds to [PoseLandmarkType] enum index (0-32)
/// - [likelihood] corresponds to [PoseLandmark.likelihood]
class Landmark {
  /// Landmark ID (0-32), corresponding to [PoseLandmarkType] enum index.
  /// Use [LandmarkSchema] constants for named access.
  final int id;

  /// X coordinate in image pixel space
  final double x;

  /// Y coordinate in image pixel space
  final double y;

  /// Z coordinate — depth perpendicular to camera plane.
  /// Origin is approximately the center point between the hips.
  /// Negative values = toward camera, positive = away from camera.
  /// Note: This is an experimental value per ML Kit docs.
  final double z;

  /// InFrameLikelihood (0.0 to 1.0).
  /// Indicates the probability that this landmark is within the image frame,
  /// NOT the accuracy of the detected position.
  final double likelihood;

  const Landmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  @override
  String toString() =>
      'Landmark($id: $x, $y, $z @ ${likelihood.toStringAsFixed(2)})';
}
