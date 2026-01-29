/// ML Kit Pose landmark IDs for type-safe access
/// Based on google_mlkit_pose_detection landmark indices
abstract class PoseLandmarkId {
  // Face landmarks
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int leftMouth = 9;
  static const int rightMouth = 10;

  // Upper body landmarks
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;

  // Lower body landmarks
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;

  /// Core torso landmarks - essential for human detection
  /// These landmarks define the fundamental human body structure
  static const List<int> coreTorso = [
    leftShoulder,
    rightShoulder,
    leftHip,
    rightHip,
  ];

  /// Face landmarks for head position estimation
  static const List<int> face = [
    nose,
    leftEye,
    rightEye,
    leftEar,
    rightEar,
    leftMouth,
    rightMouth,
  ];

  /// Upper limb landmarks (arms)
  static const List<int> upperLimbs = [
    leftShoulder,
    rightShoulder,
    leftElbow,
    rightElbow,
    leftWrist,
    rightWrist,
  ];

  /// Lower limb landmarks (legs)
  static const List<int> lowerLimbs = [
    leftHip,
    rightHip,
    leftKnee,
    rightKnee,
    leftAnkle,
    rightAnkle,
  ];

  /// Extremity landmarks (hands and feet) - often occluded
  static const List<int> extremities = [
    leftPinky,
    rightPinky,
    leftIndex,
    rightIndex,
    leftThumb,
    rightThumb,
    leftHeel,
    rightHeel,
    leftFootIndex,
    rightFootIndex,
  ];

  /// High-priority landmarks that should be visible for human detection
  /// These are the minimum landmarks needed to confirm a human pose
  static const List<int> highPriority = [
    nose,
    leftShoulder,
    rightShoulder,
    leftHip,
    rightHip,
  ];

  /// Medium-priority landmarks (important but may be occluded)
  static const List<int> mediumPriority = [
    leftElbow,
    rightElbow,
    leftKnee,
    rightKnee,
  ];
}

/// Anatomical bone segments for proportion validation
/// Each segment is a pair of landmark IDs representing a body part
class BoneSegment {
  final int startId;
  final int endId;
  final String name;

  const BoneSegment(this.startId, this.endId, this.name);
}

/// Standard human bone segments for anatomical validation
abstract class HumanBoneSegments {
  // Torso
  static const shoulderWidth = BoneSegment(
    PoseLandmarkId.leftShoulder,
    PoseLandmarkId.rightShoulder,
    'shoulder_width',
  );
  static const hipWidth = BoneSegment(
    PoseLandmarkId.leftHip,
    PoseLandmarkId.rightHip,
    'hip_width',
  );
  static const leftTorso = BoneSegment(
    PoseLandmarkId.leftShoulder,
    PoseLandmarkId.leftHip,
    'left_torso',
  );
  static const rightTorso = BoneSegment(
    PoseLandmarkId.rightShoulder,
    PoseLandmarkId.rightHip,
    'right_torso',
  );

  // Arms
  static const leftUpperArm = BoneSegment(
    PoseLandmarkId.leftShoulder,
    PoseLandmarkId.leftElbow,
    'left_upper_arm',
  );
  static const rightUpperArm = BoneSegment(
    PoseLandmarkId.rightShoulder,
    PoseLandmarkId.rightElbow,
    'right_upper_arm',
  );
  static const leftForearm = BoneSegment(
    PoseLandmarkId.leftElbow,
    PoseLandmarkId.leftWrist,
    'left_forearm',
  );
  static const rightForearm = BoneSegment(
    PoseLandmarkId.rightElbow,
    PoseLandmarkId.rightWrist,
    'right_forearm',
  );

  // Legs
  static const leftThigh = BoneSegment(
    PoseLandmarkId.leftHip,
    PoseLandmarkId.leftKnee,
    'left_thigh',
  );
  static const rightThigh = BoneSegment(
    PoseLandmarkId.rightHip,
    PoseLandmarkId.rightKnee,
    'right_thigh',
  );
  static const leftShin = BoneSegment(
    PoseLandmarkId.leftKnee,
    PoseLandmarkId.leftAnkle,
    'left_shin',
  );
  static const rightShin = BoneSegment(
    PoseLandmarkId.rightKnee,
    PoseLandmarkId.rightAnkle,
    'right_shin',
  );

  // Head/Neck
  static const neckToNose = BoneSegment(
    PoseLandmarkId.leftShoulder, // Approximated from shoulder midpoint
    PoseLandmarkId.nose,
    'neck_to_nose',
  );

  /// All segments for comprehensive validation
  static const List<BoneSegment> all = [
    shoulderWidth,
    hipWidth,
    leftTorso,
    rightTorso,
    leftUpperArm,
    rightUpperArm,
    leftForearm,
    rightForearm,
    leftThigh,
    rightThigh,
    leftShin,
    rightShin,
  ];

  /// Core segments that must be present
  static const List<BoneSegment> core = [
    shoulderWidth,
    hipWidth,
    leftTorso,
    rightTorso,
  ];
}
