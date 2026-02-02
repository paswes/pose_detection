import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/error_tracker.dart';
import 'package:pose_detection/core/services/frame_processor.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';

/// Simplified BLoC for pose detection - orchestration only.
/// No session management, just real-time pose detection with metrics.
class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  final ICameraService _cameraService;
  final FrameProcessor _frameProcessor;
  final ErrorTracker _errorTracker;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;

  // FPS calculation using rolling window
  final List<int> _frameTimestamps = [];
  static const _fpsWindowMs = 1000;

  // Current metrics
  double _lastLatencyMs = 0.0;

  PoseDetectionBloc({
    required ICameraService cameraService,
    required IPoseDetector poseDetector,
    required PoseDetectionConfig config,
  })  : _cameraService = cameraService,
        _frameProcessor = FrameProcessor(poseDetector: poseDetector),
        _errorTracker = ErrorTracker(config: config),
        super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<ProcessFrameEvent>(_onProcessFrame, transformer: droppable());
    on<DisposeEvent>(_onDispose);
  }

  double _calculateFps() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameTimestamps.removeWhere((t) => now - t > _fpsWindowMs);
    return _frameTimestamps.length.toDouble();
  }

  void _recordFrame() {
    _frameTimestamps.add(DateTime.now().millisecondsSinceEpoch);
  }

  void _resetMetrics() {
    _frameTimestamps.clear();
    _lastLatencyMs = 0.0;
  }

  Future<void> _onInitialize(
    InitializeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    try {
      emit(CameraInitializing());
      await _cameraService.initialize();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Camera controller not properly initialized');
      }

      Logger.info('Bloc', 'Camera initialized');
      emit(CameraReady(controller));
    } catch (e) {
      Logger.error('Bloc', 'ERROR initializing: $e');
      emit(PoseDetectionError('Failed to initialize camera: $e'));
    }
  }

  Future<void> _onStartCapture(
    StartCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isStreamingActive) {
      _cameraService.stopImageStream();
      _isStreamingActive = false;
    }

    _errorTracker.reset();
    _resetMetrics();

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      emit(PoseDetectionError('Camera not initialized'));
      return;
    }

    emit(Detecting(
      cameraController: controller,
      canSwitchCamera: _cameraService.canSwitchCamera,
      isFrontCamera: _cameraService.currentLensDirection == CameraLensDirection.front,
    ));

    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _isStreamingActive = true;
      _cameraService.startImageStream((image) {
        if (_isStreamingActive) {
          final timestampMicros = DateTime.now().microsecondsSinceEpoch;

          if (!_isProcessingFrame) {
            add(ProcessFrameEvent(
              image,
              cameraDescription.sensorOrientation,
              timestampMicros,
            ));
          }
          // Dropped frames are simply not processed - no tracking needed
        }
      });
    }

    Logger.info('Bloc', 'Detection started');
  }

  Future<void> _onStopCapture(
    StopCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _cameraService.stopImageStream();
    _isStreamingActive = false;

    emit(CameraReady(_cameraService.controller!));

    Logger.info('Bloc', 'Detection stopped');
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (!_cameraService.canSwitchCamera) return;

    final wasDetecting = state is Detecting;
    final previousPose = wasDetecting ? (state as Detecting).currentPose : null;
    final previousMetrics = wasDetecting ? (state as Detecting).metrics : const DetectionMetrics();

    try {
      emit(CameraInitializing());
      await _cameraService.switchCamera();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Camera controller not properly initialized after switch');
      }

      if (wasDetecting) {
        // Restart image stream for detection
        final cameraDescription = _cameraService.getCameraDescription();
        if (cameraDescription != null && !_isStreamingActive) {
          _isStreamingActive = true;
          _cameraService.startImageStream((image) {
            if (_isStreamingActive) {
              final timestampMicros = DateTime.now().microsecondsSinceEpoch;

              if (!_isProcessingFrame) {
                add(ProcessFrameEvent(
                  image,
                  cameraDescription.sensorOrientation,
                  timestampMicros,
                ));
              }
            }
          });
        }

        emit(Detecting(
          cameraController: controller,
          currentPose: previousPose,
          metrics: previousMetrics,
          canSwitchCamera: _cameraService.canSwitchCamera,
          isFrontCamera: _cameraService.currentLensDirection == CameraLensDirection.front,
        ));
      } else {
        emit(CameraReady(controller));
      }

      Logger.info('Bloc', 'Camera switched to ${_cameraService.currentLensDirection}');
    } catch (e) {
      Logger.error('Bloc', 'ERROR switching camera: $e');
      emit(PoseDetectionError('Failed to switch camera: $e'));
    }
  }

  Future<void> _onProcessFrame(
    ProcessFrameEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final result = await _frameProcessor.processFrame(
        image: event.image,
        sensorOrientation: event.sensorOrientation,
        captureTimestampMicros: event.timestampMicros,
      );

      if (result.success) {
        _errorTracker.recordSuccess();
        _recordFrame();
        _lastLatencyMs = result.latencyMs;

        if (state is Detecting) {
          emit((state as Detecting).copyWith(
            currentPose: result.pose,
            metrics: DetectionMetrics(
              fps: _calculateFps(),
              latencyMs: _lastLatencyMs,
            ),
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera: _cameraService.currentLensDirection == CameraLensDirection.front,
          ));
        }
      } else {
        _handleError(emit, result.error ?? 'Unknown error');
      }
    } catch (e) {
      _handleError(emit, e.toString());
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleError(Emitter<PoseDetectionState> emit, String message) {
    _errorTracker.recordError();
    Logger.error(
      'Bloc',
      'ERROR: $message (${_errorTracker.consecutiveErrors}/${_errorTracker.maxConsecutiveErrors})',
    );

    if (_errorTracker.hasExceededThreshold) {
      _cameraService.stopImageStream();
      _isStreamingActive = false;
      emit(PoseDetectionError('Too many consecutive errors. Last: $message'));
    }
  }

  Future<void> _onDispose(
    DisposeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _cameraService.dispose();
    _frameProcessor.dispose();
  }
}
