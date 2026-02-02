/// Quality level based on confidence thresholds
enum RegionQuality {
  /// Confidence > 0.8
  excellent,

  /// Confidence > 0.6
  good,

  /// Confidence > 0.4
  acceptable,

  /// Confidence <= 0.4
  poor,
}

/// Represents a body region with aggregated confidence
class BodyRegion {
  /// Human-readable region name
  final String name;

  /// Average confidence across all landmarks in this region
  final double confidence;

  /// Landmark indices that belong to this region
  final List<int> landmarkIndices;

  const BodyRegion({
    required this.name,
    required this.confidence,
    required this.landmarkIndices,
  });

  /// Quality level based on confidence
  RegionQuality get quality {
    if (confidence > 0.8) return RegionQuality.excellent;
    if (confidence > 0.6) return RegionQuality.good;
    if (confidence > 0.4) return RegionQuality.acceptable;
    return RegionQuality.poor;
  }

  /// Human-readable quality label
  String get qualityLabel {
    switch (quality) {
      case RegionQuality.excellent:
        return 'Excellent';
      case RegionQuality.good:
        return 'Good';
      case RegionQuality.acceptable:
        return 'Acceptable';
      case RegionQuality.poor:
        return 'Poor';
    }
  }

  @override
  String toString() => 'BodyRegion($name: ${confidence.toStringAsFixed(2)})';
}

/// Complete body region breakdown
/// Divides the 33 landmarks into anatomical regions
class BodyRegionBreakdown {
  /// Head region: nose, eyes, ears, mouth (landmarks 0-10)
  final BodyRegion head;

  /// Upper body: shoulders, elbows, wrists, hands (landmarks 11-22)
  final BodyRegion upperBody;

  /// Core/torso: shoulders + hips forming the trunk (landmarks 11-12, 23-24)
  final BodyRegion core;

  /// Lower body: hips, knees, ankles, feet (landmarks 23-32)
  final BodyRegion lowerBody;

  /// Timestamp of this breakdown (microseconds)
  final int timestampMicros;

  const BodyRegionBreakdown({
    required this.head,
    required this.upperBody,
    required this.core,
    required this.lowerBody,
    required this.timestampMicros,
  });

  /// Average confidence across all regions
  double get overallConfidence =>
      (head.confidence + upperBody.confidence + core.confidence + lowerBody.confidence) / 4;

  /// List of all regions for iteration
  List<BodyRegion> get allRegions => [head, upperBody, core, lowerBody];

  /// Region with lowest confidence (likely needs attention)
  BodyRegion get weakestRegion {
    return allRegions.reduce((a, b) => a.confidence < b.confidence ? a : b);
  }

  /// Region with highest confidence
  BodyRegion get strongestRegion {
    return allRegions.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  /// Empty breakdown for initial state
  static const empty = BodyRegionBreakdown(
    head: BodyRegion(name: 'Head', confidence: 0, landmarkIndices: []),
    upperBody: BodyRegion(name: 'Upper Body', confidence: 0, landmarkIndices: []),
    core: BodyRegion(name: 'Core', confidence: 0, landmarkIndices: []),
    lowerBody: BodyRegion(name: 'Lower Body', confidence: 0, landmarkIndices: []),
    timestampMicros: 0,
  );
}
