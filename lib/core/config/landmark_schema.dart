/// Schema for ML Kit / MediaPipe 33-landmark pose model.
///
/// Provides typed landmark IDs, human-readable names, and skeleton
/// connections. All landmark IDs are defined as named constants so
/// consumers never need magic numbers.
class LandmarkSchema {
  /// Total number of landmarks
  final int landmarkCount;

  /// Human-readable names for each landmark
  final List<String> landmarkNames;

  /// Skeleton connections as pairs of landmark indices
  final List<List<int>> skeletonConnections;

  const LandmarkSchema({
    required this.landmarkCount,
    required this.landmarkNames,
    required this.skeletonConnections,
  });

  /// Get landmark name by ID, returns 'Unknown N' if out of range
  String getLandmarkName(int id) {
    return id < landmarkNames.length ? landmarkNames[id] : 'Unknown $id';
  }

  // ---------------------------------------------------------------------------
  // ML Kit / MediaPipe 33-landmark IDs
  // ---------------------------------------------------------------------------

  // Face
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

  // Upper body
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;

  // Hands
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;

  // Lower body
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;

  // Feet
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;

  // ---------------------------------------------------------------------------
  // Default schema instance
  // ---------------------------------------------------------------------------

  /// ML Kit / MediaPipe 33-landmark schema
  static const mlKit33 = LandmarkSchema(
    landmarkCount: 33,
    landmarkNames: [
      'Nose',           // 0
      'Left Eye Inner', // 1
      'Left Eye',       // 2
      'Left Eye Outer', // 3
      'Right Eye Inner', // 4
      'Right Eye',      // 5
      'Right Eye Outer', // 6
      'Left Ear',       // 7
      'Right Ear',      // 8
      'Left Mouth',     // 9
      'Right Mouth',    // 10
      'Left Shoulder',  // 11
      'Right Shoulder', // 12
      'Left Elbow',     // 13
      'Right Elbow',    // 14
      'Left Wrist',     // 15
      'Right Wrist',    // 16
      'Left Pinky',     // 17
      'Right Pinky',    // 18
      'Left Index',     // 19
      'Right Index',    // 20
      'Left Thumb',     // 21
      'Right Thumb',    // 22
      'Left Hip',       // 23
      'Right Hip',      // 24
      'Left Knee',      // 25
      'Right Knee',     // 26
      'Left Ankle',     // 27
      'Right Ankle',    // 28
      'Left Heel',      // 29
      'Right Heel',     // 30
      'Left Foot Index', // 31
      'Right Foot Index', // 32
    ],
    skeletonConnections: [
      // Face
      [leftEyeInner, leftEye], [leftEye, leftEyeOuter],
      [leftEyeOuter, leftEar],
      [rightEyeInner, rightEye], [rightEye, rightEyeOuter],
      [rightEyeOuter, rightEar],
      [leftMouth, rightMouth],
      [nose, leftEyeInner], [nose, rightEyeInner],
      [leftMouth, leftEar], [rightMouth, rightEar],
      // Torso
      [leftShoulder, rightShoulder],
      [leftShoulder, leftHip], [rightShoulder, rightHip],
      [leftHip, rightHip],
      // Left arm
      [leftShoulder, leftElbow], [leftElbow, leftWrist],
      [leftWrist, leftPinky], [leftWrist, leftIndex],
      [leftPinky, leftIndex], [leftWrist, leftThumb],
      // Right arm
      [rightShoulder, rightElbow], [rightElbow, rightWrist],
      [rightWrist, rightPinky], [rightWrist, rightIndex],
      [rightPinky, rightIndex], [rightWrist, rightThumb],
      // Left leg
      [leftHip, leftKnee], [leftKnee, leftAnkle],
      [leftAnkle, leftHeel], [leftAnkle, leftFootIndex],
      [leftHeel, leftFootIndex],
      // Right leg
      [rightHip, rightKnee], [rightKnee, rightAnkle],
      [rightAnkle, rightHeel], [rightAnkle, rightFootIndex],
      [rightHeel, rightFootIndex],
    ],
  );
}
