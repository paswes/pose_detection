import 'dart:math' as math;

import 'package:pose_detection/core/interfaces/velocity_tracker_interface.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/landmark_velocity.dart';

/// Tracks velocity of landmarks between frames
class VelocityTracker implements IVelocityTracker {
  /// Minimum time delta to calculate velocity (1ms)
  /// Prevents division by very small numbers
  static const _minDeltaMicros = 1000;

  @override
  List<LandmarkVelocity> calculateVelocities(
    TimestampedPose previousPose,
    TimestampedPose currentPose,
  ) {
    final deltaMicros =
        currentPose.timestampMicros - previousPose.timestampMicros;
    if (deltaMicros < _minDeltaMicros) {
      return [];
    }

    final deltaSeconds = deltaMicros / 1000000.0;
    final velocities = <LandmarkVelocity>[];

    final prevLandmarks = previousPose.normalizedLandmarks;
    final currLandmarks = currentPose.normalizedLandmarks;

    final count = math.min(prevLandmarks.length, currLandmarks.length);

    for (int i = 0; i < count; i++) {
      final prev = prevLandmarks[i];
      final curr = currLandmarks[i];

      // Calculate velocity components (normalized units per second)
      final vx = (curr.x - prev.x) / deltaSeconds;
      final vy = (curr.y - prev.y) / deltaSeconds;

      // Magnitude (speed)
      final speed = math.sqrt(vx * vx + vy * vy);

      // Direction in degrees (0 = right, 90 = down, 180 = left, 270 = up)
      final direction = math.atan2(vy, vx) * (180.0 / math.pi);

      // Average confidence between frames
      final confidence = (prev.likelihood + curr.likelihood) / 2;

      velocities.add(LandmarkVelocity(
        landmarkId: i,
        vx: vx,
        vy: vy,
        speed: speed,
        directionDegrees: direction,
        confidence: confidence,
        timestampMicros: currentPose.timestampMicros,
      ));
    }

    return velocities;
  }

  @override
  LandmarkVelocity? getVelocityForLandmark(
    int landmarkId,
    TimestampedPose previousPose,
    TimestampedPose currentPose,
  ) {
    final velocities = calculateVelocities(previousPose, currentPose);
    for (final v in velocities) {
      if (v.landmarkId == landmarkId) return v;
    }
    return null;
  }

  @override
  List<LandmarkVelocity> getSmoothedVelocities(
    List<TimestampedPose> recentPoses,
    int smoothingWindow,
  ) {
    if (recentPoses.length < 2) return [];

    final window = math.min(smoothingWindow, recentPoses.length - 1);
    final startIdx = recentPoses.length - window - 1;

    // Calculate velocities for each frame pair in window
    final allVelocities = <List<LandmarkVelocity>>[];
    for (int i = startIdx; i < recentPoses.length - 1; i++) {
      final velocities = calculateVelocities(recentPoses[i], recentPoses[i + 1]);
      if (velocities.isNotEmpty) {
        allVelocities.add(velocities);
      }
    }

    if (allVelocities.isEmpty) return [];

    // Average across window for each landmark
    final landmarkCount = allVelocities.first.length;
    final smoothed = <LandmarkVelocity>[];

    for (int lid = 0; lid < landmarkCount; lid++) {
      double sumVx = 0, sumVy = 0, sumConf = 0;
      int count = 0;

      for (final frameVelocities in allVelocities) {
        if (lid < frameVelocities.length) {
          final v = frameVelocities[lid];
          sumVx += v.vx;
          sumVy += v.vy;
          sumConf += v.confidence;
          count++;
        }
      }

      if (count > 0) {
        final avgVx = sumVx / count;
        final avgVy = sumVy / count;
        final speed = math.sqrt(avgVx * avgVx + avgVy * avgVy);
        final direction = math.atan2(avgVy, avgVx) * (180.0 / math.pi);

        smoothed.add(LandmarkVelocity(
          landmarkId: lid,
          vx: avgVx,
          vy: avgVy,
          speed: speed,
          directionDegrees: direction,
          confidence: sumConf / count,
          timestampMicros: recentPoses.last.timestampMicros,
        ));
      }
    }

    return smoothed;
  }
}
