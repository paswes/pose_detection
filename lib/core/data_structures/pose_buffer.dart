import 'package:pose_detection/core/data_structures/ring_buffer.dart';
import 'package:pose_detection/core/interfaces/pose_buffer_interface.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Specialized ring buffer for TimestampedPose.
/// Implements IPoseBuffer interface for dependency injection.
class PoseBuffer implements IPoseBuffer {
  final RingBuffer<TimestampedPose> _buffer;

  PoseBuffer({required int capacity}) : _buffer = RingBuffer(capacity);

  @override
  int get length => _buffer.length;

  @override
  int get capacity => _buffer.capacity;

  @override
  bool get isEmpty => _buffer.isEmpty;

  @override
  bool get isFull => _buffer.isFull;

  @override
  List<TimestampedPose> get poses => _buffer.items;

  @override
  TimestampedPose? get latest => _buffer.latest;

  @override
  void add(TimestampedPose pose) => _buffer.add(pose);

  @override
  void clear() => _buffer.clear();
}
