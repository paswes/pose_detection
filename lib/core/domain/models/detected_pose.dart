import 'dart:ui';

import 'package:pose_detection/core/domain/models/landmark.dart';

class DetectedPose {
  final List<Landmark> landmarks;
  final Size imageSize;
  final int timestampMicros;

  const DetectedPose({
    required this.landmarks,
    required this.imageSize,
    required this.timestampMicros,
  });

  double get avgLikelihood {
    if (landmarks.isEmpty) return 0.0;
    return landmarks.fold(0.0, (sum, l) => sum + l.likelihood) /
        landmarks.length;
  }

  int get landmarkCount => landmarks.length;
}
