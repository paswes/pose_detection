import 'package:equatable/equatable.dart';

/// Represents a calculated angle at a joint.
/// Generic model for any joint angle measurement.
class JointAngle extends Equatable {
  /// Identifier for the joint (e.g., 'left_elbow', 'right_knee')
  final String jointId;

  /// Angle in degrees [0, 180]
  final double degrees;

  /// Confidence score derived from contributing landmarks [0.0, 1.0]
  final double confidence;

  /// Timestamp when this angle was calculated (microseconds)
  final int timestampMicros;

  const JointAngle({
    required this.jointId,
    required this.degrees,
    required this.confidence,
    required this.timestampMicros,
  });

  /// Whether this angle measurement is considered reliable.
  bool get isReliable => confidence >= 0.5;

  /// Angle in radians.
  double get radians => degrees * 3.141592653589793 / 180;

  @override
  List<Object?> get props => [jointId, degrees, confidence, timestampMicros];

  @override
  String toString() =>
      'JointAngle($jointId: ${degrees.toStringAsFixed(1)}° @ ${confidence.toStringAsFixed(2)})';
}

/// Common joint identifiers for consistency across the app.
/// These are suggestions - callers can use any string identifier.
abstract class JointIds {
  // Arms
  static const leftShoulder = 'left_shoulder';
  static const rightShoulder = 'right_shoulder';
  static const leftElbow = 'left_elbow';
  static const rightElbow = 'right_elbow';
  static const leftWrist = 'left_wrist';
  static const rightWrist = 'right_wrist';

  // Legs
  static const leftHip = 'left_hip';
  static const rightHip = 'right_hip';
  static const leftKnee = 'left_knee';
  static const rightKnee = 'right_knee';
  static const leftAnkle = 'left_ankle';
  static const rightAnkle = 'right_ankle';

  // Torso
  static const neck = 'neck';
  static const spine = 'spine';
}
