import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:video_thumbnail/video_thumbnail.dart';

/// Extracts video frames at specific timestamps and decodes them to [ui.Image].
///
/// Used for frame-based playback where each video frame is rendered
/// synchronously alongside landmarks in a single paint pass,
/// eliminating the async lag of VideoPlayer.seekTo().
class FrameImageDecoder {
  /// Extract and decode all frames from a video at the given timestamps.
  ///
  /// [videoPath] — absolute path to the video file.
  /// [timestampsMicros] — list of frame timestamps in microseconds.
  /// [onProgress] — callback with (completed, total) for loading UI.
  ///
  /// Returns a list of [ui.Image] objects, one per timestamp.
  /// If a frame fails to extract, it reuses the last successful frame
  /// (or skips if it's the first).
  Future<List<ui.Image>> decodeAllFrames(
    String videoPath,
    List<int> timestampsMicros, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final images = <ui.Image>[];
    final total = timestampsMicros.length;

    for (var i = 0; i < total; i++) {
      final timestampMs = timestampsMicros[i] ~/ 1000; // micros → millis

      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timestampMs,
          quality: 85,
        );

        if (bytes != null && bytes.isNotEmpty) {
          final image = await _decodeImage(bytes);
          images.add(image);
        } else if (images.isNotEmpty) {
          // Reuse last successful frame
          images.add(images.last);
        }
      } catch (_) {
        // On failure, reuse last frame if available
        if (images.isNotEmpty) {
          images.add(images.last);
        }
      }

      onProgress?.call(i + 1, total);
    }

    return images;
  }

  /// Decode JPEG bytes to a [ui.Image].
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    codec.dispose();
    return frameInfo.image;
  }
}
