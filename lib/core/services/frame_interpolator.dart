import 'dart:math';

import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// Interpolates landmark positions between two consecutive recorded frames.
///
/// Uses linear interpolation on x/y/z coordinates and conservative likelihood
/// (minimum of the two frames). Skips interpolation when frames are too far
/// apart (>100ms) to avoid artifacts during fast movement.
class FrameInterpolator {
  /// Maximum inter-frame gap (in microseconds) for interpolation.
  /// Beyond this, snap to the nearest frame instead.
  static const _maxInterpolationGapMicros = 100000; // 100ms

  /// Interpolate landmarks between [frameA] and [frameB] at factor [t].
  ///
  /// [t] ranges from 0.0 (use frameA) to 1.0 (use frameB).
  ///
  /// Returns the interpolated landmarks, or snaps to one frame if:
  /// - Either frame has no person detected
  /// - The time gap exceeds [_maxInterpolationGapMicros]
  /// - Landmark counts don't match
  static List<LandmarkData> interpolate(
    TrackedFrame frameA,
    TrackedFrame frameB,
    double t,
  ) {
    // Snap to nearest if either frame has no person
    if (!frameA.isPersonDetected && !frameB.isPersonDetected) return [];
    if (!frameA.isPersonDetected) return frameB.landmarks;
    if (!frameB.isPersonDetected) return frameA.landmarks;

    // Snap if gap is too large (fast movement = artifacts)
    final gap = (frameB.timestampMicros - frameA.timestampMicros).abs();
    if (gap > _maxInterpolationGapMicros) {
      return t < 0.5 ? frameA.landmarks : frameB.landmarks;
    }

    // Snap if landmark counts differ (shouldn't happen with ML Kit, but be safe)
    if (frameA.landmarks.length != frameB.landmarks.length) {
      return t < 0.5 ? frameA.landmarks : frameB.landmarks;
    }

    // Build lookup for frameB landmarks by ID
    final bMap = <int, LandmarkData>{};
    for (final l in frameB.landmarks) {
      bMap[l.id] = l;
    }

    // Lerp each landmark
    final result = <LandmarkData>[];
    for (final a in frameA.landmarks) {
      final b = bMap[a.id];
      if (b == null) {
        result.add(a);
        continue;
      }

      result.add(LandmarkData(
        id: a.id,
        x: _lerp(a.x, b.x, t),
        y: _lerp(a.y, b.y, t),
        z: _lerp(a.z, b.z, t),
        likelihood: min(a.likelihood, b.likelihood),
      ));
    }

    return result;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
