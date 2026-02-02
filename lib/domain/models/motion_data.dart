/// Raw landmark in image coordinate space (pixels)
class RawLandmark {
  /// Landmark ID (0-32 for 33 body landmarks)
  final int id;

  /// X coordinate in image space (pixels)
  final double x;

  /// Y coordinate in image space (pixels)
  final double y;

  /// Z coordinate - depth relative to hip midpoint
  /// ML Kit's Z is a scaled depth estimate (NOT in pixels)
  /// Negative values: landmark is in front of hip
  /// Positive values: landmark is behind hip
  /// Note: Scale is approximately similar to X/Y pixel scale but represents depth
  final double z;

  /// ML model confidence (0.0 to 1.0)
  final double likelihood;

  const RawLandmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  @override
  String toString() => 'RawLandmark(id: $id, x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, likelihood: ${likelihood.toStringAsFixed(4)})';
}

/// Normalized landmark in resolution-independent space (0.0 to 1.0)
/// This allows motion analysis across different devices and resolutions
class NormalizedLandmark {
  /// Landmark ID (0-32 for 33 body landmarks)
  final int id;

  /// X coordinate normalized (0.0 = left edge, 1.0 = right edge)
  final double x;

  /// Y coordinate normalized (0.0 = top edge, 1.0 = bottom edge)
  final double y;

  /// Z coordinate - depth relative to hip midpoint (intentionally NOT normalized)
  /// Preserves the raw Z value from ML Kit (scaled depth estimate, not pixels)
  /// WARNING: Z has different units than normalized X/Y
  /// - X/Y are in 0.0-1.0 range (resolution-independent)
  /// - Z is a raw depth estimate for relative comparisons only
  final double z;

  /// ML model confidence (0.0 to 1.0)
  final double likelihood;

  const NormalizedLandmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  @override
  String toString() => 'NormalizedLandmark(id: $id, x: ${x.toStringAsFixed(4)}, y: ${y.toStringAsFixed(4)}, z: ${z.toStringAsFixed(2)}, likelihood: ${likelihood.toStringAsFixed(4)})';
}

/// Complete pose snapshot with temporal context
/// This is the atomic unit of the motion data stream
class TimestampedPose {
  /// Raw landmarks in image coordinate space
  final List<RawLandmark> landmarks;

  /// Normalized landmarks (resolution-independent)
  final List<NormalizedLandmark> normalizedLandmarks;

  /// Sequential frame index in the capture session
  final int frameIndex;

  /// Camera image timestamp in microseconds
  /// This is the authoritative temporal reference for motion analysis
  /// Uses sensor timestamp from CameraImage for accurate temporal consistency
  final int timestampMicros;

  /// Time delta from previous frame in microseconds
  /// Null for the first frame in a session
  /// Critical for accurate velocity and acceleration calculations
  final int? deltaTimeMicros;

  /// System time when pose was detected (for debugging/logging)
  final DateTime systemTime;

  /// Image dimensions at capture time
  final double imageWidth;
  final double imageHeight;

  const TimestampedPose({
    required this.landmarks,
    required this.normalizedLandmarks,
    required this.frameIndex,
    required this.timestampMicros,
    this.deltaTimeMicros,
    required this.systemTime,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Duration since epoch in microseconds (for velocity calculations)
  int get timeMicros => timestampMicros;

  /// Number of landmarks (should always be 33 for full body)
  int get landmarkCount => landmarks.length;

  /// Average confidence across all landmarks
  double get avgConfidence {
    if (landmarks.isEmpty) return 0.0;
    final sum = landmarks.fold(0.0, (acc, l) => acc + l.likelihood);
    return sum / landmarks.length;
  }

  /// Count of landmarks with high confidence (>0.8)
  int get highConfidenceLandmarks =>
      landmarks.where((l) => l.likelihood > 0.8).length;

  /// Count of landmarks with low confidence (<0.5)
  int get lowConfidenceLandmarks =>
      landmarks.where((l) => l.likelihood < 0.5).length;

  @override
  String toString() => 'TimestampedPose(frame: $frameIndex, time: $timestampMicros μs, delta: ${deltaTimeMicros != null ? '$deltaTimeMicros μs' : 'N/A'}, landmarks: ${landmarks.length}, size: ${imageWidth}x$imageHeight)';
}
