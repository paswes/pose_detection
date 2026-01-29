import 'dart:async';
import 'dart:ui';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/domain/models/session_metrics.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';

/// Generic BLoC for pose detection - provides raw motion data with metrics
class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  final CameraService _cameraService;
  final PoseDetectionService _poseDetectionService;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;
  PoseSession? _currentSession;
  PoseSession? _lastSession;
  int _frameIndex = 0;
  int? _previousTimestampMicros;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 10;

  /// Maximum number of poses to keep in memory (ring buffer)
  /// At 30 FPS, 900 poses = 30 seconds of data
  static const int _maxPosesInMemory = 900;

  PoseDetectionBloc({
    required CameraService cameraService,
    required PoseDetectionService poseDetectionService,
  }) : _cameraService = cameraService,
       _poseDetectionService = poseDetectionService,
       super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    // Use droppable transformer for high-frequency frame events
    // This automatically drops events that arrive while processing
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

      Logger.info(
        'Bloc',
        'Camera initialized with resolution: ${controller.value.previewSize}',
      );

      emit(CameraReady(controller, lastSession: _lastSession));
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
      Logger.warning(
        'Bloc',
        'Stream already active, stopping existing stream first',
      );
      _cameraService.stopImageStream();
      _isStreamingActive = false;
    }

    Logger.info('Bloc', 'Starting pose capture session...');

    // Reset state for new session
    _frameIndex = 0;
    _previousTimestampMicros = null;
    _consecutiveErrors = 0;

    // Initialize new session with empty metrics
    _currentSession = PoseSession(
      startTime: DateTime.now(),
      capturedPoses: [],
      metrics: const SessionMetrics(),
    );

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      emit(PoseDetectionError('Camera not initialized'));
      return;
    }

    // Emit detecting state
    emit(
      Detecting(
        cameraController: controller,
        session: _currentSession!,
      ),
    );

    // Start image stream
    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _isStreamingActive = true;
      _cameraService.startImageStream((image) {
        // Track received frames (including dropped ones)
        if (_currentSession != null && _isStreamingActive) {
          // Use system time as fallback if camera doesn't provide timestamp
          final timestampMicros = DateTime.now().microsecondsSinceEpoch;

          if (!_isProcessingFrame) {
            // Can process - add to event queue
            add(
              ProcessFrameEvent(
                image,
                cameraDescription.sensorOrientation,
                timestampMicros,
              ),
            );
          } else {
            // Back-pressure: frame will be dropped
            _updateMetricsForDroppedFrame();
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
    Logger.info('Bloc', 'Stopping capture session...');

    _cameraService.stopImageStream();

    if (_currentSession != null) {
      // Finalize session
      final finalSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
      );

      _lastSession = finalSession;
      _currentSession = null;

      Logger.info('Bloc', 'Session Summary:');
      Logger.info('Bloc', '  Duration: ${finalSession.duration.inSeconds}s');
      Logger.info(
        'Bloc',
        '  Poses Captured: ${finalSession.capturedPoses.length}',
      );
      Logger.info('Bloc', '  ${finalSession.metrics}');

      emit(
        SessionSummary(
          cameraController: _cameraService.controller!,
          session: finalSession,
        ),
      );
    }
  }

  Future<void> _onProcessFrame(
    ProcessFrameEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isProcessingFrame || _currentSession == null) return;
    _isProcessingFrame = true;

    final startTime = DateTime.now();

    try {
      // Detect pose using domain model conversion with camera timestamp
      final timestampedPose = await _poseDetectionService.detectPose(
        image: event.image,
        sensorOrientation: event.sensorOrientation,
        frameIndex: _frameIndex++,
        cameraTimestampMicros: event.timestampMicros,
        previousTimestampMicros: _previousTimestampMicros,
      );

      // Update previous timestamp for next frame's delta calculation
      if (timestampedPose != null) {
        _previousTimestampMicros = timestampedPose.timestampMicros;
      }

      // Calculate processing latency (ML Kit inference time)
      final processingLatencyMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      // Calculate end-to-end latency (frame capture to now)
      // This represents the "visual lag" users perceive
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      final endToEndLatencyMs = (nowMicros - event.timestampMicros) / 1000.0;

      // Update metrics
      final updatedMetrics = _currentSession!.metrics
          .withReceivedFrame()
          .withProcessedFrame(
            poseDetected: timestampedPose != null,
            latencyMs: processingLatencyMs,
            endToEndLatencyMs: endToEndLatencyMs,
          );

      // Implement ring buffer for pose retention (keep last N poses)
      final currentPoses = _currentSession!.capturedPoses;
      List<TimestampedPose> updatedPoses;

      if (timestampedPose != null) {
        if (currentPoses.length >= _maxPosesInMemory) {
          // Ring buffer: remove oldest pose
          updatedPoses = List<TimestampedPose>.from(currentPoses.sublist(1))
            ..add(timestampedPose);
        } else {
          updatedPoses = List<TimestampedPose>.from(currentPoses)
            ..add(timestampedPose);
        }
      } else {
        updatedPoses = currentPoses;
      }

      _currentSession = _currentSession!.copyWith(
        capturedPoses: updatedPoses,
        metrics: updatedMetrics,
      );

      // Reset consecutive error counter on success
      _consecutiveErrors = 0;

      // Emit updated state
      if (state is Detecting) {
        emit(
          (state as Detecting).copyWith(
            currentPose: timestampedPose,
            imageSize: Size(
              event.image.width.toDouble(),
              event.image.height.toDouble(),
            ),
            session: _currentSession!,
          ),
        );
      }
    } catch (e) {
      _consecutiveErrors++;
      Logger.error(
        'Bloc',
        'ERROR processing frame ($_consecutiveErrors consecutiveErrors/$_maxConsecutiveErrors): $e',
      );

      // Check if we've exceeded the error threshold
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        Logger.error(
          'Bloc',
          'CRITICAL: Too many consecutive errors, stopping capture',
        );
        _cameraService.stopImageStream();
        _isStreamingActive = false;
        emit(
          PoseDetectionError(
            'Pose detection failed after $_maxConsecutiveErrors consecutive errors. Last error: $e',
          ),
        );
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Update metrics when a frame is dropped due to back-pressure
  void _updateMetricsForDroppedFrame() {
    if (_currentSession == null) return;

    final updatedMetrics = _currentSession!.metrics.withDroppedFrame();

    _currentSession = _currentSession!.copyWith(
      metrics: updatedMetrics,
    );
  }

  Future<void> _onDispose(
    DisposeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _cameraService.dispose();
    _poseDetectionService.dispose();
  }
}
