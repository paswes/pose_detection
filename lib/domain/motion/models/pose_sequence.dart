import 'package:pose_detection/core/data_structures/ring_buffer.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/motion/models/vector3.dart';

/// A sequence of poses over time for temporal analysis.
///
/// Uses a ring buffer to efficiently store a fixed-size history of poses.
/// Provides access to current, previous, and historical poses for
/// calculating velocities, accelerations, and movement patterns.
///
/// This is exercise-agnostic - it simply stores pose history without
/// knowledge of what movements are being performed.
class PoseSequence {
  final RingBuffer<DetectedPose> _buffer;

  /// Maximum number of poses to store
  final int capacity;

  PoseSequence({this.capacity = 30}) : _buffer = RingBuffer(capacity);

  /// Add a new pose to the sequence
  void add(DetectedPose pose) {
    _buffer.add(pose);
  }

  /// Get all poses in chronological order (oldest first)
  List<DetectedPose> get poses => _buffer.items;

  /// Get the most recent pose, or null if empty
  DetectedPose? get current => _buffer.latest;

  /// Get the previous pose (one before current), or null
  DetectedPose? get previous {
    if (_buffer.length < 2) return null;
    return _buffer[_buffer.length - 2];
  }

  /// Get a pose at a specific index (0 = oldest)
  DetectedPose? operator [](int index) => _buffer[index];

  /// Number of poses currently stored
  int get length => _buffer.length;

  /// Whether the sequence is empty
  bool get isEmpty => _buffer.isEmpty;

  /// Whether the sequence has at least 2 poses (enough for velocity)
  bool get hasHistory => _buffer.length >= 2;

  /// Whether the sequence is at capacity
  bool get isFull => _buffer.isFull;

  /// Time span of the sequence in microseconds
  int get durationMicros {
    if (_buffer.length < 2) return 0;
    final oldest = _buffer.oldest;
    final latest = _buffer.latest;
    if (oldest == null || latest == null) return 0;
    return latest.timestampMicros - oldest.timestampMicros;
  }

  /// Time span in seconds
  double get durationSeconds => durationMicros / 1000000.0;

  /// Average frame interval in microseconds
  double get averageFrameIntervalMicros {
    if (_buffer.length < 2) return 0;
    return durationMicros / (_buffer.length - 1);
  }

  /// Average frames per second based on stored poses
  double get averageFps {
    final interval = averageFrameIntervalMicros;
    if (interval <= 0) return 0;
    return 1000000.0 / interval;
  }

  /// Get position history for a specific landmark
  List<Vector3> getLandmarkPositions(int landmarkId) {
    return poses
        .map((pose) => _getLandmarkPosition(pose, landmarkId))
        .whereType<Vector3>()
        .toList();
  }

  /// Get the position of a landmark from a pose
  Vector3? _getLandmarkPosition(DetectedPose pose, int landmarkId) {
    final landmark = pose.landmarks.where((l) => l.id == landmarkId).firstOrNull;
    if (landmark == null) return null;
    return Vector3(landmark.x, landmark.y, landmark.z);
  }

  /// Get timestamps for all poses
  List<int> get timestamps => poses.map((p) => p.timestampMicros).toList();

  /// Calculate velocity for a landmark between current and previous pose
  Vector3? getLandmarkVelocity(int landmarkId) {
    if (!hasHistory) return null;

    final curr = current;
    final prev = previous;
    if (curr == null || prev == null) return null;

    final currPos = _getLandmarkPosition(curr, landmarkId);
    final prevPos = _getLandmarkPosition(prev, landmarkId);
    if (currPos == null || prevPos == null) return null;

    final dtMicros = curr.timestampMicros - prev.timestampMicros;
    if (dtMicros <= 0) return Vector3.zero;

    final dtSeconds = dtMicros / 1000000.0;
    final delta = currPos - prevPos;

    return delta / dtSeconds;
  }

  /// Calculate average velocity over the entire sequence for a landmark
  Vector3? getAverageLandmarkVelocity(int landmarkId) {
    final positions = getLandmarkPositions(landmarkId);
    if (positions.length < 2) return null;

    final durationSec = durationSeconds;
    if (durationSec <= 0) return Vector3.zero;

    final totalDisplacement = positions.last - positions.first;
    return totalDisplacement / durationSec;
  }

  /// Get the path length traveled by a landmark
  double getLandmarkPathLength(int landmarkId) {
    final positions = getLandmarkPositions(landmarkId);
    if (positions.length < 2) return 0;

    double totalLength = 0;
    for (int i = 1; i < positions.length; i++) {
      totalLength += positions[i].distanceTo(positions[i - 1]);
    }
    return totalLength;
  }

  /// Get the average confidence for a landmark across all poses
  double getAverageLandmarkConfidence(int landmarkId) {
    double totalConfidence = 0;
    int count = 0;

    for (final pose in poses) {
      final landmark =
          pose.landmarks.where((l) => l.id == landmarkId).firstOrNull;
      if (landmark != null) {
        totalConfidence += landmark.confidence;
        count++;
      }
    }

    return count > 0 ? totalConfidence / count : 0;
  }

  /// Clear all stored poses
  void clear() {
    _buffer.clear();
  }

  /// Get a sub-sequence of the most recent N poses
  List<DetectedPose> getRecent(int count) {
    final all = poses;
    if (all.length <= count) return all;
    return all.sublist(all.length - count);
  }

  /// Check if any landmark has low confidence in the current pose
  bool get hasLowConfidenceLandmarks {
    final curr = current;
    if (curr == null) return true;
    return curr.landmarks.any((l) => l.confidence < 0.5);
  }

  /// Get the average confidence across all landmarks in current pose
  double get currentAverageConfidence {
    final curr = current;
    if (curr == null) return 0;
    return curr.avgConfidence;
  }
}

/// Extension on Landmark for Vector3 conversion
extension LandmarkVector on Landmark {
  /// Convert landmark position to Vector3
  Vector3 get position => Vector3(x, y, z);
}
