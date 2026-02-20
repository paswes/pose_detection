import 'package:pose_detection/data/models/tracked_frame.dart';

/// Manages video-to-landmark frame synchronization with lag compensation.
///
/// Uses binary search on pre-extracted timestamps for O(log n) frame lookup
/// during continuous playback, and O(1) index-based lookup for frame-stepping.
class PlaybackSyncEngine {
  final List<TrackedFrame> _frames;
  final List<int> _offsetsMicros;

  /// Forward offset to compensate for VideoPlayer position reporting lag on iOS.
  /// The video_player package reports position ~30-80ms behind the rendered frame.
  int lagOffsetMicros;

  PlaybackSyncEngine({
    required List<TrackedFrame> frames,
    this.lagOffsetMicros = 50000, // 50ms default
  }) : _frames = frames,
       _offsetsMicros = frames.map((f) => f.timestampMicros).toList();

  /// Total number of recorded frames.
  int get frameCount => _frames.length;

  /// Whether any frames are available.
  bool get hasFrames => _frames.isNotEmpty;

  /// Get frame by direct index for frame-stepping mode.
  TrackedFrame? getFrameByIndex(int index) {
    if (index < 0 || index >= _frames.length) return null;
    return _frames[index];
  }

  /// Find the frame pair bracketing the given video position.
  ///
  /// Returns `(frameA, frameB, t)` where:
  /// - `frameA` is the frame at or before the target time
  /// - `frameB` is the next frame (null if `frameA` is the last frame)
  /// - `t` is the interpolation factor (0.0 = frameA, 1.0 = frameB)
  ///
  /// Applies [lagOffsetMicros] to compensate for VideoPlayer reporting delay.
  /// Returns null if no frames exist.
  ({TrackedFrame frameA, TrackedFrame? frameB, double t})? findFramePair(
    Duration position,
  ) {
    if (_frames.isEmpty || _offsetsMicros.isEmpty) return null;

    final targetMicros = position.inMicroseconds + lagOffsetMicros;

    // Clamp to valid range
    if (targetMicros <= _offsetsMicros.first) {
      return (frameA: _frames.first, frameB: null, t: 0.0);
    }
    if (targetMicros >= _offsetsMicros.last) {
      return (frameA: _frames.last, frameB: null, t: 0.0);
    }

    // Binary search for the insertion point
    int low = 0;
    int high = _offsetsMicros.length - 1;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_offsetsMicros[mid] < targetMicros) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    // low now points to the first offset >= targetMicros
    // The frame before is at low - 1
    final indexB = low;
    final indexA = low - 1;

    if (indexA < 0) {
      return (frameA: _frames[indexB], frameB: null, t: 0.0);
    }

    final timeA = _offsetsMicros[indexA];
    final timeB = _offsetsMicros[indexB];
    final range = timeB - timeA;

    // Compute interpolation factor
    final t = range > 0 ? (targetMicros - timeA) / range : 0.0;

    return (
      frameA: _frames[indexA],
      frameB: _frames[indexB],
      t: t.clamp(0.0, 1.0),
    );
  }

  /// Find the nearest frame index for a given video position.
  /// Used for syncing frame-step mode with slider position.
  int findNearestFrameIndex(Duration position) {
    if (_frames.isEmpty) return 0;

    final targetMicros = position.inMicroseconds;

    int low = 0;
    int high = _offsetsMicros.length - 1;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_offsetsMicros[mid] < targetMicros) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    // Check neighbor for closer match
    if (low > 0) {
      final diffLow = (targetMicros - _offsetsMicros[low - 1]).abs();
      final diffHigh = (targetMicros - _offsetsMicros[low]).abs();
      if (diffLow < diffHigh) return low - 1;
    }

    return low;
  }
}
