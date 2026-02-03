import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/motion/models/vector3.dart';

/// Represents the velocity of a tracked point (landmark or derived point).
///
/// Velocity is calculated as the change in position over time.
/// Units are in image-space units per second (pixels/second for x,y).
///
/// This model is exercise-agnostic - it measures movement speed
/// without knowledge of what movement is being performed.
class Velocity extends Equatable {
  /// The landmark or point ID this velocity refers to
  final int pointId;

  /// Velocity vector (units per second)
  final Vector3 velocity;

  /// Timestamp when this velocity was calculated (microseconds)
  final int timestampMicros;

  /// Time delta used for calculation (seconds)
  final double deltaTimeSeconds;

  /// Confidence of the velocity measurement
  /// Lower if based on low-confidence landmarks
  final double confidence;

  const Velocity({
    required this.pointId,
    required this.velocity,
    required this.timestampMicros,
    required this.deltaTimeSeconds,
    this.confidence = 1.0,
  });

  /// Speed (magnitude of velocity) in units per second
  double get speed => velocity.magnitude;

  /// 2D speed (ignoring Z component)
  double get speed2D => velocity.magnitude2D;

  /// Direction of movement (normalized velocity vector)
  Vector3 get direction => velocity.normalized;

  /// Check if the point is approximately stationary
  bool isStationary({double threshold = 5.0}) {
    return speed < threshold;
  }

  /// Check if movement is primarily in one direction
  bool isMovingUp({double threshold = 0.5}) => velocity.y < -threshold * speed;
  bool isMovingDown({double threshold = 0.5}) => velocity.y > threshold * speed;
  bool isMovingLeft({double threshold = 0.5}) => velocity.x < -threshold * speed;
  bool isMovingRight({double threshold = 0.5}) =>
      velocity.x > threshold * speed;
  bool isMovingForward({double threshold = 0.5}) =>
      velocity.z < -threshold * speed;
  bool isMovingBackward({double threshold = 0.5}) =>
      velocity.z > threshold * speed;

  /// Categorize movement speed
  VelocityCategory get category {
    if (speed < 50) return VelocityCategory.stationary;
    if (speed < 200) return VelocityCategory.slow;
    if (speed < 500) return VelocityCategory.moderate;
    if (speed < 1000) return VelocityCategory.fast;
    return VelocityCategory.veryFast;
  }

  /// Check if this is high confidence velocity
  bool get isHighConfidence => confidence >= 0.8;

  @override
  List<Object?> get props => [
        pointId,
        velocity,
        timestampMicros,
        deltaTimeSeconds,
        confidence,
      ];

  @override
  String toString() =>
      'Velocity(point $pointId: ${speed.toStringAsFixed(1)} units/s)';

  /// Convert to map for serialization
  Map<String, dynamic> toMap() => {
        'pointId': pointId,
        'velocity': velocity.toMap(),
        'timestampMicros': timestampMicros,
        'deltaTimeSeconds': deltaTimeSeconds,
        'confidence': confidence,
      };

  /// Create from map
  factory Velocity.fromMap(Map<String, dynamic> map) {
    return Velocity(
      pointId: map['pointId'] as int,
      velocity: Vector3.fromMap(map['velocity'] as Map<String, dynamic>),
      timestampMicros: map['timestampMicros'] as int,
      deltaTimeSeconds: (map['deltaTimeSeconds'] as num).toDouble(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Create a zero velocity
  factory Velocity.zero(int pointId, int timestampMicros) {
    return Velocity(
      pointId: pointId,
      velocity: Vector3.zero,
      timestampMicros: timestampMicros,
      deltaTimeSeconds: 0,
    );
  }
}

/// Categories for velocity magnitude
enum VelocityCategory {
  /// < 50 units/s - essentially not moving
  stationary,

  /// 50-200 units/s - slow deliberate movement
  slow,

  /// 200-500 units/s - normal movement speed
  moderate,

  /// 500-1000 units/s - quick movement
  fast,

  /// > 1000 units/s - very rapid movement
  veryFast,
}

/// Angular velocity for joint angle changes
class AngularVelocity extends Equatable {
  /// The joint ID this angular velocity refers to
  final String jointId;

  /// Angular velocity in radians per second
  final double radiansPerSecond;

  /// Timestamp when calculated
  final int timestampMicros;

  /// Time delta used for calculation
  final double deltaTimeSeconds;

  /// Confidence of the measurement
  final double confidence;

  const AngularVelocity({
    required this.jointId,
    required this.radiansPerSecond,
    required this.timestampMicros,
    required this.deltaTimeSeconds,
    this.confidence = 1.0,
  });

  /// Angular velocity in degrees per second
  double get degreesPerSecond => radiansPerSecond * 180 / 3.14159265359;

  /// Check if joint is approximately stationary
  bool isStationary({double threshold = 0.1}) {
    return radiansPerSecond.abs() < threshold;
  }

  /// Check if joint is flexing (angle decreasing)
  bool get isFlexing => radiansPerSecond < 0;

  /// Check if joint is extending (angle increasing)
  bool get isExtending => radiansPerSecond > 0;

  @override
  List<Object?> get props => [
        jointId,
        radiansPerSecond,
        timestampMicros,
        deltaTimeSeconds,
        confidence,
      ];

  @override
  String toString() =>
      'AngularVelocity($jointId: ${degreesPerSecond.toStringAsFixed(1)}°/s)';

  /// Convert to map for serialization
  Map<String, dynamic> toMap() => {
        'jointId': jointId,
        'radiansPerSecond': radiansPerSecond,
        'timestampMicros': timestampMicros,
        'deltaTimeSeconds': deltaTimeSeconds,
        'confidence': confidence,
      };

  /// Create from map
  factory AngularVelocity.fromMap(Map<String, dynamic> map) {
    return AngularVelocity(
      jointId: map['jointId'] as String,
      radiansPerSecond: (map['radiansPerSecond'] as num).toDouble(),
      timestampMicros: map['timestampMicros'] as int,
      deltaTimeSeconds: (map['deltaTimeSeconds'] as num).toDouble(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
