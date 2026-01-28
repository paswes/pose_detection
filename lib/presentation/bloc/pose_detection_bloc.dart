import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
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
  PoseSession? _currentSession;
  PoseSession? _lastSession;
  int _frameIndex = 0;

  PoseDetectionBloc({
    required CameraService cameraService,
    required PoseDetectionService poseDetectionService,
  })  : _cameraService = cameraService,
        _poseDetectionService = poseDetectionService,
        super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    on<ProcessFrameEvent>(_onProcessFrame);
    on<DisposeEvent>(_onDispose);
  }

  Future<void> _onInitialize(
    InitializeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    try {
      emit(CameraInitializing());
      _log('Bloc', 'Initializing camera...');

      await _cameraService.initialize();

      _log('Bloc', 'Camera initialized successfully');
      _log('Bloc', 'Resolution: ${_cameraService.controller!.value.previewSize}');

      emit(CameraReady(_cameraService.controller!, lastSession: _lastSession));
    } catch (e) {
      _log('Bloc', 'ERROR initializing: $e');
      emit(PoseDetectionError('Failed to initialize camera: $e'));
    }
  }

  Future<void> _onStartCapture(
    StartCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _log('Bloc', 'Starting pose capture session...');

    // Reset frame counter
    _frameIndex = 0;

    // Initialize new session with empty metrics
    _currentSession = PoseSession(
      startTime: DateTime.now(),
      capturedPoses: [],
      metrics: const SessionMetrics(),
    );

    // Emit detecting state
    emit(Detecting(
      cameraController: _cameraService.controller!,
      session: _currentSession!,
    ));

    // Start image stream
    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _cameraService.startImageStream((image) {
        // Track received frames (including dropped ones)
        if (_currentSession != null) {
          if (!_isProcessingFrame) {
            // Can process - add to event queue
            add(ProcessFrameEvent(image, cameraDescription.sensorOrientation));
          } else {
            // Back-pressure: frame will be dropped
            _updateMetricsForDroppedFrame();
          }
        }
      });
    }

    _log('Bloc', 'Capture session started');
  }

  Future<void> _onStopCapture(
    StopCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _log('Bloc', 'Stopping capture session...');

    _cameraService.stopImageStream();

    if (_currentSession != null) {
      // Finalize session
      final finalSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
      );

      _lastSession = finalSession;
      _currentSession = null;

      _log('Bloc', 'Session Summary:');
      _log('Bloc', '  Duration: ${finalSession.duration.inSeconds}s');
      _log('Bloc', '  Poses Captured: ${finalSession.capturedPoses.length}');
      _log('Bloc', '  ${finalSession.metrics}');

      emit(SessionSummary(
        cameraController: _cameraService.controller!,
        session: finalSession,
      ));
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
      // Detect pose using domain model conversion
      final timestampedPose = await _poseDetectionService.detectPose(
        image: event.image,
        sensorOrientation: event.sensorOrientation,
        frameIndex: _frameIndex++,
      );

      // Calculate processing latency
      final latencyMs = DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      // Update metrics
      final updatedMetrics = _currentSession!.metrics
          .withReceivedFrame()
          .withProcessedFrame(
            poseDetected: timestampedPose != null,
            latencyMs: latencyMs,
          );

      // Update session
      final updatedPoses = List<TimestampedPose>.from(_currentSession!.capturedPoses);
      if (timestampedPose != null) {
        updatedPoses.add(timestampedPose);
      }

      _currentSession = _currentSession!.copyWith(
        capturedPoses: updatedPoses,
        metrics: updatedMetrics,
      );

      // Emit updated state
      if (state is Detecting) {
        emit((state as Detecting).copyWith(
          currentPose: timestampedPose,
          imageSize: Size(
            event.image.width.toDouble(),
            event.image.height.toDouble(),
          ),
          session: _currentSession!,
        ));
      }
    } catch (e) {
      _log('Bloc', 'ERROR processing frame: $e');
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

  void _log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    developer.log('[$timestamp] [$tag] $message');
    debugPrint('[$timestamp] [$tag] $message');
  }
}

