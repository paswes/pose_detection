/// Enumeration of all 33 ML Kit / MediaPipe pose landmarks.
///
/// Provides semantic access to landmark IDs instead of magic numbers.
/// Each landmark has a unique ID (0-32) that corresponds to the ML Kit output.
///
/// Usage:
/// ```dart
/// final landmark = pose.getLandmarkById(LandmarkType.leftShoulder.id);
/// final elbowId = LandmarkType.leftElbow.id; // 13
/// ```
enum LandmarkType {
  // ============================================
  // Face (0-10)
  // ============================================
  nose(0),
  leftEyeInner(1),
  leftEye(2),
  leftEyeOuter(3),
  rightEyeInner(4),
  rightEye(5),
  rightEyeOuter(6),
  leftEar(7),
  rightEar(8),
  mouthLeft(9),
  mouthRight(10),

  // ============================================
  // Upper Body (11-22)
  // ============================================
  leftShoulder(11),
  rightShoulder(12),
  leftElbow(13),
  rightElbow(14),
  leftWrist(15),
  rightWrist(16),
  leftPinky(17),
  rightPinky(18),
  leftIndex(19),
  rightIndex(20),
  leftThumb(21),
  rightThumb(22),

  // ============================================
  // Lower Body (23-32)
  // ============================================
  leftHip(23),
  rightHip(24),
  leftKnee(25),
  rightKnee(26),
  leftAnkle(27),
  rightAnkle(28),
  leftHeel(29),
  rightHeel(30),
  leftFootIndex(31),
  rightFootIndex(32);

  /// The ML Kit landmark ID (0-32)
  final int id;

  const LandmarkType(this.id);

  /// Get LandmarkType from ML Kit ID
  static LandmarkType? fromId(int id) {
    return LandmarkType.values.where((l) => l.id == id).firstOrNull;
  }

  /// Human-readable name
  String get displayName {
    // Convert camelCase to Title Case with spaces
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

  /// Whether this is a face landmark
  bool get isFace => id >= 0 && id <= 10;

  /// Whether this is an upper body landmark
  bool get isUpperBody => id >= 11 && id <= 22;

  /// Whether this is a lower body landmark
  bool get isLowerBody => id >= 23 && id <= 32;

  /// Whether this is a left-side landmark
  bool get isLeftSide => name.startsWith('left');

  /// Whether this is a right-side landmark
  bool get isRightSide => name.startsWith('right');

  /// Get the mirrored landmark (left <-> right)
  LandmarkType? get mirrored {
    if (isLeftSide) {
      final mirroredName = name.replaceFirst('left', 'right');
      return LandmarkType.values.where((l) => l.name == mirroredName).firstOrNull;
    } else if (isRightSide) {
      final mirroredName = name.replaceFirst('right', 'left');
      return LandmarkType.values.where((l) => l.name == mirroredName).firstOrNull;
    }
    return null;
  }

  // ============================================
  // Grouped accessors
  // ============================================

  /// All face landmarks
  static List<LandmarkType> get face => values.where((l) => l.isFace).toList();

  /// All upper body landmarks
  static List<LandmarkType> get upperBody =>
      values.where((l) => l.isUpperBody).toList();

  /// All lower body landmarks
  static List<LandmarkType> get lowerBody =>
      values.where((l) => l.isLowerBody).toList();

  /// All left-side landmarks
  static List<LandmarkType> get leftSide =>
      values.where((l) => l.isLeftSide).toList();

  /// All right-side landmarks
  static List<LandmarkType> get rightSide =>
      values.where((l) => l.isRightSide).toList();

  /// Core body landmarks (shoulders, hips) - useful for body tracking
  static List<LandmarkType> get coreBody => [
        leftShoulder,
        rightShoulder,
        leftHip,
        rightHip,
      ];

  /// Arm landmarks
  static List<LandmarkType> get arms => [
        leftShoulder,
        rightShoulder,
        leftElbow,
        rightElbow,
        leftWrist,
        rightWrist,
      ];

  /// Leg landmarks
  static List<LandmarkType> get legs => [
        leftHip,
        rightHip,
        leftKnee,
        rightKnee,
        leftAnkle,
        rightAnkle,
      ];

  /// Hand landmarks (wrists and fingers)
  static List<LandmarkType> get hands => [
        leftWrist,
        rightWrist,
        leftPinky,
        rightPinky,
        leftIndex,
        rightIndex,
        leftThumb,
        rightThumb,
      ];

  /// Foot landmarks
  static List<LandmarkType> get feet => [
        leftAnkle,
        rightAnkle,
        leftHeel,
        rightHeel,
        leftFootIndex,
        rightFootIndex,
      ];

  /// Total number of landmarks (33 for ML Kit)
  static const int totalCount = 33;
}
