import 'dart:ui';

import 'package:pose_detection/domain/models/landmark.dart';

/// A detected pose from a single frame.
/// Minimal model containing only what's needed for rendering and metrics.
class DetectedPose {
  /// All landmarks from ML Kit (33 for full body)
  final List<Landmark> landmarks;

  /// Image dimensions at detection time
  final Size imageSize;

  /// Timestamp when pose was detected (microseconds since epoch)
  final int timestampMicros;

  const DetectedPose({
    required this.landmarks,
    required this.imageSize,
    required this.timestampMicros,
  });

  /// Average confidence across all landmarks
  double get avgConfidence {
    if (landmarks.isEmpty) return 0.0;
    return landmarks.fold(0.0, (sum, l) => sum + l.confidence) /
        landmarks.length;
  }

  /// Number of landmarks
  int get landmarkCount => landmarks.length;

  /// Count of landmarks with confidence above a threshold
  int highConfidenceLandmarksCount({double threshold = 0.8}) =>
      landmarks.where((l) => l.confidence > threshold).length;

  /// Count of landmarks with confidence below a threshold
  int lowConfidenceLandmarksCount({double threshold = 0.5}) =>
      landmarks.where((l) => l.confidence < threshold).length;

  /// Legacy getters for backwards compatibility (using default thresholds)
  int get highConfidenceLandmarks => highConfidenceLandmarksCount();
  int get lowConfidenceLandmarks => lowConfidenceLandmarksCount();

  /// Get a landmark by its ID, returns null if not found
  Landmark? getLandmarkById(int id) {
    return landmarks.where((l) => l.id == id).firstOrNull;
  }

  /// Get landmarks by their IDs
  List<Landmark> getLandmarksByIds(List<int> ids) {
    return landmarks.where((l) => ids.contains(l.id)).toList();
  }

  /// Check if all specified landmarks have sufficient confidence
  bool hasConfidentLandmarks(List<int> ids, {double minConfidence = 0.5}) {
    for (final id in ids) {
      final landmark = getLandmarkById(id);
      if (landmark == null || landmark.confidence < minConfidence) {
        return false;
      }
    }
    return true;
  }

  /// Get landmarks filtered by minimum confidence
  List<Landmark> getConfidentLandmarks({double minConfidence = 0.5}) {
    return landmarks.where((l) => l.confidence >= minConfidence).toList();
  }

  /// Calculate the bounding box of all confident landmarks
  Rect? getBoundingBox({double minConfidence = 0.5}) {
    final confident = getConfidentLandmarks(minConfidence: minConfidence);
    if (confident.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final landmark in confident) {
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y > maxY) maxY = landmark.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculate the center of mass (average position of all confident landmarks)
  Offset? getCenterOfMass({double minConfidence = 0.5}) {
    final confident = getConfidentLandmarks(minConfidence: minConfidence);
    if (confident.isEmpty) return null;

    double sumX = 0;
    double sumY = 0;

    for (final landmark in confident) {
      sumX += landmark.x;
      sumY += landmark.y;
    }

    return Offset(sumX / confident.length, sumY / confident.length);
  }

  /// Create a copy with filtered landmarks
  DetectedPose copyWithFilteredLandmarks({double minConfidence = 0.5}) {
    return DetectedPose(
      landmarks: getConfidentLandmarks(minConfidence: minConfidence),
      imageSize: imageSize,
      timestampMicros: timestampMicros,
    );
  }

  /// Timestamp in seconds
  double get timestampSeconds => timestampMicros / 1000000.0;

  /// Timestamp in milliseconds
  double get timestampMs => timestampMicros / 1000.0;

  @override
  String toString() =>
      'DetectedPose(${landmarks.length} landmarks, confidence: ${avgConfidence.toStringAsFixed(2)})';
}
