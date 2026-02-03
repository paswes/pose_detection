import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/filters/one_euro_filter.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Service for smoothing pose landmark data using OneEuroFilter.
///
/// Reduces jitter in landmark positions while maintaining responsiveness
/// during fast movements. Configurable via PoseDetectionConfig.
///
/// Usage:
/// ```dart
/// final smoother = PoseSmoother(config: config);
/// final smoothedPose = smoother.smooth(rawPose);
/// ```
class PoseSmoother {
  final PoseDetectionConfig _config;

  /// Filters for each landmark ID (x, y, z per landmark)
  final Map<int, OneEuroFilter3D> _landmarkFilters = {};

  /// Last timestamp used for reset detection
  int? _lastTimestampMicros;

  /// Maximum gap between frames before resetting filters (microseconds)
  /// Default: 500ms - if gap is larger, assume tracking was lost
  static const int _maxGapMicros = 500000;

  PoseSmoother({required PoseDetectionConfig config}) : _config = config;

  /// Smooth a detected pose using OneEuroFilter.
  ///
  /// If smoothing is disabled in config, returns the original pose unchanged.
  /// If there's a large time gap, filters are reset to avoid artifacts.
  ///
  /// [pose] - The raw detected pose from ML
  ///
  /// Returns a new DetectedPose with smoothed landmark positions.
  DetectedPose smooth(DetectedPose pose) {
    if (!_config.smoothingEnabled) {
      return pose;
    }

    // Check for time gap (tracking loss detection)
    if (_lastTimestampMicros != null) {
      final gap = pose.timestampMicros - _lastTimestampMicros!;
      if (gap > _maxGapMicros || gap < 0) {
        // Large gap or time went backwards - reset all filters
        reset();
      }
    }
    _lastTimestampMicros = pose.timestampMicros;

    // Convert timestamp to seconds for the filter
    final timestampSec = pose.timestampMicros / 1000000.0;

    // Smooth each landmark
    final smoothedLandmarks = pose.landmarks.map((landmark) {
      return _smoothLandmark(landmark, timestampSec);
    }).toList();

    return DetectedPose(
      landmarks: smoothedLandmarks,
      imageSize: pose.imageSize,
      timestampMicros: pose.timestampMicros,
    );
  }

  /// Smooth a single landmark.
  Landmark _smoothLandmark(Landmark landmark, double timestampSec) {
    // Get or create filter for this landmark ID
    final filter = _landmarkFilters.putIfAbsent(
      landmark.id,
      () => OneEuroFilter3D(
        minCutoff: _config.smoothingMinCutoff,
        beta: _config.smoothingBeta,
        dCutoff: _config.smoothingDerivativeCutoff,
      ),
    );

    // Apply filter
    final smoothed = filter.filter(
      landmark.x,
      landmark.y,
      landmark.z,
      timestampSec,
    );

    return Landmark(
      id: landmark.id,
      x: smoothed.x,
      y: smoothed.y,
      z: smoothed.z,
      confidence: landmark.confidence, // Confidence is not smoothed
    );
  }

  /// Reset all filter states.
  ///
  /// Call this when:
  /// - Starting a new tracking session
  /// - Tracking was lost and resumed
  /// - Camera was switched
  void reset() {
    for (final filter in _landmarkFilters.values) {
      filter.reset();
    }
    _lastTimestampMicros = null;
  }

  /// Clear all filters and release resources.
  void dispose() {
    _landmarkFilters.clear();
    _lastTimestampMicros = null;
  }

  /// Check if the smoother has been initialized with at least one pose.
  bool get isInitialized => _landmarkFilters.isNotEmpty;

  /// Get the number of landmark filters currently active.
  int get activeLandmarkCount => _landmarkFilters.length;
}

/// Interface for pose smoothing to allow different implementations.
abstract class IPoseSmoother {
  /// Smooth a detected pose.
  DetectedPose smooth(DetectedPose pose);

  /// Reset filter states.
  void reset();

  /// Dispose resources.
  void dispose();
}
