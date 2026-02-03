import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/models/landmark_type.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/vector3.dart';

/// Service for calculating joint angles from pose landmarks.
///
/// Provides both 2D (x,y only) and 3D angle calculations.
/// Exercise-agnostic - calculates geometric angles without
/// knowledge of specific exercises or movements.
///
/// Usage:
/// ```dart
/// final calculator = AngleCalculator();
///
/// // Using BodyJoint enum (recommended)
/// final elbowAngle = calculator.calculateFromBodyJoint(
///   pose: pose,
///   joint: BodyJoint.leftElbow,
/// );
///
/// // Using LandmarkType enum
/// final kneeAngle = calculator.calculateFromLandmarks(
///   pose: pose,
///   first: LandmarkType.leftHip,
///   vertex: LandmarkType.leftKnee,
///   third: LandmarkType.leftAnkle,
/// );
/// ```
class AngleCalculator {
  /// Calculate the angle at a joint using BodyJoint definition (recommended).
  ///
  /// [pose] - The detected pose containing landmarks
  /// [joint] - The body joint to calculate angle for
  /// [use3D] - Whether to include Z coordinate in calculation
  ///
  /// Returns null if any required landmark is missing or has very low confidence.
  JointAngle? calculateFromBodyJoint({
    required DetectedPose pose,
    required BodyJoint joint,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    return calculateAngle(
      pose: pose,
      first: joint.first.id,
      vertex: joint.vertex.id,
      third: joint.third.id,
      bodyJoint: joint,
      use3D: use3D,
      minConfidence: minConfidence,
    );
  }

  /// Calculate the angle using LandmarkType enum (semantic).
  JointAngle? calculateFromLandmarks({
    required DetectedPose pose,
    required LandmarkType first,
    required LandmarkType vertex,
    required LandmarkType third,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    return calculateAngle(
      pose: pose,
      first: first.id,
      vertex: vertex.id,
      third: third.id,
      use3D: use3D,
      minConfidence: minConfidence,
    );
  }

  /// Calculate the angle at a joint defined by three landmark IDs.
  ///
  /// [pose] - The detected pose containing landmarks
  /// [first] - ID of the first landmark (start of first ray)
  /// [vertex] - ID of the vertex landmark (where angle is measured)
  /// [third] - ID of the third landmark (end of second ray)
  /// [bodyJoint] - Optional BodyJoint for semantic reference
  /// [use3D] - Whether to include Z coordinate in calculation
  ///
  /// Returns null if any required landmark is missing or has very low confidence.
  JointAngle? calculateAngle({
    required DetectedPose pose,
    required int first,
    required int vertex,
    required int third,
    BodyJoint? bodyJoint,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    // Get landmarks by ID
    final firstLandmark = _getLandmarkById(pose, first);
    final vertexLandmark = _getLandmarkById(pose, vertex);
    final thirdLandmark = _getLandmarkById(pose, third);

    // Check if all landmarks exist
    if (firstLandmark == null ||
        vertexLandmark == null ||
        thirdLandmark == null) {
      return null;
    }

    // Check minimum confidence
    final avgConfidence = (firstLandmark.confidence +
            vertexLandmark.confidence +
            thirdLandmark.confidence) /
        3;
    if (avgConfidence < minConfidence) {
      return null;
    }

    // Calculate vectors from vertex to other points
    final Vector3 v1;
    final Vector3 v2;

    if (use3D) {
      v1 = Vector3(
        firstLandmark.x - vertexLandmark.x,
        firstLandmark.y - vertexLandmark.y,
        firstLandmark.z - vertexLandmark.z,
      );
      v2 = Vector3(
        thirdLandmark.x - vertexLandmark.x,
        thirdLandmark.y - vertexLandmark.y,
        thirdLandmark.z - vertexLandmark.z,
      );
    } else {
      // 2D calculation (ignore Z)
      v1 = Vector3(
        firstLandmark.x - vertexLandmark.x,
        firstLandmark.y - vertexLandmark.y,
        0,
      );
      v2 = Vector3(
        thirdLandmark.x - vertexLandmark.x,
        thirdLandmark.y - vertexLandmark.y,
        0,
      );
    }

    // Calculate angle using dot product
    final radians = v1.angleTo(v2);

    return JointAngle(
      bodyJoint: bodyJoint,
      firstLandmarkId: first,
      vertexLandmarkId: vertex,
      thirdLandmarkId: third,
      radians: radians,
      timestampMicros: pose.timestampMicros,
      confidence: avgConfidence,
    );
  }

  /// Calculate all primary body joint angles for a pose.
  ///
  /// Returns a map of jointId to JointAngle for all successfully calculated angles.
  Map<String, JointAngle> calculateAllPrimaryAngles({
    required DetectedPose pose,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    final angles = <String, JointAngle>{};

    for (final joint in BodyJoint.primaryJoints) {
      final angle = calculateFromBodyJoint(
        pose: pose,
        joint: joint,
        use3D: use3D,
        minConfidence: minConfidence,
      );
      if (angle != null) {
        angles[angle.jointId] = angle;
      }
    }

    return angles;
  }

  /// Calculate all body joint angles for a pose.
  Map<String, JointAngle> calculateAllAngles({
    required DetectedPose pose,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    final angles = <String, JointAngle>{};

    for (final joint in BodyJoint.values) {
      final angle = calculateFromBodyJoint(
        pose: pose,
        joint: joint,
        use3D: use3D,
        minConfidence: minConfidence,
      );
      if (angle != null) {
        angles[angle.jointId] = angle;
      }
    }

    return angles;
  }

  /// Alias for calculateAllPrimaryAngles for backward compatibility.
  Map<String, JointAngle> calculateAllCommonAngles({
    required DetectedPose pose,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    return calculateAllPrimaryAngles(
      pose: pose,
      use3D: use3D,
      minConfidence: minConfidence,
    );
  }

  /// Calculate angle between two body segments (4 landmarks).
  ///
  /// Useful for measuring angles like torso lean relative to legs.
  /// [a1, a2] define the first segment, [b1, b2] define the second.
  double? calculateSegmentAngle({
    required DetectedPose pose,
    required LandmarkType a1,
    required LandmarkType a2,
    required LandmarkType b1,
    required LandmarkType b2,
    bool use3D = true,
    double minConfidence = 0.3,
  }) {
    final la1 = _getLandmarkById(pose, a1.id);
    final la2 = _getLandmarkById(pose, a2.id);
    final lb1 = _getLandmarkById(pose, b1.id);
    final lb2 = _getLandmarkById(pose, b2.id);

    if (la1 == null || la2 == null || lb1 == null || lb2 == null) {
      return null;
    }

    // Check confidence
    final avgConf =
        (la1.confidence + la2.confidence + lb1.confidence + lb2.confidence) / 4;
    if (avgConf < minConfidence) return null;

    // Create direction vectors
    final Vector3 v1;
    final Vector3 v2;

    if (use3D) {
      v1 = Vector3(la2.x - la1.x, la2.y - la1.y, la2.z - la1.z);
      v2 = Vector3(lb2.x - lb1.x, lb2.y - lb1.y, lb2.z - lb1.z);
    } else {
      v1 = Vector3(la2.x - la1.x, la2.y - la1.y, 0);
      v2 = Vector3(lb2.x - lb1.x, lb2.y - lb1.y, 0);
    }

    return v1.angleTo(v2);
  }

  /// Calculate the angle of a segment relative to vertical (Y-axis).
  ///
  /// Useful for measuring things like torso inclination.
  double? calculateAngleFromVertical({
    required DetectedPose pose,
    required LandmarkType top,
    required LandmarkType bottom,
    bool use3D = false, // Usually want 2D for vertical alignment
    double minConfidence = 0.3,
  }) {
    final topLandmark = _getLandmarkById(pose, top.id);
    final bottomLandmark = _getLandmarkById(pose, bottom.id);

    if (topLandmark == null || bottomLandmark == null) return null;

    final avgConf = (topLandmark.confidence + bottomLandmark.confidence) / 2;
    if (avgConf < minConfidence) return null;

    final Vector3 segment;
    if (use3D) {
      segment = Vector3(
        topLandmark.x - bottomLandmark.x,
        topLandmark.y - bottomLandmark.y,
        topLandmark.z - bottomLandmark.z,
      );
    } else {
      segment = Vector3(
        topLandmark.x - bottomLandmark.x,
        topLandmark.y - bottomLandmark.y,
        0,
      );
    }

    // Vertical axis (pointing up, negative Y in screen coordinates)
    const vertical = Vector3(0, -1, 0);

    return segment.angleTo(vertical);
  }

  /// Calculate the angle of a segment relative to horizontal (X-axis).
  double? calculateAngleFromHorizontal({
    required DetectedPose pose,
    required LandmarkType left,
    required LandmarkType right,
    bool use3D = false,
    double minConfidence = 0.3,
  }) {
    final leftLandmark = _getLandmarkById(pose, left.id);
    final rightLandmark = _getLandmarkById(pose, right.id);

    if (leftLandmark == null || rightLandmark == null) return null;

    final avgConf = (leftLandmark.confidence + rightLandmark.confidence) / 2;
    if (avgConf < minConfidence) return null;

    final Vector3 segment;
    if (use3D) {
      segment = Vector3(
        rightLandmark.x - leftLandmark.x,
        rightLandmark.y - leftLandmark.y,
        rightLandmark.z - leftLandmark.z,
      );
    } else {
      segment = Vector3(
        rightLandmark.x - leftLandmark.x,
        rightLandmark.y - leftLandmark.y,
        0,
      );
    }

    // Horizontal axis
    const horizontal = Vector3(1, 0, 0);

    return segment.angleTo(horizontal);
  }

  /// Get a landmark by ID from a pose
  Landmark? _getLandmarkById(DetectedPose pose, int id) {
    return pose.landmarks.where((l) => l.id == id).firstOrNull;
  }
}

/// Interface for angle calculation (allows mocking/alternative implementations)
abstract class IAngleCalculator {
  JointAngle? calculateFromBodyJoint({
    required DetectedPose pose,
    required BodyJoint joint,
    bool use3D = true,
    double minConfidence = 0.3,
  });

  JointAngle? calculateAngle({
    required DetectedPose pose,
    required int first,
    required int vertex,
    required int third,
    bool use3D = true,
    double minConfidence = 0.3,
  });

  Map<String, JointAngle> calculateAllPrimaryAngles({
    required DetectedPose pose,
    bool use3D = true,
    double minConfidence = 0.3,
  });
}
