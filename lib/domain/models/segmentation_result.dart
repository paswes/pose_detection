import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/detected_object.dart';

/// Result of segmentation analysis for a single frame
/// Agnostic - contains raw segmentation data without interpretation
class SegmentationResult extends Equatable {
  /// Width of the segmentation mask
  final int maskWidth;

  /// Height of the segmentation mask
  final int maskHeight;

  /// Total number of pixels in the mask
  int get totalPixels => maskWidth * maskHeight;

  /// Number of pixels classified as foreground (subject)
  final int foregroundPixels;

  /// Percentage of frame covered by foreground (0.0 to 1.0)
  double get foregroundCoverage =>
      totalPixels > 0 ? foregroundPixels / totalPixels : 0.0;

  /// Average confidence of foreground pixels (0.0 to 1.0)
  final double averageConfidence;

  /// Bounding box of the foreground region in normalized coordinates
  /// null if no foreground detected
  final NormalizedBoundingBox? foregroundBounds;

  /// Processing latency in milliseconds
  final double segmentationLatencyMs;

  /// Image dimensions that were processed
  final double imageWidth;
  final double imageHeight;

  const SegmentationResult({
    required this.maskWidth,
    required this.maskHeight,
    required this.foregroundPixels,
    required this.averageConfidence,
    this.foregroundBounds,
    required this.segmentationLatencyMs,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Whether any foreground was detected
  bool get hasForeground => foregroundPixels > 0;

  /// Create an empty result (no segmentation data)
  const SegmentationResult.empty({
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.segmentationLatencyMs = 0,
  })  : maskWidth = 0,
        maskHeight = 0,
        foregroundPixels = 0,
        averageConfidence = 0.0,
        foregroundBounds = null;

  @override
  List<Object?> get props => [
        maskWidth,
        maskHeight,
        foregroundPixels,
        averageConfidence,
        foregroundBounds,
        segmentationLatencyMs,
      ];

  @override
  String toString() =>
      'SegmentationResult(coverage: ${(foregroundCoverage * 100).toStringAsFixed(1)}%, '
      'confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%, '
      'latency: ${segmentationLatencyMs.toStringAsFixed(1)}ms)';
}
