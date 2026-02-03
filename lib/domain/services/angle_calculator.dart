import 'package:pose_detection/core/utils/geometry_calculator.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/joint_angle.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// ML Kit landmark indices for joint angle calculations.
abstract class LandmarkIndex {
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;
}

/// Definition of a joint angle: which 3 landmarks form the angle.
class JointAngleDefinition {
  final String jointId;
  final int landmarkA; // First point
  final int landmarkB; // Vertex (angle is measured here)
  final int landmarkC; // Third point

  const JointAngleDefinition({
    required this.jointId,
    required this.landmarkA,
    required this.landmarkB,
    required this.landmarkC,
  });
}

/// Calculates joint angles from pose landmarks.
/// Stateless service - call methods directly.
class AngleCalculator {
  /// Standard joint angle definitions for common body joints.
  static const standardJoints = [
    // Arms - angle at elbow (shoulder-elbow-wrist)
    JointAngleDefinition(
      jointId: JointIds.leftElbow,
      landmarkA: LandmarkIndex.leftShoulder,
      landmarkB: LandmarkIndex.leftElbow,
      landmarkC: LandmarkIndex.leftWrist,
    ),
    JointAngleDefinition(
      jointId: JointIds.rightElbow,
      landmarkA: LandmarkIndex.rightShoulder,
      landmarkB: LandmarkIndex.rightElbow,
      landmarkC: LandmarkIndex.rightWrist,
    ),

    // Arms - angle at shoulder (hip-shoulder-elbow)
    JointAngleDefinition(
      jointId: JointIds.leftShoulder,
      landmarkA: LandmarkIndex.leftHip,
      landmarkB: LandmarkIndex.leftShoulder,
      landmarkC: LandmarkIndex.leftElbow,
    ),
    JointAngleDefinition(
      jointId: JointIds.rightShoulder,
      landmarkA: LandmarkIndex.rightHip,
      landmarkB: LandmarkIndex.rightShoulder,
      landmarkC: LandmarkIndex.rightElbow,
    ),

    // Legs - angle at knee (hip-knee-ankle)
    JointAngleDefinition(
      jointId: JointIds.leftKnee,
      landmarkA: LandmarkIndex.leftHip,
      landmarkB: LandmarkIndex.leftKnee,
      landmarkC: LandmarkIndex.leftAnkle,
    ),
    JointAngleDefinition(
      jointId: JointIds.rightKnee,
      landmarkA: LandmarkIndex.rightHip,
      landmarkB: LandmarkIndex.rightKnee,
      landmarkC: LandmarkIndex.rightAnkle,
    ),

    // Legs - angle at hip (shoulder-hip-knee)
    JointAngleDefinition(
      jointId: JointIds.leftHip,
      landmarkA: LandmarkIndex.leftShoulder,
      landmarkB: LandmarkIndex.leftHip,
      landmarkC: LandmarkIndex.leftKnee,
    ),
    JointAngleDefinition(
      jointId: JointIds.rightHip,
      landmarkA: LandmarkIndex.rightShoulder,
      landmarkB: LandmarkIndex.rightHip,
      landmarkC: LandmarkIndex.rightKnee,
    ),
  ];

  const AngleCalculator._();

  /// Calculate a single joint angle from a pose.
  /// Returns null if any required landmark is missing or unreliable.
  static JointAngle? calculateAngle(
    DetectedPose pose,
    JointAngleDefinition definition, {
    double minConfidence = 0.5,
    bool use2D = false,
  }) {
    final landmarks = pose.landmarks;

    // Get the three landmarks
    final a = _findLandmark(landmarks, definition.landmarkA);
    final b = _findLandmark(landmarks, definition.landmarkB);
    final c = _findLandmark(landmarks, definition.landmarkC);

    if (a == null || b == null || c == null) return null;

    // Check confidence
    if (!GeometryCalculator.areAllReliable(
      [a, b, c],
      threshold: minConfidence,
    )) {
      return null;
    }

    // Calculate angle
    final degrees = use2D
        ? GeometryCalculator.angleBetweenPoints2D(a, b, c)
        : GeometryCalculator.angleBetweenPoints(a, b, c);

    return JointAngle(
      jointId: definition.jointId,
      degrees: degrees,
      confidence: GeometryCalculator.minConfidence([a, b, c]),
      timestampMicros: pose.timestampMicros,
    );
  }

  /// Calculate all standard joint angles from a pose.
  /// Returns a map of joint ID to JointAngle (only includes successful calculations).
  static Map<String, JointAngle> calculateAllAngles(
    DetectedPose pose, {
    double minConfidence = 0.5,
    bool use2D = false,
  }) {
    final angles = <String, JointAngle>{};

    for (final definition in standardJoints) {
      final angle = calculateAngle(
        pose,
        definition,
        minConfidence: minConfidence,
        use2D: use2D,
      );
      if (angle != null) {
        angles[definition.jointId] = angle;
      }
    }

    return angles;
  }

  /// Calculate angles for a custom list of joint definitions.
  static Map<String, JointAngle> calculateCustomAngles(
    DetectedPose pose,
    List<JointAngleDefinition> definitions, {
    double minConfidence = 0.5,
    bool use2D = false,
  }) {
    final angles = <String, JointAngle>{};

    for (final definition in definitions) {
      final angle = calculateAngle(
        pose,
        definition,
        minConfidence: minConfidence,
        use2D: use2D,
      );
      if (angle != null) {
        angles[definition.jointId] = angle;
      }
    }

    return angles;
  }

  static Landmark? _findLandmark(List<Landmark> landmarks, int id) {
    try {
      return landmarks.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
