import 'dart:ui' as ui;

import 'package:pose_detection/core/services/frame_image_decoder.dart';

/// Sliding window cache for decoded video frame images.
///
/// Keeps at most [_maxCacheSize] frames in memory at any time,
/// evicting and disposing frames furthest from the current playhead.
/// Prefetches frames ahead of the playhead for smooth playback.
class FrameImageCache {
  final String videoPath;
  final List<int> timestampsMicros;
  final FrameImageDecoder _decoder;

  final Map<int, ui.Image> _cache = {};
  final Set<int> _pendingDecodes = {};

  static const int _maxCacheSize = 20;
  static const int _prefetchAhead = 10;
  static const int _prefetchBehind = 2;

  FrameImageCache({
    required this.videoPath,
    required this.timestampsMicros,
    required FrameImageDecoder decoder,
  }) : _decoder = decoder;

  int get totalFrames => timestampsMicros.length;

  /// Get the decoded image for [index].
  ///
  /// Returns immediately if cached, otherwise decodes on-demand.
  /// Returns `null` if decoding fails.
  Future<ui.Image?> getFrame(int index) async {
    if (index < 0 || index >= timestampsMicros.length) return null;

    final cached = _cache[index];
    if (cached != null) return cached;

    return _decodeAndCache(index);
  }

  /// Prefetch frames around [index] for smooth playback.
  ///
  /// Decodes frames in [index - _prefetchBehind .. index + _prefetchAhead]
  /// and evicts frames outside this window.
  void prefetchAround(int index) {
    final start = (index - _prefetchBehind).clamp(0, totalFrames - 1);
    final end = (index + _prefetchAhead).clamp(0, totalFrames - 1);

    // Kick off decodes for uncached frames in the window
    for (var i = start; i <= end; i++) {
      if (!_cache.containsKey(i) && !_pendingDecodes.contains(i)) {
        _decodeAndCache(i);
      }
    }

    // Evict frames outside the window if over budget
    _evictIfNeeded(index);
  }

  /// Dispose all cached images and clear state.
  void dispose() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _pendingDecodes.clear();
  }

  Future<ui.Image?> _decodeAndCache(int index) async {
    if (_pendingDecodes.contains(index)) return null;
    _pendingDecodes.add(index);

    try {
      final image = await _decoder.decodeSingleFrame(
        videoPath,
        timestampsMicros[index],
      );

      _pendingDecodes.remove(index);

      if (image != null) {
        _cache[index] = image;
        return image;
      }
    } catch (_) {
      _pendingDecodes.remove(index);
    }

    return null;
  }

  /// Evict cached frames furthest from [currentIndex] when over budget.
  void _evictIfNeeded(int currentIndex) {
    while (_cache.length > _maxCacheSize) {
      // Find the cached frame furthest from currentIndex
      int? furthestIndex;
      int maxDistance = -1;

      for (final cachedIndex in _cache.keys) {
        final distance = (cachedIndex - currentIndex).abs();
        if (distance > maxDistance) {
          maxDistance = distance;
          furthestIndex = cachedIndex;
        }
      }

      if (furthestIndex != null) {
        final evicted = _cache.remove(furthestIndex);
        evicted?.dispose();
      } else {
        break;
      }
    }
  }
}
