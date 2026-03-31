import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';

/// Manages recording state and frame collection during a capture session.
class RecordingService {
  DateTime? _recordingStartTime;
  int? _videoStartTimestampMicros;
  final List<TrackedFrame> _frames = [];
  String? _sessionId;
  Size? _imageSize;

  bool get isRecording => _recordingStartTime != null;

  Duration get recordingDuration => _recordingStartTime == null
      ? Duration.zero
      : DateTime.now().difference(_recordingStartTime!);

  int get frameCount => _frames.length;

  Future<void> startRecording(
    CameraController controller,
    String sessionId,
  ) async {
    _sessionId = sessionId;
    _recordingStartTime = DateTime.now();
    _frames.clear();

    // Record timestamp BEFORE the await — the platform begins recording
    // as soon as it receives the command, so this is the closest
    // approximation of the actual video start time.
    _videoStartTimestampMicros = DateTime.now().microsecondsSinceEpoch;

    await controller.startVideoRecording();
  }

  void recordFrame(
    DetectedPose? pose,
    bool isPersonDetected,
    int captureTimestampMicros,
  ) {
    if (!isRecording || _sessionId == null) return;

    // Discard frames captured before video recording started
    final videoStart = _videoStartTimestampMicros;
    if (videoStart == null || captureTimestampMicros < videoStart) return;

    // Store raw ML Kit image dimensions from the first frame with valid pose
    if (pose != null) {
      _imageSize ??= pose.imageSize;
    }

    final frame = TrackedFrame(
      sessionId: _sessionId!,
      // Use original capture timestamp (not post-detection) relative to video start
      timestampMicros: captureTimestampMicros - videoStart,
      // Store empty landmarks array when no person detected (pose == null)
      landmarks: pose?.landmarks ?? [],
      isPersonDetected: isPersonDetected,
    );

    _frames.add(frame);
  }

  Future<RecordingResult> stopRecording(CameraController controller) async {
    if (!isRecording) throw Exception('Not recording');

    final videoFile = await controller.stopVideoRecording();

    final appDir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${appDir.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${videoDir.path}/session_$timestamp.mp4';
    await File(videoFile.path).copy(newPath);

    try {
      await File(videoFile.path).delete();
    } catch (_) {}

    final duration = recordingDuration;
    final frames = List<TrackedFrame>.from(_frames);
    final imageSize = _imageSize ?? Size.zero;
    final sessionId = _sessionId!;

    _recordingStartTime = null;
    _videoStartTimestampMicros = null;
    _frames.clear();
    _sessionId = null;
    _imageSize = null;

    return RecordingResult(
      sessionId: sessionId,
      videoPath: newPath,
      duration: duration,
      frames: frames,
      imageSize: imageSize,
    );
  }

  void reset() {
    _recordingStartTime = null;
    _videoStartTimestampMicros = null;
    _frames.clear();
    _sessionId = null;
    _imageSize = null;
  }
}

/// Result returned after stopping a recording.
class RecordingResult {
  final String sessionId;
  final String videoPath;
  final Duration duration;
  final List<TrackedFrame> frames;
  final Size imageSize;

  const RecordingResult({
    required this.sessionId,
    required this.videoPath,
    required this.duration,
    required this.frames,
    required this.imageSize,
  });
}
