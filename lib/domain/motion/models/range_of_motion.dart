import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Represents the range of motion (ROM) for a joint over a time period.
///
/// ROM is tracked as the minimum and maximum angles observed for a joint.
/// This is exercise-agnostic - it simply measures how much a joint moves
/// without knowledge of what exercise is being performed.
class RangeOfMotion extends Equatable {
  /// The joint ID (format: "first_vertex_third")
  final String jointId;

  /// Minimum angle observed (radians)
  final double minRadians;

  /// Maximum angle observed (radians)
  final double maxRadians;

  /// Timestamp when tracking started (microseconds)
  final int startTimestampMicros;

  /// Timestamp of last update (microseconds)
  final int lastUpdateTimestampMicros;

  /// Number of samples used to calculate this ROM
  final int sampleCount;

  /// Average confidence across all samples
  final double averageConfidence;

  const RangeOfMotion({
    required this.jointId,
    required this.minRadians,
    required this.maxRadians,
    required this.startTimestampMicros,
    required this.lastUpdateTimestampMicros,
    this.sampleCount = 1,
    this.averageConfidence = 1.0,
  });

  /// Create initial ROM from a single angle measurement
  factory RangeOfMotion.initial({
    required String jointId,
    required double radians,
    required int timestampMicros,
    double confidence = 1.0,
  }) {
    return RangeOfMotion(
      jointId: jointId,
      minRadians: radians,
      maxRadians: radians,
      startTimestampMicros: timestampMicros,
      lastUpdateTimestampMicros: timestampMicros,
      sampleCount: 1,
      averageConfidence: confidence,
    );
  }

  /// Range of motion in radians
  double get rangeRadians => maxRadians - minRadians;

  /// Range of motion in degrees
  double get rangeDegrees => rangeRadians * 180 / math.pi;

  /// Minimum angle in degrees
  double get minDegrees => minRadians * 180 / math.pi;

  /// Maximum angle in degrees
  double get maxDegrees => maxRadians * 180 / math.pi;

  /// Midpoint of the range (radians)
  double get midpointRadians => (minRadians + maxRadians) / 2;

  /// Midpoint of the range (degrees)
  double get midpointDegrees => midpointRadians * 180 / math.pi;

  /// Duration of tracking (microseconds)
  int get durationMicros => lastUpdateTimestampMicros - startTimestampMicros;

  /// Duration of tracking (seconds)
  double get durationSeconds => durationMicros / 1000000.0;

  /// Sample rate (samples per second)
  double get sampleRate {
    if (durationSeconds <= 0) return 0;
    return sampleCount / durationSeconds;
  }

  /// Check if this ROM has meaningful data (more than one sample)
  bool get hasMeaningfulData => sampleCount > 1 && rangeRadians > 0.01;

  /// Check if this is high confidence ROM
  bool get isHighConfidence => averageConfidence >= 0.8;

  /// Categorize the range of motion
  RangeOfMotionCategory get category {
    final degrees = rangeDegrees;
    if (degrees < 10) return RangeOfMotionCategory.minimal;
    if (degrees < 30) return RangeOfMotionCategory.limited;
    if (degrees < 60) return RangeOfMotionCategory.moderate;
    if (degrees < 90) return RangeOfMotionCategory.good;
    return RangeOfMotionCategory.full;
  }

  /// Update ROM with a new angle measurement
  RangeOfMotion update({
    required double radians,
    required int timestampMicros,
    required double confidence,
  }) {
    // Running average for confidence
    final newAvgConfidence =
        (averageConfidence * sampleCount + confidence) / (sampleCount + 1);

    return RangeOfMotion(
      jointId: jointId,
      minRadians: math.min(minRadians, radians),
      maxRadians: math.max(maxRadians, radians),
      startTimestampMicros: startTimestampMicros,
      lastUpdateTimestampMicros: timestampMicros,
      sampleCount: sampleCount + 1,
      averageConfidence: newAvgConfidence,
    );
  }

  /// Check if an angle is within this ROM
  bool contains(double radians) {
    return radians >= minRadians && radians <= maxRadians;
  }

  /// Get the position of an angle within this ROM (0.0 = min, 1.0 = max)
  double normalizedPosition(double radians) {
    if (rangeRadians <= 0) return 0.5;
    return (radians - minRadians) / rangeRadians;
  }

  /// Merge with another ROM (union of ranges)
  RangeOfMotion merge(RangeOfMotion other) {
    if (jointId != other.jointId) {
      throw ArgumentError('Cannot merge ROM from different joints');
    }

    final totalSamples = sampleCount + other.sampleCount;
    final mergedConfidence = totalSamples > 0
        ? (averageConfidence * sampleCount +
                other.averageConfidence * other.sampleCount) /
            totalSamples
        : 0.0;

    return RangeOfMotion(
      jointId: jointId,
      minRadians: math.min(minRadians, other.minRadians),
      maxRadians: math.max(maxRadians, other.maxRadians),
      startTimestampMicros:
          math.min(startTimestampMicros, other.startTimestampMicros),
      lastUpdateTimestampMicros:
          math.max(lastUpdateTimestampMicros, other.lastUpdateTimestampMicros),
      sampleCount: totalSamples,
      averageConfidence: mergedConfidence,
    );
  }

  @override
  List<Object?> get props => [
        jointId,
        minRadians,
        maxRadians,
        startTimestampMicros,
        lastUpdateTimestampMicros,
        sampleCount,
        averageConfidence,
      ];

  @override
  String toString() =>
      'RangeOfMotion($jointId: ${minDegrees.toStringAsFixed(1)}° - ${maxDegrees.toStringAsFixed(1)}° = ${rangeDegrees.toStringAsFixed(1)}°)';

  /// Convert to map for serialization
  Map<String, dynamic> toMap() => {
        'jointId': jointId,
        'minRadians': minRadians,
        'maxRadians': maxRadians,
        'startTimestampMicros': startTimestampMicros,
        'lastUpdateTimestampMicros': lastUpdateTimestampMicros,
        'sampleCount': sampleCount,
        'averageConfidence': averageConfidence,
      };

  /// Create from map
  factory RangeOfMotion.fromMap(Map<String, dynamic> map) {
    return RangeOfMotion(
      jointId: map['jointId'] as String,
      minRadians: (map['minRadians'] as num).toDouble(),
      maxRadians: (map['maxRadians'] as num).toDouble(),
      startTimestampMicros: map['startTimestampMicros'] as int,
      lastUpdateTimestampMicros: map['lastUpdateTimestampMicros'] as int,
      sampleCount: map['sampleCount'] as int? ?? 1,
      averageConfidence: (map['averageConfidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Categories for range of motion
enum RangeOfMotionCategory {
  /// < 10° - essentially static
  minimal,

  /// 10-30° - limited movement
  limited,

  /// 30-60° - moderate movement
  moderate,

  /// 60-90° - good range
  good,

  /// > 90° - full range movement
  full,
}
