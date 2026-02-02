import 'dart:ui';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/error_tracker.dart';
import 'package:pose_detection/core/services/frame_processor.dart';
import 'package:pose_detection/core/services/session_manager.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';

/// Simplified BLoC for pose detection - orchestration only.
/// All business logic delegated to specialized services.
class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  final ICameraService _cameraService;
  final FrameProcessor _frameProcessor;
  final SessionManager _sessionManager;
  final ErrorTracker _errorTracker;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;

  PoseDetectionBloc({
    required ICameraService cameraService,
    required IPoseDetector poseDetector,
    required PoseDetectionConfig config,
  })  : _cameraService = cameraService,
        _frameProcessor = FrameProcessor(poseDetector: poseDetector),
        _sessionManager = SessionManager(config: config),
        _errorTracker = ErrorTracker(config: config),
        super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    on<ProcessFrameEvent>(_onProcessFrame, transformer: droppable());
    on<DisposeEvent>(_onDispose);
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
      emit(CameraReady(controller, lastSession: _sessionManager.lastSession));
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
    _sessionManager.startSession();

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      emit(PoseDetectionError('Camera not initialized'));
      return;
    }

    emit(Detecting(
      cameraController: controller,
      session: _sessionManager.getCurrentSessionSnapshot()!,
    ));

    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _isStreamingActive = true;
      _cameraService.startImageStream((image) {
        if (_sessionManager.hasActiveSession && _isStreamingActive) {
          final timestampMicros = DateTime.now().microsecondsSinceEpoch;

          if (!_isProcessingFrame) {
            add(ProcessFrameEvent(
              image,
              cameraDescription.sensorOrientation,
              timestampMicros,
            ));
          } else {
            _sessionManager.recordDroppedFrame();
          }
        }
      });
    }

    Logger.info('Bloc', 'Capture session started');
  }

  Future<void> _onStopCapture(
    StopCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _cameraService.stopImageStream();
    _isStreamingActive = false;

    _sessionManager.endSession();

    if (_sessionManager.lastSession != null) {
      emit(SessionSummary(
        cameraController: _cameraService.controller!,
        session: _sessionManager.lastSession!,
      ));
    }

    Logger.info('Bloc', 'Capture session stopped');
  }

  Future<void> _onProcessFrame(
    ProcessFrameEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isProcessingFrame || !_sessionManager.hasActiveSession) return;
    _isProcessingFrame = true;

    try {
      _sessionManager.recordReceivedFrame();

      final result = await _frameProcessor.processFrame(
        image: event.image,
        sensorOrientation: event.sensorOrientation,
        frameIndex: _sessionManager.nextFrameIndex(),
        timestampMicros: event.timestampMicros,
        previousTimestampMicros: _sessionManager.previousTimestampMicros,
      );

      if (result.success) {
        _errorTracker.recordSuccess();

        if (result.pose != null) {
          _sessionManager.addPose(result.pose!);
        }

        _sessionManager.recordProcessedFrame(
          poseDetected: result.pose != null,
          latencyMs: result.processingLatencyMs,
          endToEndLatencyMs: result.endToEndLatencyMs,
        );

        _emitDetectingState(emit, event, result);
      } else {
        _handleError(emit, result.errorMessage ?? 'Unknown error');
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

  void _emitDetectingState(
    Emitter<PoseDetectionState> emit,
    ProcessFrameEvent event,
    dynamic result,
  ) {
    if (state is Detecting) {
      emit((state as Detecting).copyWith(
        currentPose: result.pose,
        imageSize: Size(
          event.image.width.toDouble(),
          event.image.height.toDouble(),
        ),
        session: _sessionManager.getCurrentSessionSnapshot()!,
      ));
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
