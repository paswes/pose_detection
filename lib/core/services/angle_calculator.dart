import 'dart:math' as math;

import 'package:pose_detection/core/config/inspection_config.dart';
import 'package:pose_detection/core/interfaces/angle_calculator_interface.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/joint_angle.dart';

/// Calculates joint angles from pose landmarks
class AngleCalculator implements IAngleCalculator {
  final InspectionConfig _config;

  /// Landmark index mapping for joint triplets
  /// Based on ML Kit 33-landmark schema:
  /// 11: Left Shoulder, 12: Right Shoulder
  /// 13: Left Elbow, 14: Right Elbow
  /// 15: Left Wrist, 16: Right Wrist
  /// 23: Left Hip, 24: Right Hip
  /// 25: Left Knee, 26: Right Knee
  /// 27: Left Ankle, 28: Right Ankle
  /// 31: Left Foot Index, 32: Right Foot Index
  static const _jointTriplets = <AnatomicalJoint, (int, int, int)>{
    // Arms: (shoulder, elbow, wrist)
    AnatomicalJoint.leftElbow: (11, 13, 15),
    AnatomicalJoint.rightElbow: (12, 14, 16),

    // Shoulders: (elbow, shoulder, hip)
    AnatomicalJoint.leftShoulder: (13, 11, 23),
    AnatomicalJoint.rightShoulder: (14, 12, 24),

    // Hips: (shoulder, hip, knee)
    AnatomicalJoint.leftHip: (11, 23, 25),
    AnatomicalJoint.rightHip: (12, 24, 26),

    // Knees: (hip, knee, ankle)
    AnatomicalJoint.leftKnee: (23, 25, 27),
    AnatomicalJoint.rightKnee: (24, 26, 28),

    // Ankles: (knee, ankle, foot index)
    AnatomicalJoint.leftAnkle: (25, 27, 31),
    AnatomicalJoint.rightAnkle: (26, 28, 32),
  };

  AngleCalculator({InspectionConfig? config})
      : _config = config ?? InspectionConfig.defaultConfig;

  @override
  (int, int, int) getLandmarkTriplet(AnatomicalJoint joint) {
    return _jointTriplets[joint] ?? (0, 0, 0);
  }

  @override
  JointAngle? calculateAngle(AnatomicalJoint joint, TimestampedPose pose) {
    final triplet = _jointTriplets[joint];
    if (triplet == null) return null;

    final (proximalIdx, vertexIdx, distalIdx) = triplet;

    // Get normalized landmarks for resolution-independence
    final landmarks = pose.normalizedLandmarks;
    final maxIdx = math.max(proximalIdx, math.max(vertexIdx, distalIdx));
    if (landmarks.length <= maxIdx) {
      return null;
    }

    final proximal = landmarks[proximalIdx];
    final vertex = landmarks[vertexIdx];
    final distal = landmarks[distalIdx];

    // Check confidence threshold for all three landmarks
    final minConfidence = math.min(
      proximal.likelihood,
      math.min(vertex.likelihood, distal.likelihood),
    );
    if (minConfidence < _config.minConfidenceForAngle) {
      return null;
    }

    // Calculate angle using 2D vectors (normalized X/Y)
    final angle = _calculate2DAngle(
      proximal.x,
      proximal.y,
      vertex.x,
      vertex.y,
      distal.x,
      distal.y,
    );

    return JointAngle(
      joint: joint,
      angleDegrees: angle,
      confidence: minConfidence,
      timestampMicros: pose.timestampMicros,
      landmarkIds: (proximalIdx, vertexIdx, distalIdx),
    );
  }

  @override
  List<JointAngle> calculateAllAngles(TimestampedPose pose) {
    final angles = <JointAngle>[];
    for (final joint in AnatomicalJoint.values) {
      final angle = calculateAngle(joint, pose);
      if (angle != null) {
        angles.add(angle);
      }
    }
    return angles;
  }

  /// Calculate angle at vertex using dot product formula
  /// Returns angle in degrees (0-180)
  double _calculate2DAngle(
    double ax,
    double ay, // proximal point
    double bx,
    double by, // vertex point (angle measured here)
    double cx,
    double cy, // distal point
  ) {
    // Vector BA (from vertex to proximal)
    final bax = ax - bx;
    final bay = ay - by;

    // Vector BC (from vertex to distal)
    final bcx = cx - bx;
    final bcy = cy - by;

    // Dot product: BA · BC
    final dot = bax * bcx + bay * bcy;

    // Magnitudes
    final magBA = math.sqrt(bax * bax + bay * bay);
    final magBC = math.sqrt(bcx * bcx + bcy * bcy);

    // Handle degenerate case (points too close)
    if (magBA < 0.0001 || magBC < 0.0001) {
      return 0.0;
    }

    // Clamp to avoid acos domain errors from floating point
    final cosAngle = (dot / (magBA * magBC)).clamp(-1.0, 1.0);

    // Convert to degrees
    return math.acos(cosAngle) * (180.0 / math.pi);
  }
}
