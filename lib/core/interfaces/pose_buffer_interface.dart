import 'package:pose_detection/domain/models/motion_data.dart';

/// Abstract interface for pose storage with capacity limits.
/// Enables different buffer implementations (ring buffer, unlimited, etc.)
abstract class IPoseBuffer {
  /// Current number of poses in buffer
  int get length;

  /// Maximum capacity
  int get capacity;

  /// Whether buffer is empty
  bool get isEmpty;

  /// Whether buffer is at capacity
  bool get isFull;

  /// Get all poses (read-only)
  List<TimestampedPose> get poses;

  /// Get most recent pose
  TimestampedPose? get latest;

  /// Add a pose to the buffer
  void add(TimestampedPose pose);

  /// Clear all poses
  void clear();
}
