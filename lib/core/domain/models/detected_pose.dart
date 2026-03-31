import 'dart:ui';

import 'package:pose_detection/core/domain/models/landmark.dart';

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

  /// Average inFrameLikelihood across all landmarks
  double get avgLikelihood {
    if (landmarks.isEmpty) return 0.0;
    return landmarks.fold(0.0, (sum, l) => sum + l.likelihood) /
        landmarks.length;
  }

  /// Number of landmarks
  int get landmarkCount => landmarks.length;

}
