import 'package:camera/camera.dart';
import 'package:pose_detection/core/interfaces/frame_processor_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';

/// Orchestrates frame processing pipeline.
/// Handles pose detection and latency measurement.
class FrameProcessor implements IFrameProcessor {
  final IPoseDetector _poseDetector;

  FrameProcessor({required IPoseDetector poseDetector})
      : _poseDetector = poseDetector;

  @override
  Future<FrameProcessingResult> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required int frameIndex,
    required int timestampMicros,
    int? previousTimestampMicros,
  }) async {
    final startTime = DateTime.now();

    try {
      final pose = await _poseDetector.detectPose(
        image: image,
        sensorOrientation: sensorOrientation,
        frameIndex: frameIndex,
        cameraTimestampMicros: timestampMicros,
        previousTimestampMicros: previousTimestampMicros,
      );

      final processingLatencyMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      final endToEndLatencyMs = (nowMicros - timestampMicros) / 1000.0;

      return FrameProcessingResult.success(
        pose: pose,
        processingLatencyMs: processingLatencyMs,
        endToEndLatencyMs: endToEndLatencyMs,
      );
    } catch (e) {
      final processingLatencyMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      return FrameProcessingResult.failure(
        error: e.toString(),
        processingLatencyMs: processingLatencyMs,
      );
    }
  }

  @override
  void dispose() {
    _poseDetector.dispose();
  }
}
