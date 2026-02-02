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

  /// Count of landmarks with confidence > 0.8
  int get highConfidenceLandmarks =>
      landmarks.where((l) => l.confidence > 0.8).length;

  /// Count of landmarks with confidence < 0.5
  int get lowConfidenceLandmarks =>
      landmarks.where((l) => l.confidence < 0.5).length;
}
