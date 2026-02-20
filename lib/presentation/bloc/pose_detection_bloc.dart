import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/error_tracker.dart';
import 'package:pose_detection/core/services/frame_processor.dart';
import 'package:pose_detection/core/services/recording_service.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';

/// BLoC for pose detection with session recording support.
class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  final ICameraService _cameraService;
  final FrameProcessor _frameProcessor;
  final ErrorTracker _errorTracker;
  final IPersonValidator _personValidator;
  final RecordingService _recordingService;
  final SessionRepository _sessionRepository;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;
  Timer? _recordingTimer;
  RecordingResult? _pendingResult;

  // FPS calculation using rolling window
  final List<int> _frameTimestamps = [];
  static const _fpsWindowMs = 1000;

  // Current metrics
  double _lastLatencyMs = 0.0;

  PoseDetectionBloc({
    required ICameraService cameraService,
    required IPoseDetector poseDetector,
    required PoseDetectionConfig config,
    required IPersonValidator personValidator,
    required RecordingService recordingService,
    required SessionRepository sessionRepository,
  }) : _cameraService = cameraService,
       _frameProcessor = FrameProcessor(poseDetector: poseDetector),
       _errorTracker = ErrorTracker(config: config),
       _personValidator = personValidator,
       _recordingService = recordingService,
       _sessionRepository = sessionRepository,
       super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<ChangeOrientationEvent>(_onChangeOrientation);
    on<ProcessFrameEvent>(_onProcessFrame, transformer: droppable());
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<SaveSessionEvent>(_onSaveSession);
    on<RecordingTickEvent>(_onRecordingTick);
    on<DisposeEvent>(_onDispose);
  }

  double _calculateFps() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameTimestamps.removeWhere((t) => now - t > _fpsWindowMs);
    return _frameTimestamps.length.toDouble();
  }

  void _recordFpsFrame() {
    _frameTimestamps.add(DateTime.now().millisecondsSinceEpoch);
  }

  void _resetMetrics() {
    _frameTimestamps.clear();
    _lastLatencyMs = 0.0;
  }

  void _startImageStream() {
    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _isStreamingActive = true;
      _cameraService.startImageStream((image) {
        if (_isStreamingActive) {
          final timestampMicros = DateTime.now().microsecondsSinceEpoch;

          if (!_isProcessingFrame) {
            add(
              ProcessFrameEvent(
                image,
                cameraDescription.sensorOrientation,
                timestampMicros,
              ),
            );
          }
        }
      });
    }
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

    emit(
      Detecting(
        cameraController: controller,
        canSwitchCamera: _cameraService.canSwitchCamera,
        isFrontCamera:
            _cameraService.currentLensDirection == CameraLensDirection.front,
      ),
    );

    _startImageStream();

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

  Future<void> _onStartRecording(
    StartRecordingEvent event,
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

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Start image stream before video recording (iOS requires this order)
      _startImageStream();

      await _recordingService.startRecording(controller, sessionId);

      emit(
        Recording(
          cameraController: controller,
          isFrontCamera:
              _cameraService.currentLensDirection == CameraLensDirection.front,
        ),
      );

      // Timer to update recording duration via event
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (state is Recording) {
          add(RecordingTickEvent());
        }
      });

      Logger.info('Bloc', 'Recording started (session: $sessionId)');
    } catch (e) {
      Logger.error('Bloc', 'ERROR starting recording: $e');
      _recordingService.reset();
      emit(PoseDetectionError('Failed to start recording: $e'));
    }
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    _cameraService.stopImageStream();
    _isStreamingActive = false;
    _isProcessingFrame = false;

    try {
      final controller = _cameraService.controller;
      if (controller == null) {
        throw Exception('Camera controller not available');
      }

      _pendingResult = await _recordingService.stopRecording(controller);

      Logger.info('Bloc', 'Recording stopped (${_pendingResult!.frames.length} frames)');
      emit(RecordingStopped());
    } catch (e) {
      Logger.error('Bloc', 'ERROR stopping recording: $e');
      _recordingService.reset();
      emit(PoseDetectionError('Failed to stop recording: $e'));
    }
  }

  Future<void> _onSaveSession(
    SaveSessionEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    final result = _pendingResult;
    if (result == null) {
      emit(PoseDetectionError('No recording to save'));
      return;
    }

    emit(SavingSession());

    try {
      final sensorOrientation =
          _cameraService.getCameraDescription()?.sensorOrientation ?? 90;

      final session = Session(
        id: result.sessionId,
        title: event.title,
        createdAt: DateTime.now(),
        durationMs: result.duration.inMilliseconds,
        videoPath: result.videoPath,
        frameCount: result.frames.length,
        isFrontCamera: _cameraService.currentLensDirection == CameraLensDirection.front,
        isLandscape: _cameraService.currentOrientation != DeviceOrientation.portraitUp,
        imageWidth: result.imageSize.width,
        imageHeight: result.imageSize.height,
        sensorOrientation: sensorOrientation,
      );

      await _sessionRepository.saveSession(session, result.frames);
      _pendingResult = null;

      Logger.info('Bloc', 'Session saved: ${session.id} (${result.frames.length} frames)');
      emit(SessionSaved(session.id));
    } catch (e) {
      Logger.error('Bloc', 'ERROR saving session: $e');
      emit(PoseDetectionError('Failed to save session: $e'));
    }
  }

  void _onRecordingTick(
    RecordingTickEvent event,
    Emitter<PoseDetectionState> emit,
  ) {
    if (state is Recording) {
      emit(
        (state as Recording).copyWith(
          recordingDuration: _recordingService.recordingDuration,
          frameCount: _recordingService.frameCount,
        ),
      );
    }
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (!_cameraService.canSwitchCamera) return;
    // Don't allow camera switch during recording
    if (state is Recording) return;

    final wasDetecting = state is Detecting;
    final previousPose = wasDetecting ? (state as Detecting).currentPose : null;
    final previousMetrics = wasDetecting
        ? (state as Detecting).metrics
        : const DetectionMetrics();

    try {
      emit(CameraInitializing());
      await _cameraService.switchCamera();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception(
          'Camera controller not properly initialized after switch',
        );
      }

      if (wasDetecting) {
        _startImageStream();

        emit(
          Detecting(
            cameraController: controller,
            currentPose: previousPose,
            metrics: previousMetrics,
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera:
                _cameraService.currentLensDirection ==
                CameraLensDirection.front,
          ),
        );
      } else {
        emit(CameraReady(controller));
      }

      Logger.info(
        'Bloc',
        'Camera switched to ${_cameraService.currentLensDirection}',
      );
    } catch (e) {
      Logger.error('Bloc', 'ERROR switching camera: $e');
      emit(PoseDetectionError('Failed to switch camera: $e'));
    }
  }

  Future<void> _onChangeOrientation(
    ChangeOrientationEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    final wasDetecting = state is Detecting;
    final previousMetrics = wasDetecting
        ? (state as Detecting).metrics
        : const DetectionMetrics();

    try {
      emit(CameraInitializing());
      await _cameraService.setOrientation(event.orientation);

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception(
          'Camera controller not properly initialized after orientation change',
        );
      }

      if (wasDetecting) {
        _startImageStream();

        emit(
          Detecting(
            cameraController: controller,
            currentPose: null, // Clear pose since image dimensions changed
            metrics: previousMetrics,
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera:
                _cameraService.currentLensDirection ==
                CameraLensDirection.front,
          ),
        );
      } else {
        emit(CameraReady(controller));
      }

      Logger.info('Bloc', 'Orientation changed to ${event.orientation}');
    } catch (e) {
      Logger.error('Bloc', 'ERROR changing orientation: $e');
      emit(PoseDetectionError('Failed to change orientation: $e'));
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
        _recordFpsFrame();
        _lastLatencyMs = result.latencyMs;

        // Only process frames during active recording.
        // Detection is not needed in idle/preview states.
        if (state is! Recording) return;

        final personDetection = _personValidator.validate(result.pose);

        // Only record frames with a validated person detection.
        // This ensures stored data matches what is painted on screen.
        if (personDetection.isPersonDetected) {
          _recordingService.recordFrame(
            result.pose,
            personDetection,
            event.timestampMicros,
          );
        }

        emit(
          (state as Recording).copyWith(
            currentPose: personDetection.isPersonDetected ? result.pose : null,
            clearPose: !personDetection.isPersonDetected,
            metrics: DetectionMetrics(
              fps: _calculateFps(),
              latencyMs: _lastLatencyMs,
            ),
            personDetection: personDetection,
            frameCount: _recordingService.frameCount,
          ),
        );
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
    _recordingTimer?.cancel();
    _cameraService.dispose();
    _frameProcessor.dispose();
  }
}
