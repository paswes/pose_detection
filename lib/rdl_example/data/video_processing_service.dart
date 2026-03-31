import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:pose_detection/rdl_example/data/static_image_pose_detector.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

/// Result of processing an uploaded video through pose detection.
class VideoProcessingResult {
  final String sessionId;
  final String videoPath;
  final int durationMs;
  final List<TrackedFrame> frames;
  final double imageWidth;
  final double imageHeight;

  const VideoProcessingResult({
    required this.sessionId,
    required this.videoPath,
    required this.durationMs,
    required this.frames,
    required this.imageWidth,
    required this.imageHeight,
  });
}

/// Orchestrates the video upload processing pipeline:
///
/// 1. Copy video to app documents directory
/// 2. Read video metadata (duration, dimensions)
/// 3. Extract frames at ~30 FPS using video_thumbnail
/// 4. Run ML Kit pose detection on each frame
/// 5. Assemble [TrackedFrame] list with raw landmarks
class VideoProcessingService {
  final StaticImagePoseDetector _poseDetector;

  static const int _targetFps = 30;

  VideoProcessingService({
    required StaticImagePoseDetector poseDetector,
  }) : _poseDetector = poseDetector;

  /// Process a video file for pose detection.
  ///
  /// [sourcePath] — path to the picked video file (from image_picker).
  /// [sessionId] — unique session identifier.
  /// [onProgress] — callback with (completedFrames, totalFrames).
  Future<VideoProcessingResult> processVideo(
    String sourcePath,
    String sessionId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final videoPath = await _copyToDocuments(sourcePath, sessionId);
    final metadata = await _getVideoMetadata(videoPath);
    final timestampsMs = _generateTimestamps(durationMs: metadata.durationMs);
    final frames = <TrackedFrame>[];
    final tempDir = await _createTempFrameDir(sessionId);

    for (var i = 0; i < timestampsMs.length; i++) {
      final timestampMs = timestampsMs[i];
      final timestampMicros = timestampMs * 1000;

      // Extract frame to temp JPEG file
      final framePath = await _extractFrame(
        videoPath,
        timestampMs,
        tempDir,
        i,
      );

      if (framePath == null) {
        frames.add(
          TrackedFrame(
            sessionId: sessionId,
            timestampMicros: timestampMicros,
            landmarks: const [],
            isPersonDetected: false,
          ),
        );
        onProgress?.call(i + 1, timestampsMs.length);
        continue;
      }

      final pose = await _poseDetector.detectPoseFromFile(
        framePath,
        imageWidth: metadata.width,
        imageHeight: metadata.height,
      );

      frames.add(
        TrackedFrame(
          sessionId: sessionId,
          timestampMicros: timestampMicros,
          landmarks: pose?.landmarks ?? const [],
          isPersonDetected: pose != null,
        ),
      );

      try {
        await File(framePath).delete();
      } catch (_) {}

      onProgress?.call(i + 1, timestampsMs.length);
    }

    await _cleanupTempDir(tempDir);

    return VideoProcessingResult(
      sessionId: sessionId,
      videoPath: videoPath,
      durationMs: metadata.durationMs,
      frames: frames,
      imageWidth: metadata.width,
      imageHeight: metadata.height,
    );
  }

  /// Copy video from picker temp location to app documents.
  Future<String> _copyToDocuments(String sourcePath, String sessionId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(p.join(docsDir.path, 'videos'));
    if (!videosDir.existsSync()) {
      await videosDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath);
    final destPath = p.join(videosDir.path, 'session_$sessionId$extension');

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Read video duration and dimensions.
  Future<_VideoMetadata> _getVideoMetadata(String videoPath) async {
    final controller = VideoPlayerController.file(File(videoPath));
    await controller.initialize();

    final duration = controller.value.duration;
    final size = controller.value.size;

    await controller.dispose();

    return _VideoMetadata(
      durationMs: duration.inMilliseconds,
      width: size.width,
      height: size.height,
    );
  }

  /// Generate frame timestamps at ~30 FPS.
  List<int> _generateTimestamps({required int durationMs}) {
    final intervalMs = (1000 / _targetFps).round();
    final timestamps = <int>[];
    for (var ms = 0; ms < durationMs; ms += intervalMs) {
      timestamps.add(ms);
    }
    return timestamps;
  }

  /// Extract a single frame from the video to a temp JPEG file.
  Future<String?> _extractFrame(
    String videoPath,
    int timestampMs,
    String tempDir,
    int index,
  ) async {
    try {
      final framePath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir,
        imageFormat: ImageFormat.JPEG,
        timeMs: timestampMs,
        quality: 85,
      );
      return framePath;
    } catch (_) {
      return null;
    }
  }

  /// Create a temporary directory for frame extraction.
  Future<String> _createTempFrameDir(String sessionId) async {
    final tempDir = await getTemporaryDirectory();
    final frameDir = Directory(
      p.join(tempDir.path, 'pose_frames_$sessionId'),
    );
    if (!frameDir.existsSync()) {
      await frameDir.create(recursive: true);
    }
    return frameDir.path;
  }

  /// Clean up the temporary frame directory.
  Future<void> _cleanupTempDir(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

class _VideoMetadata {
  final int durationMs;
  final double width;
  final double height;

  const _VideoMetadata({
    required this.durationMs,
    required this.width,
    required this.height,
  });
}
