import 'package:pose_detection/domain/models/landmark_type.dart';

/// Represents an anatomical joint defined by three landmarks.
///
/// A joint angle is measured at the vertex (middle landmark) with
/// the first and third landmarks forming the two rays of the angle.
///
/// Usage:
/// ```dart
/// final elbowJoint = BodyJoint.leftElbow;
/// final angle = angleCalculator.calculateAngle(
///   pose: pose,
///   first: elbowJoint.first.id,
///   vertex: elbowJoint.vertex.id,
///   third: elbowJoint.third.id,
/// );
/// ```
enum BodyJoint {
  // ============================================
  // Upper Body Joints
  // ============================================

  /// Left elbow angle (shoulder → elbow → wrist)
  leftElbow(
    first: LandmarkType.leftShoulder,
    vertex: LandmarkType.leftElbow,
    third: LandmarkType.leftWrist,
  ),

  /// Right elbow angle (shoulder → elbow → wrist)
  rightElbow(
    first: LandmarkType.rightShoulder,
    vertex: LandmarkType.rightElbow,
    third: LandmarkType.rightWrist,
  ),

  /// Left shoulder angle (elbow → shoulder → hip)
  leftShoulder(
    first: LandmarkType.leftElbow,
    vertex: LandmarkType.leftShoulder,
    third: LandmarkType.leftHip,
  ),

  /// Right shoulder angle (elbow → shoulder → hip)
  rightShoulder(
    first: LandmarkType.rightElbow,
    vertex: LandmarkType.rightShoulder,
    third: LandmarkType.rightHip,
  ),

  // ============================================
  // Lower Body Joints
  // ============================================

  /// Left hip angle (shoulder → hip → knee)
  leftHip(
    first: LandmarkType.leftShoulder,
    vertex: LandmarkType.leftHip,
    third: LandmarkType.leftKnee,
  ),

  /// Right hip angle (shoulder → hip → knee)
  rightHip(
    first: LandmarkType.rightShoulder,
    vertex: LandmarkType.rightHip,
    third: LandmarkType.rightKnee,
  ),

  /// Left knee angle (hip → knee → ankle)
  leftKnee(
    first: LandmarkType.leftHip,
    vertex: LandmarkType.leftKnee,
    third: LandmarkType.leftAnkle,
  ),

  /// Right knee angle (hip → knee → ankle)
  rightKnee(
    first: LandmarkType.rightHip,
    vertex: LandmarkType.rightKnee,
    third: LandmarkType.rightAnkle,
  ),

  /// Left ankle angle (knee → ankle → heel)
  leftAnkle(
    first: LandmarkType.leftKnee,
    vertex: LandmarkType.leftAnkle,
    third: LandmarkType.leftHeel,
  ),

  /// Right ankle angle (knee → ankle → heel)
  rightAnkle(
    first: LandmarkType.rightKnee,
    vertex: LandmarkType.rightAnkle,
    third: LandmarkType.rightHeel,
  ),

  // ============================================
  // Torso & Spine
  // ============================================

  /// Left torso lean (shoulder → hip → knee)
  /// Same as leftHip, but semantically represents torso lean
  leftTorsoLean(
    first: LandmarkType.leftShoulder,
    vertex: LandmarkType.leftHip,
    third: LandmarkType.leftKnee,
  ),

  /// Right torso lean (shoulder → hip → knee)
  rightTorsoLean(
    first: LandmarkType.rightShoulder,
    vertex: LandmarkType.rightHip,
    third: LandmarkType.rightKnee,
  ),

  /// Neck angle (nose → left shoulder → left hip)
  /// Approximates neck/head forward lean
  neckLean(
    first: LandmarkType.nose,
    vertex: LandmarkType.leftShoulder,
    third: LandmarkType.leftHip,
  );

  /// The first landmark (start of first ray)
  final LandmarkType first;

  /// The vertex landmark (where angle is measured)
  final LandmarkType vertex;

  /// The third landmark (end of second ray)
  final LandmarkType third;

  const BodyJoint({
    required this.first,
    required this.vertex,
    required this.third,
  });

  /// Get the landmark IDs as a tuple (for backward compatibility)
  (int, int, int) get landmarkIds => (first.id, vertex.id, third.id);

  /// Unique identifier for this joint configuration
  String get jointId => '${first.id}_${vertex.id}_${third.id}';

  /// Human-readable name of the joint
  String get displayName {
    final result = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      final char = name[i];
      if (i == 0) {
        result.write(char.toUpperCase());
      } else if (char.toUpperCase() == char && char != char.toLowerCase()) {
        result.write(' ');
        result.write(char);
      } else {
        result.write(char);
      }
    }
    return result.toString();
  }

  /// Whether this is a left-side joint
  bool get isLeftSide => name.startsWith('left');

  /// Whether this is a right-side joint
  bool get isRightSide => name.startsWith('right');

  /// Get the mirrored joint (left <-> right)
  BodyJoint? get mirrored {
    if (isLeftSide) {
      final mirroredName = name.replaceFirst('left', 'right');
      return BodyJoint.values.where((j) => j.name == mirroredName).firstOrNull;
    } else if (isRightSide) {
      final mirroredName = name.replaceFirst('right', 'left');
      return BodyJoint.values.where((j) => j.name == mirroredName).firstOrNull;
    }
    return null;
  }

  /// Whether this is an upper body joint
  bool get isUpperBody =>
      this == leftElbow ||
      this == rightElbow ||
      this == leftShoulder ||
      this == rightShoulder;

  /// Whether this is a lower body joint
  bool get isLowerBody =>
      this == leftHip ||
      this == rightHip ||
      this == leftKnee ||
      this == rightKnee ||
      this == leftAnkle ||
      this == rightAnkle;

  // ============================================
  // Grouped accessors
  // ============================================

  /// All upper body joints
  static List<BodyJoint> get upperBodyJoints =>
      values.where((j) => j.isUpperBody).toList();

  /// All lower body joints
  static List<BodyJoint> get lowerBodyJoints =>
      values.where((j) => j.isLowerBody).toList();

  /// All left-side joints
  static List<BodyJoint> get leftSideJoints =>
      values.where((j) => j.isLeftSide).toList();

  /// All right-side joints
  static List<BodyJoint> get rightSideJoints =>
      values.where((j) => j.isRightSide).toList();

  /// Paired joints (left and right versions)
  static List<(BodyJoint left, BodyJoint right)> get pairedJoints => [
        (leftElbow, rightElbow),
        (leftShoulder, rightShoulder),
        (leftHip, rightHip),
        (leftKnee, rightKnee),
        (leftAnkle, rightAnkle),
      ];

  /// Primary joints for full-body tracking
  static List<BodyJoint> get primaryJoints => [
        leftElbow,
        rightElbow,
        leftShoulder,
        rightShoulder,
        leftHip,
        rightHip,
        leftKnee,
        rightKnee,
      ];
}
