import 'package:pose_detection/domain/models/landmark.dart';

/// Lightweight landmark model for storage/serialization.
class LandmarkData {
  final int id;
  final double x;
  final double y;
  final double z;
  final double confidence;

  const LandmarkData({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  factory LandmarkData.fromLandmark(Landmark landmark) {
    return LandmarkData(
      id: landmark.id,
      x: landmark.x,
      y: landmark.y,
      z: landmark.z,
      confidence: landmark.confidence,
    );
  }

  Landmark toLandmark() {
    return Landmark(id: id, x: x, y: y, z: z, confidence: confidence);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'z': z,
    'c': confidence,
  };

  factory LandmarkData.fromJson(Map<String, dynamic> json) {
    return LandmarkData(
      id: json['id'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      confidence: (json['c'] as num).toDouble(),
    );
  }
}
