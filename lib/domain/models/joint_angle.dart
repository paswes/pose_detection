/// Anatomical joints for angle calculation
/// Based on ML Kit 33-landmark model indices
enum AnatomicalJoint {
  // Arms
  leftElbow,
  rightElbow,
  leftShoulder,
  rightShoulder,

  // Hips
  leftHip,
  rightHip,

  // Legs
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// Represents a calculated joint angle at a specific moment
class JointAngle {
  /// Which anatomical joint this angle represents
  final AnatomicalJoint joint;

  /// Angle in degrees (0-180)
  final double angleDegrees;

  /// Minimum confidence across the three landmarks used
  final double confidence;

  /// Timestamp when this angle was calculated (microseconds)
  final int timestampMicros;

  /// The three landmark IDs used: (proximal, vertex, distal)
  /// The angle is measured at the vertex
  final (int, int, int) landmarkIds;

  const JointAngle({
    required this.joint,
    required this.angleDegrees,
    required this.confidence,
    required this.timestampMicros,
    required this.landmarkIds,
  });

  /// Human-readable joint name
  String get jointName {
    switch (joint) {
      case AnatomicalJoint.leftElbow:
        return 'Left Elbow';
      case AnatomicalJoint.rightElbow:
        return 'Right Elbow';
      case AnatomicalJoint.leftShoulder:
        return 'Left Shoulder';
      case AnatomicalJoint.rightShoulder:
        return 'Right Shoulder';
      case AnatomicalJoint.leftHip:
        return 'Left Hip';
      case AnatomicalJoint.rightHip:
        return 'Right Hip';
      case AnatomicalJoint.leftKnee:
        return 'Left Knee';
      case AnatomicalJoint.rightKnee:
        return 'Right Knee';
      case AnatomicalJoint.leftAnkle:
        return 'Left Ankle';
      case AnatomicalJoint.rightAnkle:
        return 'Right Ankle';
    }
  }

  /// Short label for compact display
  String get shortLabel {
    switch (joint) {
      case AnatomicalJoint.leftElbow:
        return 'L.Elbow';
      case AnatomicalJoint.rightElbow:
        return 'R.Elbow';
      case AnatomicalJoint.leftShoulder:
        return 'L.Shoulder';
      case AnatomicalJoint.rightShoulder:
        return 'R.Shoulder';
      case AnatomicalJoint.leftHip:
        return 'L.Hip';
      case AnatomicalJoint.rightHip:
        return 'R.Hip';
      case AnatomicalJoint.leftKnee:
        return 'L.Knee';
      case AnatomicalJoint.rightKnee:
        return 'R.Knee';
      case AnatomicalJoint.leftAnkle:
        return 'L.Ankle';
      case AnatomicalJoint.rightAnkle:
        return 'R.Ankle';
    }
  }

  @override
  String toString() =>
      'JointAngle($jointName: ${angleDegrees.toStringAsFixed(1)}°, conf: ${confidence.toStringAsFixed(2)})';
}
