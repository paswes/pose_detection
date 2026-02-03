import 'package:equatable/equatable.dart';

/// Represents a body segment (distance between two landmarks).
/// Generic model for any limb or body part measurement.
class BodySegment extends Equatable {
  /// Identifier for the segment (e.g., 'left_upper_arm', 'right_thigh')
  final String segmentId;

  /// Length in image space (pixels)
  final double length;

  /// Confidence score derived from endpoint landmarks [0.0, 1.0]
  final double confidence;

  /// Timestamp when this segment was calculated (microseconds)
  final int timestampMicros;

  const BodySegment({
    required this.segmentId,
    required this.length,
    required this.confidence,
    required this.timestampMicros,
  });

  /// Whether this measurement is considered reliable.
  bool get isReliable => confidence >= 0.5;

  @override
  List<Object?> get props => [segmentId, length, confidence, timestampMicros];

  @override
  String toString() =>
      'BodySegment($segmentId: ${length.toStringAsFixed(1)}px @ ${confidence.toStringAsFixed(2)})';
}

/// Common segment identifiers for consistency across the app.
/// These are suggestions - callers can use any string identifier.
abstract class SegmentIds {
  // Arms
  static const leftUpperArm = 'left_upper_arm';
  static const rightUpperArm = 'right_upper_arm';
  static const leftForearm = 'left_forearm';
  static const rightForearm = 'right_forearm';

  // Legs
  static const leftThigh = 'left_thigh';
  static const rightThigh = 'right_thigh';
  static const leftShin = 'left_shin';
  static const rightShin = 'right_shin';

  // Torso
  static const shoulders = 'shoulders'; // Shoulder to shoulder
  static const hips = 'hips'; // Hip to hip
  static const torsoLeft = 'torso_left'; // Left shoulder to left hip
  static const torsoRight = 'torso_right'; // Right shoulder to right hip
  static const spine = 'spine'; // Neck to hip midpoint
}
