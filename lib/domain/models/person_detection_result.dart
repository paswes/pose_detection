import 'package:equatable/equatable.dart';

/// Result of person detection validation
/// Contains all debug information and final detection result
class PersonDetectionResult extends Equatable {
  // Final result
  final bool isPersonDetected;

  // Size metrics
  final double shoulderWidth;
  final double torsoLength;
  final double ratio;
  final bool minSizeOk;
  final bool proportionsOk;

  // Geometry checks
  final bool headAboveShoulders;
  final bool shouldersAboveHips;

  // Symmetry checks
  final double shoulderSymmetry;
  final bool shoulderSymmetryOk;
  final double hipSymmetry;
  final bool hipSymmetryOk;

  // Head/neck checks
  final double neckLength;
  final double neckRatio;
  final bool neckOk;

  // Face detection
  final int facePartsDetected;
  final bool faceOk;

  const PersonDetectionResult({
    required this.isPersonDetected,
    required this.shoulderWidth,
    required this.torsoLength,
    required this.ratio,
    required this.minSizeOk,
    required this.proportionsOk,
    required this.headAboveShoulders,
    required this.shouldersAboveHips,
    required this.shoulderSymmetry,
    required this.shoulderSymmetryOk,
    required this.hipSymmetry,
    required this.hipSymmetryOk,
    required this.neckLength,
    required this.neckRatio,
    required this.neckOk,
    required this.facePartsDetected,
    required this.faceOk,
  });

  /// No pose detected - all values are default/false
  factory PersonDetectionResult.noPose() {
    return const PersonDetectionResult(
      isPersonDetected: false,
      shoulderWidth: 0,
      torsoLength: 0,
      ratio: 0,
      minSizeOk: false,
      proportionsOk: false,
      headAboveShoulders: false,
      shouldersAboveHips: false,
      shoulderSymmetry: 0,
      shoulderSymmetryOk: false,
      hipSymmetry: 0,
      hipSymmetryOk: false,
      neckLength: 0,
      neckRatio: 0,
      neckOk: false,
      facePartsDetected: 0,
      faceOk: false,
    );
  }

  @override
  List<Object?> get props => [
        isPersonDetected,
        shoulderWidth,
        torsoLength,
        ratio,
        minSizeOk,
        proportionsOk,
        headAboveShoulders,
        shouldersAboveHips,
        shoulderSymmetry,
        shoulderSymmetryOk,
        hipSymmetry,
        hipSymmetryOk,
        neckLength,
        neckRatio,
        neckOk,
        facePartsDetected,
        faceOk,
      ];
}
