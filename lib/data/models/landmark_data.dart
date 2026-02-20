import 'package:pose_detection/domain/models/landmark.dart';

/// Lightweight landmark model for storage/serialization.
///
/// Maps 1:1 to [Landmark] but adds JSON serialization.
/// JSON key `'c'` stores [likelihood] (ML Kit's inFrameLikelihood).
class LandmarkData {
  final int id;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const LandmarkData({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  factory LandmarkData.fromLandmark(Landmark landmark) {
    return LandmarkData(
      id: landmark.id,
      x: landmark.x,
      y: landmark.y,
      z: landmark.z,
      likelihood: landmark.likelihood,
    );
  }

  Landmark toLandmark() {
    return Landmark(id: id, x: x, y: y, z: z, likelihood: likelihood);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'z': z,
    'c': likelihood,
  };

  factory LandmarkData.fromJson(Map<String, dynamic> json) {
    return LandmarkData(
      id: json['id'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      likelihood: (json['c'] as num).toDouble(),
    );
  }
}
