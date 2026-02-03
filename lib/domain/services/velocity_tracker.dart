import 'package:pose_detection/core/data_structures/ring_buffer.dart';
import 'package:pose_detection/core/utils/geometry_calculator.dart';
import 'package:pose_detection/core/utils/vector3.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Tracks landmark velocities across frames.
/// Uses a ring buffer to maintain pose history for velocity calculations.
class VelocityTracker {
  final RingBuffer<DetectedPose> _poseHistory;
  final double _minConfidence;

  /// Creates a velocity tracker.
  /// [historySize] determines how many frames are kept for smoothing.
  /// [minConfidence] is the minimum landmark confidence for calculations.
  VelocityTracker({
    int historySize = 5,
    double minConfidence = 0.5,
  })  : _poseHistory = RingBuffer<DetectedPose>(historySize),
        _minConfidence = minConfidence;

  /// Add a new pose to the tracker and calculate velocities.
  /// Returns a map of landmark ID to velocity vector (pixels per second).
  Map<int, Vector3> addPose(DetectedPose pose) {
    final previousPose = _poseHistory.latest;
    _poseHistory.add(pose);

    if (previousPose == null) {
      return {}; // Need at least 2 poses to calculate velocity
    }

    return _calculateVelocities(previousPose, pose);
  }

  /// Calculate velocities between two consecutive poses.
  Map<int, Vector3> _calculateVelocities(
    DetectedPose previous,
    DetectedPose current,
  ) {
    final velocities = <int, Vector3>{};

    // Time delta in seconds
    final timeDeltaMicros = current.timestampMicros - previous.timestampMicros;
    if (timeDeltaMicros <= 0) return velocities;

    final timeDeltaSeconds = timeDeltaMicros / 1000000.0;

    // Build lookup map for previous landmarks
    final prevLandmarks = <int, Landmark>{};
    for (final landmark in previous.landmarks) {
      prevLandmarks[landmark.id] = landmark;
    }

    // Calculate velocity for each current landmark
    for (final current in current.landmarks) {
      final prev = prevLandmarks[current.id];
      if (prev == null) continue;

      // Check confidence
      if (!GeometryCalculator.areAllReliable(
        [prev, current],
        threshold: _minConfidence,
      )) {
        continue;
      }

      // Calculate displacement
      final dx = current.x - prev.x;
      final dy = current.y - prev.y;
      final dz = current.z - prev.z;

      // Calculate velocity (pixels per second)
      velocities[current.id] = Vector3(
        dx / timeDeltaSeconds,
        dy / timeDeltaSeconds,
        dz / timeDeltaSeconds,
      );
    }

    return velocities;
  }

  /// Get smoothed velocities using average over the history buffer.
  /// More stable but less responsive than instant velocity.
  Map<int, Vector3> getSmoothedVelocities() {
    final poses = _poseHistory.items;
    if (poses.length < 2) return {};

    final oldest = poses.first;
    final newest = poses.last;

    final timeDeltaMicros = newest.timestampMicros - oldest.timestampMicros;
    if (timeDeltaMicros <= 0) return {};

    final timeDeltaSeconds = timeDeltaMicros / 1000000.0;
    final velocities = <int, Vector3>{};

    // Build lookup map for oldest landmarks
    final oldestLandmarks = <int, Landmark>{};
    for (final landmark in oldest.landmarks) {
      oldestLandmarks[landmark.id] = landmark;
    }

    // Calculate average velocity for each landmark
    for (final current in newest.landmarks) {
      final old = oldestLandmarks[current.id];
      if (old == null) continue;

      if (!GeometryCalculator.areAllReliable(
        [old, current],
        threshold: _minConfidence,
      )) {
        continue;
      }

      final dx = current.x - old.x;
      final dy = current.y - old.y;
      final dz = current.z - old.z;

      velocities[current.id] = Vector3(
        dx / timeDeltaSeconds,
        dy / timeDeltaSeconds,
        dz / timeDeltaSeconds,
      );
    }

    return velocities;
  }

  /// Get speed (magnitude of velocity) for a specific landmark.
  /// Returns null if velocity is not available.
  double? getSpeed(int landmarkId, Map<int, Vector3> velocities) {
    final velocity = velocities[landmarkId];
    return velocity?.magnitude;
  }

  /// Check if a landmark is moving significantly.
  /// [threshold] is in pixels per second.
  bool isMoving(
    int landmarkId,
    Map<int, Vector3> velocities, {
    double threshold = 50.0,
  }) {
    final speed = getSpeed(landmarkId, velocities);
    return speed != null && speed > threshold;
  }

  /// Get the direction of movement for a landmark (normalized velocity).
  Vector3? getDirection(int landmarkId, Map<int, Vector3> velocities) {
    final velocity = velocities[landmarkId];
    if (velocity == null || velocity.magnitude < 0.001) return null;
    return velocity.normalized;
  }

  /// Clear all pose history.
  void reset() {
    _poseHistory.clear();
  }

  /// Number of poses currently in history.
  int get historyLength => _poseHistory.length;

  /// Whether enough history exists for velocity calculations.
  bool get hasEnoughHistory => _poseHistory.length >= 2;
}
