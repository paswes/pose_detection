import 'package:equatable/equatable.dart';
import 'dart:ui' show Offset;

/// Status of a specific landmark for position validation
enum LandmarkStatus {
  /// Landmark detected with sufficient confidence
  detected,

  /// Landmark detected but with low confidence
  lowConfidence,

  /// Landmark not detected at all
  missing,
}

/// Result of position validation for exercise setup
/// Contains validation status for required landmarks and guidance messages
class PositionValidationResult extends Equatable {
  /// Overall result - true if user is properly positioned
  final bool isProperlyPositioned;

  /// Status of left hip landmark (id: 23)
  final LandmarkStatus leftHipStatus;

  /// Status of left knee landmark (id: 25)
  final LandmarkStatus leftKneeStatus;

  /// Status of left ankle landmark (id: 27)
  final LandmarkStatus leftAnkleStatus;

  /// Detected position of left hip (null if missing)
  final Offset? leftHipPosition;

  /// Detected position of left knee (null if missing)
  final Offset? leftKneePosition;

  /// Detected position of left ankle (null if missing)
  final Offset? leftAnklePosition;

  /// Whether user appears to be in side profile (left side facing camera)
  final bool isSideProfile;

  /// Average confidence of leg landmarks
  final double avgLegConfidence;

  /// Guidance messages for the user (in German)
  final List<String> guidanceMessages;

  const PositionValidationResult({
    required this.isProperlyPositioned,
    required this.leftHipStatus,
    required this.leftKneeStatus,
    required this.leftAnkleStatus,
    this.leftHipPosition,
    this.leftKneePosition,
    this.leftAnklePosition,
    required this.isSideProfile,
    required this.avgLegConfidence,
    required this.guidanceMessages,
  });

  /// No pose detected - all values are default/missing
  factory PositionValidationResult.noPose() {
    return const PositionValidationResult(
      isProperlyPositioned: false,
      leftHipStatus: LandmarkStatus.missing,
      leftKneeStatus: LandmarkStatus.missing,
      leftAnkleStatus: LandmarkStatus.missing,
      leftHipPosition: null,
      leftKneePosition: null,
      leftAnklePosition: null,
      isSideProfile: false,
      avgLegConfidence: 0.0,
      guidanceMessages: [],
    );
  }

  /// Check if all required landmarks are detected (any confidence level)
  bool get hasAllLandmarks =>
      leftHipStatus != LandmarkStatus.missing &&
      leftKneeStatus != LandmarkStatus.missing &&
      leftAnkleStatus != LandmarkStatus.missing;

  /// Check if all landmarks are detected with good confidence
  bool get hasHighConfidenceLandmarks =>
      leftHipStatus == LandmarkStatus.detected &&
      leftKneeStatus == LandmarkStatus.detected &&
      leftAnkleStatus == LandmarkStatus.detected;

  @override
  List<Object?> get props => [
        isProperlyPositioned,
        leftHipStatus,
        leftKneeStatus,
        leftAnkleStatus,
        leftHipPosition,
        leftKneePosition,
        leftAnklePosition,
        isSideProfile,
        avgLegConfidence,
        guidanceMessages,
      ];
}
