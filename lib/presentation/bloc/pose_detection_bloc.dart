import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/object_detection_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/domain/models/detected_object.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/domain/models/session_metrics.dart';
import 'package:pose_detection/domain/models/validation_result.dart';
import 'package:pose_detection/domain/validators/human_signal_validator.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';

/// BLoC for pose detection with cascaded human validation
///
/// Architecture follows Clean Architecture principles:
/// - Core Layer: CameraService, ObjectDetectionService, PoseDetectionService
///   (agnostic data providers - no knowledge of "humans")
/// - Domain Layer: HumanSignalValidator (biometric control center)
///   (all interpretation and validation logic)
/// - Presentation Layer: This BLoC (orchestration and state management)
///
/// Flow: Object Detection -> Human Detection (Domain) -> Pose Detection -> Validation
class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  // === Core Layer Services (Agnostic) ===
  final CameraService _cameraService;
  final ObjectDetectionService _objectDetectionService;
  final PoseDetectionService _poseDetectionService;

  // === Domain Layer Validator (Biometric Control Center) ===
  final HumanSignalValidator _humanValidator;

  /// Whether validation is enabled (can be toggled for debugging)
  bool _validationEnabled = true;

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
    ObjectDetectionService? objectDetectionService,
    HumanSignalValidator? humanValidator,
  }) : _cameraService = cameraService,
       _poseDetectionService = poseDetectionService,
       _objectDetectionService =
           objectDetectionService ?? ObjectDetectionService(),
       _humanValidator = humanValidator ?? HumanSignalValidator(),
       super(PoseDetectionInitial()) {
    on<InitializeEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    // Use droppable transformer for high-frequency frame events
    // This automatically drops events that arrive while processing
    on<ProcessFrameEvent>(_onProcessFrame, transformer: droppable());
    on<DisposeEvent>(_onDispose);
  }

  /// Enable or disable validation (useful for debugging)
  void setValidationEnabled(bool enabled) {
    _validationEnabled = enabled;
    _log('Bloc', 'Validation ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> _onInitialize(
    InitializeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    try {
      emit(CameraInitializing());
      _log('Bloc', 'Initializing camera...');

      await _cameraService.initialize();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Camera controller not properly initialized');
      }

      _log('Bloc', 'Camera initialized successfully');
      _log('Bloc', 'Resolution: ${controller.value.previewSize}');

      emit(CameraReady(controller, lastSession: _lastSession));
    } catch (e) {
      _log('Bloc', 'ERROR initializing: $e');
      emit(PoseDetectionError('Failed to initialize camera: $e'));
    }
  }

  Future<void> _onStartCapture(
    StartCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isStreamingActive) {
      _log(
        'Bloc',
        'WARNING: Stream already active, stopping existing stream first',
      );
      _cameraService.stopImageStream();
      _isStreamingActive = false;
    }

    _log('Bloc', 'Starting pose capture session...');

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
      // ============================================================
      // STAGE 1: Core Layer - Object Detection (Agnostic)
      // ============================================================
      // Core service returns ALL detected objects without interpretation
      ObjectDetectionResult? objectDetectionResult;
      HumanDetectionResult? humanDetection;
      bool humanPresent = true;

      if (_validationEnabled) {
        objectDetectionResult = await _objectDetectionService.detectObjects(
          image: event.image,
          sensorOrientation: event.sensorOrientation,
        );

        // ============================================================
        // STAGE 2: Domain Layer - Human Interpretation
        // ============================================================
        // Domain layer interprets agnostic data to find humans
        humanDetection = _humanValidator.interpretObjectDetection(
          objectDetectionResult,
        );

        humanPresent = _humanValidator.isHumanPresent(humanDetection);

        if (!humanPresent) {
          // No human detected - skip pose detection entirely
          _handleNoHumanFrame(event, emit, humanDetection);
          return;
        }
      }

      // ============================================================
      // STAGE 3: Core Layer - Pose Detection (Agnostic)
      // ============================================================
      // Only run pose detection if human was detected (cascaded principle)
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

      // ============================================================
      // STAGE 4: Domain Layer - Pose Validation (Biometric Control)
      // ============================================================
      // Domain layer validates pose is a real human signal
      PoseValidationResult? validationResult;
      TimestampedPose? validatedPose;

      if (timestampedPose != null &&
          _validationEnabled &&
          humanDetection != null) {
        // Validate the detected pose using domain validator
        validationResult = _humanValidator.validatePose(
          pose: timestampedPose,
          humanDetection: humanDetection,
        );

        if (validationResult.isValid) {
          // Pose passed all validation gates - this is a confirmed human
          validatedPose = timestampedPose;
          _log('Validation', 'VALID pose - human confirmed');
        } else {
          // Ghost pose detected - filter it out
          _log(
            'Validation',
            'REJECTED pose: ${validationResult.rejectionReasons.map((r) => r.name).join(", ")}',
          );
        }
      } else if (timestampedPose != null && !_validationEnabled) {
        // Validation disabled - pass through all poses
        validatedPose = timestampedPose;
      }

      // Calculate processing latency (total pipeline time)
      final processingLatencyMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      // Calculate end-to-end latency (frame capture to now)
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      final endToEndLatencyMs = (nowMicros - event.timestampMicros) / 1000.0;

      // Update metrics with validation info
      final updatedMetrics = _currentSession!.metrics
          .withReceivedFrame()
          .withProcessedFrame(
            poseDetected: timestampedPose != null,
            latencyMs: processingLatencyMs,
            endToEndLatencyMs: endToEndLatencyMs,
            poseValidated: validatedPose != null,
            humanDetected: humanPresent,
          );

      // Implement ring buffer for pose retention (only store VALIDATED poses)
      final currentPoses = _currentSession!.capturedPoses;
      List<TimestampedPose> updatedPoses;

      if (validatedPose != null) {
        if (currentPoses.length >= _maxPosesInMemory) {
          // Ring buffer: remove oldest pose
          updatedPoses = List<TimestampedPose>.from(currentPoses.sublist(1))
            ..add(validatedPose);
        } else {
          updatedPoses = List<TimestampedPose>.from(currentPoses)
            ..add(validatedPose);
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
            currentPose: validatedPose,
            lastValidation: validationResult,
            imageSize: Size(
              event.image.width.toDouble(),
              event.image.height.toDouble(),
            ),
            session: _currentSession!,
            validationEnabled: _validationEnabled,
            // Clear pose if rejected to avoid stale display
            clearCurrentPose: timestampedPose != null && validatedPose == null,
          ),
        );
      }
    } catch (e) {
      _consecutiveErrors++;
      _log(
        'Bloc',
        'ERROR processing frame ($_consecutiveErrors consecutiveErrors/$_maxConsecutiveErrors): $e',
      );

      // Check if we've exceeded the error threshold
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _log('Bloc', 'CRITICAL: Too many consecutive errors, stopping capture');
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

  /// Handle frames where no human was detected
  void _handleNoHumanFrame(
    ProcessFrameEvent event,
    Emitter<PoseDetectionState> emit,
    HumanDetectionResult humanDetection,
  ) {
    final processingLatencyMs = humanDetection.detectionLatencyMs;
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final endToEndLatencyMs = (nowMicros - event.timestampMicros) / 1000.0;

    // Update metrics - frame processed but no pose detected
    final updatedMetrics = _currentSession!.metrics
        .withReceivedFrame()
        .withProcessedFrame(
          poseDetected: false,
          latencyMs: processingLatencyMs,
          endToEndLatencyMs: endToEndLatencyMs,
          poseValidated: null,
          humanDetected: false,
        );

    _currentSession = _currentSession!.copyWith(
      metrics: updatedMetrics,
    );

    // Emit state with no pose but keep session updated
    // IMPORTANT: Clear the current pose so no landmarks are painted
    if (state is Detecting) {
      emit(
        (state as Detecting).copyWith(
          session: _currentSession!,
          clearCurrentPose: true,
          validationEnabled: _validationEnabled,
        ),
      );
    }

    _isProcessingFrame = false;
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
    _objectDetectionService.dispose();
    _poseDetectionService.dispose();
  }

  void _log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    developer.log('[$timestamp] [$tag] $message');
  }
}
