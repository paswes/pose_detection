import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/models/landmark_type.dart';

/// Represents an angle formed by three landmarks (joint angle).
///
/// The angle is measured at the middle landmark (vertex), with the first
/// and third landmarks forming the two rays of the angle.
///
/// Example: For elbow angle, use BodyJoint.leftElbow
/// - first: LandmarkType.leftShoulder
/// - vertex: LandmarkType.leftElbow (where angle is measured)
/// - third: LandmarkType.leftWrist
///
/// This model is exercise-agnostic - it simply represents geometric angles.
class JointAngle extends Equatable {
  /// The body joint this angle represents (if using semantic joints)
  final BodyJoint? bodyJoint;

  /// ID of the first landmark (start of first ray)
  final int firstLandmarkId;

  /// ID of the vertex landmark (where angle is measured)
  final int vertexLandmarkId;

  /// ID of the third landmark (end of second ray)
  final int thirdLandmarkId;

  /// The angle in radians (0 to π)
  final double radians;

  /// Timestamp when this angle was calculated (microseconds)
  final int timestampMicros;

  /// Average confidence of the three landmarks used
  final double confidence;

  const JointAngle({
    this.bodyJoint,
    required this.firstLandmarkId,
    required this.vertexLandmarkId,
    required this.thirdLandmarkId,
    required this.radians,
    required this.timestampMicros,
    this.confidence = 1.0,
  });

  /// Create a JointAngle from a BodyJoint definition
  factory JointAngle.fromBodyJoint({
    required BodyJoint joint,
    required double radians,
    required int timestampMicros,
    double confidence = 1.0,
  }) {
    return JointAngle(
      bodyJoint: joint,
      firstLandmarkId: joint.first.id,
      vertexLandmarkId: joint.vertex.id,
      thirdLandmarkId: joint.third.id,
      radians: radians,
      timestampMicros: timestampMicros,
      confidence: confidence,
    );
  }

  /// Angle in degrees (0 to 180)
  double get degrees => radians * 180 / math.pi;

  /// Normalized angle (0.0 to 1.0, where 0 = fully flexed, 1 = fully extended)
  /// This is a simple linear mapping from 0-180 degrees.
  double get normalized => degrees / 180.0;

  /// Get the first landmark as LandmarkType (if valid ID)
  LandmarkType? get firstLandmark => LandmarkType.fromId(firstLandmarkId);

  /// Get the vertex landmark as LandmarkType (if valid ID)
  LandmarkType? get vertexLandmark => LandmarkType.fromId(vertexLandmarkId);

  /// Get the third landmark as LandmarkType (if valid ID)
  LandmarkType? get thirdLandmark => LandmarkType.fromId(thirdLandmarkId);

  /// Check if the angle is approximately equal to another angle.
  /// [tolerance] is in radians.
  bool isApproximately(double targetRadians, {double tolerance = 0.1}) {
    return (radians - targetRadians).abs() <= tolerance;
  }

  /// Check if the angle is approximately equal to another angle in degrees.
  bool isApproximatelyDegrees(double targetDegrees, {double tolerance = 5.0}) {
    return (degrees - targetDegrees).abs() <= tolerance;
  }

  /// Check if the angle is within a range (in radians)
  bool isInRange(double minRadians, double maxRadians) {
    return radians >= minRadians && radians <= maxRadians;
  }

  /// Check if the angle is within a range (in degrees)
  bool isInRangeDegrees(double minDegrees, double maxDegrees) {
    return degrees >= minDegrees && degrees <= maxDegrees;
  }

  /// Check if this is considered "high confidence" (all landmarks reliable)
  bool get isHighConfidence => confidence >= 0.8;

  /// Create a unique identifier for this joint angle configuration
  String get jointId =>
      '${firstLandmarkId}_${vertexLandmarkId}_$thirdLandmarkId';

  /// Human-readable description of the joint
  String get displayName {
    if (bodyJoint != null) {
      return bodyJoint!.displayName;
    }
    final first = firstLandmark?.displayName ?? 'Point $firstLandmarkId';
    final vertex = vertexLandmark?.displayName ?? 'Point $vertexLandmarkId';
    final third = thirdLandmark?.displayName ?? 'Point $thirdLandmarkId';
    return '$first → $vertex → $third';
  }

  /// Copy with a new angle value
  JointAngle copyWithAngle(double newRadians, int newTimestamp) {
    return JointAngle(
      bodyJoint: bodyJoint,
      firstLandmarkId: firstLandmarkId,
      vertexLandmarkId: vertexLandmarkId,
      thirdLandmarkId: thirdLandmarkId,
      radians: newRadians,
      timestampMicros: newTimestamp,
      confidence: confidence,
    );
  }

  @override
  List<Object?> get props => [
        bodyJoint,
        firstLandmarkId,
        vertexLandmarkId,
        thirdLandmarkId,
        radians,
        timestampMicros,
        confidence,
      ];

  @override
  String toString() {
    final name = bodyJoint?.displayName ?? jointId;
    return 'JointAngle($name: ${degrees.toStringAsFixed(1)}° @ confidence ${confidence.toStringAsFixed(2)})';
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() => {
        'bodyJoint': bodyJoint?.name,
        'firstLandmarkId': firstLandmarkId,
        'vertexLandmarkId': vertexLandmarkId,
        'thirdLandmarkId': thirdLandmarkId,
        'radians': radians,
        'timestampMicros': timestampMicros,
        'confidence': confidence,
      };

  /// Create from map
  factory JointAngle.fromMap(Map<String, dynamic> map) {
    final bodyJointName = map['bodyJoint'] as String?;
    final bodyJoint = bodyJointName != null
        ? BodyJoint.values.where((j) => j.name == bodyJointName).firstOrNull
        : null;

    return JointAngle(
      bodyJoint: bodyJoint,
      firstLandmarkId: map['firstLandmarkId'] as int,
      vertexLandmarkId: map['vertexLandmarkId'] as int,
      thirdLandmarkId: map['thirdLandmarkId'] as int,
      radians: (map['radians'] as num).toDouble(),
      timestampMicros: map['timestampMicros'] as int,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
