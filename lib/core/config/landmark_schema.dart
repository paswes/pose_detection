/// Schema for pose landmark definitions.
/// Makes the 33-landmark assumption explicit and configurable.
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

  /// ML Kit / MediaPipe 33-landmark schema
  static const mlKit33 = LandmarkSchema(
    landmarkCount: 33,
    landmarkNames: [
      'Nose',
      'Left Eye Inner',
      'Left Eye',
      'Left Eye Outer',
      'Right Eye Inner',
      'Right Eye',
      'Right Eye Outer',
      'Left Ear',
      'Right Ear',
      'Mouth Left',
      'Mouth Right',
      'Left Shoulder',
      'Right Shoulder',
      'Left Elbow',
      'Right Elbow',
      'Left Wrist',
      'Right Wrist',
      'Left Pinky',
      'Right Pinky',
      'Left Index',
      'Right Index',
      'Left Thumb',
      'Right Thumb',
      'Left Hip',
      'Right Hip',
      'Left Knee',
      'Right Knee',
      'Left Ankle',
      'Right Ankle',
      'Left Heel',
      'Right Heel',
      'Left Foot Index',
      'Right Foot Index',
    ],
    skeletonConnections: [
      // Face
      [1, 2], [2, 3], [3, 7], // Left eye to ear
      [4, 5], [5, 6], [6, 8], // Right eye to ear
      [9, 10], // Mouth
      [0, 1], [0, 4], // Nose to eyes
      [9, 7], [10, 8], // Mouth to ears

      // Torso
      [11, 12], // Shoulders
      [11, 23], [12, 24], // Shoulders to hips
      [23, 24], // Hips

      // Left arm
      [11, 13], [13, 15], // Shoulder to wrist
      [15, 17], [15, 19], [17, 19], [15, 21], // Hand

      // Right arm
      [12, 14], [14, 16], // Shoulder to wrist
      [16, 18], [16, 20], [18, 20], [16, 22], // Hand

      // Left leg
      [23, 25], [25, 27], // Hip to ankle
      [27, 29], [27, 31], [29, 31], // Foot

      // Right leg
      [24, 26], [26, 28], // Hip to ankle
      [28, 30], [28, 32], [30, 32], // Foot
    ],
  );
}
