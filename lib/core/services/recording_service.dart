import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/person_detection_result.dart';

/// Manages recording state and frame collection during a capture session.
class RecordingService {
  DateTime? _recordingStartTime;
  final List<TrackedFrame> _frames = [];
  String? _sessionId;

  bool get isRecording => _recordingStartTime != null;

  Duration get recordingDuration => _recordingStartTime == null
      ? Duration.zero
      : DateTime.now().difference(_recordingStartTime!);

  int get frameCount => _frames.length;

  Future<void> startRecording(CameraController controller, String sessionId) async {
    _sessionId = sessionId;
    _recordingStartTime = DateTime.now();
    _frames.clear();

    await controller.startVideoRecording();
  }

  void recordFrame(DetectedPose? pose, PersonDetectionResult personDetection) {
    if (!isRecording || _sessionId == null) return;
    if (pose == null) return;

    final frame = TrackedFrame(
      sessionId: _sessionId!,
      timestampMicros: pose.timestampMicros,
      landmarks: pose.landmarks.map((l) => LandmarkData.fromLandmark(l)).toList(),
      isPersonDetected: personDetection.isPersonDetected,
      personConfidence: pose.avgConfidence,
    );

    _frames.add(frame);
  }

  Future<RecordingResult> stopRecording(CameraController controller) async {
    if (!isRecording) throw Exception('Not recording');

    final videoFile = await controller.stopVideoRecording();

    // Move video to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${appDir.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '${videoDir.path}/session_$timestamp.mp4';
    await File(videoFile.path).copy(newPath);

    // Clean up temp file
    try {
      await File(videoFile.path).delete();
    } catch (_) {}

    final duration = recordingDuration;
    final frames = List<TrackedFrame>.from(_frames);

    // Reset state
    _recordingStartTime = null;
    _frames.clear();
    _sessionId = null;

    return RecordingResult(
      videoPath: newPath,
      duration: duration,
      frames: frames,
    );
  }

  void reset() {
    _recordingStartTime = null;
    _frames.clear();
    _sessionId = null;
  }
}

/// Result returned after stopping a recording.
class RecordingResult {
  final String videoPath;
  final Duration duration;
  final List<TrackedFrame> frames;

  const RecordingResult({
    required this.videoPath,
    required this.duration,
    required this.frames,
  });
}
