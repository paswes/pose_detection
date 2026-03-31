import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/recording_service.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_state.dart';

class PoseDetectionBloc extends Bloc<PoseDetectionEvent, PoseDetectionState> {
  final ICameraService _cameraService;
  final IPoseDetector _poseDetector;
  final IPersonValidator _personValidator;
  final RecordingService _recordingService;
  final SessionRepository _sessionRepository;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;
  Timer? _recordingTimer;
  RecordingResult? _pendingResult;

  int _consecutiveErrors = 0;
  static const _maxConsecutiveErrors = 10;

  PoseDetectionBloc({
    required ICameraService cameraService,
    required IPoseDetector poseDetector,
    required IPersonValidator personValidator,
    required RecordingService recordingService,
    required SessionRepository sessionRepository,
  }) : _cameraService = cameraService,
       _poseDetector = poseDetector,
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

      emit(CameraReady(controller));
    } catch (e) {
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

    _consecutiveErrors = 0;

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
  }

  Future<void> _onStopCapture(
    StopCaptureEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _cameraService.stopImageStream();
    _isStreamingActive = false;

    emit(CameraReady(_cameraService.controller!));
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    if (_isStreamingActive) {
      _cameraService.stopImageStream();
      _isStreamingActive = false;
    }

    _consecutiveErrors = 0;

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      emit(PoseDetectionError('Camera not initialized'));
      return;
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      _startImageStream();

      await _recordingService.startRecording(controller, sessionId);

      emit(
        Recording(
          cameraController: controller,
          isFrontCamera:
              _cameraService.currentLensDirection == CameraLensDirection.front,
        ),
      );

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (state is Recording) {
          add(RecordingTickEvent());
        }
      });
    } catch (e) {
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

      emit(RecordingStopped());
    } catch (e) {
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
        isFrontCamera:
            _cameraService.currentLensDirection == CameraLensDirection.front,
        isLandscape:
            _cameraService.currentOrientation != DeviceOrientation.portraitUp,
        imageWidth: result.imageSize.width,
        imageHeight: result.imageSize.height,
        sensorOrientation: sensorOrientation,
      );

      await _sessionRepository.saveSession(session, result.frames);
      _pendingResult = null;

      emit(SessionSaved(session.id));
    } catch (e) {
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
    if (state is Recording) return;

    final wasDetecting = state is Detecting;

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
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera:
                _cameraService.currentLensDirection ==
                CameraLensDirection.front,
          ),
        );
      } else {
        emit(CameraReady(controller));
      }
    } catch (e) {
      emit(PoseDetectionError('Failed to switch camera: $e'));
    }
  }

  Future<void> _onChangeOrientation(
    ChangeOrientationEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    final wasDetecting = state is Detecting;

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
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera:
                _cameraService.currentLensDirection ==
                CameraLensDirection.front,
          ),
        );
      } else {
        emit(CameraReady(controller));
      }
    } catch (e) {
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
      final pose = await _poseDetector.detectPose(
        image: event.image,
        sensorOrientation: event.sensorOrientation,
      );

      _consecutiveErrors = 0;

      if (state is! Recording) return;

      final isPersonDetected = _personValidator.validate(pose);

      _recordingService.recordFrame(
        pose,
        isPersonDetected,
        event.timestampMicros,
      );

      emit(
        (state as Recording).copyWith(
          currentPose: isPersonDetected ? pose : null,
          clearPose: !isPersonDetected,
          isPersonDetected: isPersonDetected,
          frameCount: _recordingService.frameCount,
        ),
      );
    } catch (e) {
      _consecutiveErrors++;

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _cameraService.stopImageStream();
        _isStreamingActive = false;
        emit(PoseDetectionError('Too many consecutive errors. Last: $e'));
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _onDispose(
    DisposeEvent event,
    Emitter<PoseDetectionState> emit,
  ) async {
    _recordingTimer?.cancel();
    _cameraService.dispose();
    _poseDetector.dispose();
  }
}
