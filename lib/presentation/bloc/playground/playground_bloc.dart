import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/data_structures/ring_buffer.dart';
import 'package:pose_detection/core/errors/pose_detection_errors.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/error_tracker.dart';
import 'package:pose_detection/core/services/frame_processor.dart';
import 'package:pose_detection/core/services/pose_smoother.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';
import 'package:pose_detection/domain/motion/services/motion_analyzer.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';

/// BLoC for the Developer Playground UI.
///
/// Extends pose detection with:
/// - Motion analysis integration
/// - Dynamic configuration changes
/// - Extended metrics tracking
/// - Panel state management
class PlaygroundBloc extends Bloc<PlaygroundEvent, PlaygroundState> {
  final ICameraService _cameraService;
  final FrameProcessor _frameProcessor;
  ErrorTracker _errorTracker;
  PoseSmoother _poseSmoother;
  MotionAnalyzer _motionAnalyzer;

  bool _isProcessingFrame = false;
  bool _isStreamingActive = false;

  // FPS calculation using RingBuffer
  late RingBuffer<int> _frameTimestamps;

  // Metrics tracking
  double _lastLatencyMs = 0.0;
  int _poseCount = 0;
  int _droppedFrames = 0;

  PlaygroundBloc({
    required ICameraService cameraService,
    required IPoseDetector poseDetector,
    required PoseDetectionConfig initialPoseConfig,
    required MotionAnalyzerConfig initialMotionConfig,
  })  : _cameraService = cameraService,
        _frameProcessor = FrameProcessor(poseDetector: poseDetector),
        _errorTracker = ErrorTracker(config: initialPoseConfig),
        _poseSmoother = PoseSmoother(config: initialPoseConfig),
        _motionAnalyzer = MotionAnalyzer(config: initialMotionConfig),
        _frameTimestamps = RingBuffer(initialPoseConfig.fpsBufferSize),
        super(PlaygroundState(
          poseConfig: initialPoseConfig,
          motionConfig: initialMotionConfig,
        )) {
    // Lifecycle events
    on<InitializePlaygroundEvent>(_onInitialize);
    on<StartCaptureEvent>(_onStartCapture);
    on<StopCaptureEvent>(_onStopCapture);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<ProcessFrameEvent>(_onProcessFrame, transformer: droppable());
    on<DisposePlaygroundEvent>(_onDispose);

    // Configuration events
    on<ApplyPresetEvent>(_onApplyPreset);
    on<UpdatePoseConfigEvent>(_onUpdatePoseConfig);
    on<UpdateMotionConfigEvent>(_onUpdateMotionConfig);

    // UI state events
    on<TogglePanelEvent>(_onTogglePanel);
    on<SelectJointsEvent>(_onSelectJoints);
    on<ToggleAllVelocitiesEvent>(_onToggleAllVelocities);

    // Analysis events
    on<ResetMotionAnalysisEvent>(_onResetMotionAnalysis);
  }

  // ============================================
  // Metrics Calculation
  // ============================================

  double _calculateFps() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = state.poseConfig.fpsWindowMs;

    int count = 0;
    for (final timestamp in _frameTimestamps.items) {
      if (now - timestamp <= windowMs) {
        count++;
      }
    }
    return count.toDouble();
  }

  void _recordFrame() {
    _frameTimestamps.add(DateTime.now().millisecondsSinceEpoch);
    _poseCount++;
  }

  void _recordDroppedFrame() {
    _droppedFrames++;
  }

  void _resetMetrics() {
    _frameTimestamps.clear();
    _lastLatencyMs = 0.0;
    _poseCount = 0;
    _droppedFrames = 0;
    _poseSmoother.reset();
  }

  PlaygroundMetrics _buildMetrics({bool isStationary = true}) {
    return PlaygroundMetrics(
      detection: DetectionMetrics(
        fps: _calculateFps(),
        latencyMs: _lastLatencyMs,
      ),
      poseCount: _poseCount,
      droppedFrames: _droppedFrames,
      isStationary: isStationary,
      sessionStartTime: state.metrics.sessionStartTime,
    );
  }

  // ============================================
  // Lifecycle Event Handlers
  // ============================================

  Future<void> _onInitialize(
    InitializePlaygroundEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    try {
      emit(state.copyWith(isInitializing: true, clearError: true));

      await _cameraService.initialize();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw PoseDetectionException.cameraNotInitialized();
      }

      Logger.info('PlaygroundBloc', 'Camera initialized');
      emit(state.copyWith(
        cameraController: controller,
        isInitializing: false,
        canSwitchCamera: _cameraService.canSwitchCamera,
        isFrontCamera:
            _cameraService.currentLensDirection == CameraLensDirection.front,
      ));
    } catch (e) {
      Logger.error('PlaygroundBloc', 'Initialization error: $e');
      _emitError(emit, e);
    }
  }

  Future<void> _onStartCapture(
    StartCaptureEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    if (_isStreamingActive) {
      _cameraService.stopImageStream();
      _isStreamingActive = false;
    }

    _errorTracker.reset();
    _resetMetrics();
    _motionAnalyzer.startSession();

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      emit(state.copyWith(
        errorMessage: 'Camera not initialized',
        errorCode: PoseDetectionErrorCode.cameraNotInitialized,
      ));
      return;
    }

    emit(state.copyWith(
      isDetecting: true,
      clearPose: true,
      clearMotionData: true,
      metrics: PlaygroundMetrics(sessionStartTime: DateTime.now()),
    ));

    final cameraDescription = _cameraService.getCameraDescription();
    if (cameraDescription != null) {
      _isStreamingActive = true;
      _cameraService.startImageStream((image) {
        if (_isStreamingActive) {
          final timestampMicros = DateTime.now().microsecondsSinceEpoch;

          if (!_isProcessingFrame) {
            add(ProcessFrameEvent(image, cameraDescription.sensorOrientation,
                timestampMicros));
          } else {
            _recordDroppedFrame();
          }
        }
      });
    }

    Logger.info('PlaygroundBloc', 'Detection started');
  }

  Future<void> _onStopCapture(
    StopCaptureEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    _cameraService.stopImageStream();
    _isStreamingActive = false;
    _motionAnalyzer.endSession();

    emit(state.copyWith(isDetecting: false));

    Logger.info('PlaygroundBloc', 'Detection stopped');
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    if (!_cameraService.canSwitchCamera) return;

    final wasDetecting = state.isDetecting;

    try {
      emit(state.copyWith(isInitializing: true));

      _poseSmoother.reset();
      await _cameraService.switchCamera();

      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw PoseDetectionException.cameraSwitchFailed(
          'Camera not properly initialized after switch',
        );
      }

      emit(state.copyWith(
        cameraController: controller,
        isInitializing: false,
        isFrontCamera:
            _cameraService.currentLensDirection == CameraLensDirection.front,
      ));

      if (wasDetecting) {
        final cameraDescription = _cameraService.getCameraDescription();
        if (cameraDescription != null && !_isStreamingActive) {
          _isStreamingActive = true;
          _cameraService.startImageStream((image) {
            if (_isStreamingActive) {
              final timestampMicros = DateTime.now().microsecondsSinceEpoch;
              if (!_isProcessingFrame) {
                add(ProcessFrameEvent(image, cameraDescription.sensorOrientation,
                    timestampMicros));
              } else {
                _recordDroppedFrame();
              }
            }
          });
        }
      }

      Logger.info('PlaygroundBloc',
          'Camera switched to ${_cameraService.currentLensDirection}');
    } catch (e) {
      Logger.error('PlaygroundBloc', 'Camera switch error: $e');
      _emitError(emit, e);
    }
  }

  Future<void> _onProcessFrame(
    ProcessFrameEvent event,
    Emitter<PlaygroundState> emit,
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

        // Apply smoothing
        final smoothedPose =
            result.pose != null ? _poseSmoother.smooth(result.pose!) : null;

        // Run motion analysis
        final motionResult =
            smoothedPose != null ? _motionAnalyzer.analyze(smoothedPose) : null;

        final isStationary = motionResult?.isStationary ?? true;

        if (state.isDetecting) {
          emit(state.copyWith(
            currentPose: smoothedPose,
            motionData: motionResult,
            metrics: _buildMetrics(isStationary: isStationary),
            canSwitchCamera: _cameraService.canSwitchCamera,
            isFrontCamera:
                _cameraService.currentLensDirection == CameraLensDirection.front,
          ));
        }
      } else {
        _handleFrameError(emit,
            PoseDetectionException.mlKitDetectionFailed(result.error));
      }
    } catch (e) {
      _handleFrameError(
        emit,
        e is PoseDetectionException ? e : PoseDetectionException.unknown(e),
      );
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleFrameError(
      Emitter<PlaygroundState> emit, PoseDetectionException exception) {
    _errorTracker.recordError();
    Logger.error(
      'PlaygroundBloc',
      'Frame error [${exception.code}]: ${exception.message} '
      '(${_errorTracker.consecutiveErrors}/${_errorTracker.maxConsecutiveErrors})',
    );

    if (_errorTracker.hasExceededThreshold) {
      _cameraService.stopImageStream();
      _isStreamingActive = false;
      emit(state.copyWith(
        isDetecting: false,
        errorMessage: 'Too many consecutive errors. Last: ${exception.message}',
        errorCode: PoseDetectionErrorCode.tooManyConsecutiveErrors,
      ));
    }
  }

  Future<void> _onDispose(
    DisposePlaygroundEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    _cameraService.dispose();
    _frameProcessor.dispose();
    _poseSmoother.dispose();
    _motionAnalyzer.dispose();
  }

  // ============================================
  // Configuration Event Handlers
  // ============================================

  Future<void> _onApplyPreset(
    ApplyPresetEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    switch (event.preset) {
      // Pose detection presets
      case ConfigPreset.defaultConfig:
        _updatePoseConfig(PoseDetectionConfig.defaultConfig(), emit);
        break;
      case ConfigPreset.smoothVisuals:
        _updatePoseConfig(PoseDetectionConfig.smoothVisuals(), emit);
        break;
      case ConfigPreset.responsive:
        _updatePoseConfig(PoseDetectionConfig.responsive(), emit);
        break;
      case ConfigPreset.raw:
        _updatePoseConfig(PoseDetectionConfig.raw(), emit);
        break;
      case ConfigPreset.highPrecision:
        _updatePoseConfig(PoseDetectionConfig.highPrecision(), emit);
        break;

      // Motion analyzer presets
      case ConfigPreset.motionDefault:
        _updateMotionConfig(MotionAnalyzerConfig.defaultConfig(), emit);
        break;
      case ConfigPreset.motionMinimal:
        _updateMotionConfig(MotionAnalyzerConfig.minimal(), emit);
        break;
      case ConfigPreset.motionFull:
        _updateMotionConfig(MotionAnalyzerConfig.fullAnalysis(), emit);
        break;
      case ConfigPreset.motionRomFocused:
        _updateMotionConfig(MotionAnalyzerConfig.romFocused(), emit);
        break;
      case ConfigPreset.motionVelocityFocused:
        _updateMotionConfig(MotionAnalyzerConfig.velocityFocused(), emit);
        break;
    }

    emit(state.copyWith(activePreset: event.preset));
  }

  Future<void> _onUpdatePoseConfig(
    UpdatePoseConfigEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    _updatePoseConfig(event.config, emit);
    emit(state.copyWith(clearActivePreset: true));
  }

  Future<void> _onUpdateMotionConfig(
    UpdateMotionConfigEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    _updateMotionConfig(event.config, emit);
    emit(state.copyWith(clearActivePreset: true));
  }

  void _updatePoseConfig(
      PoseDetectionConfig config, Emitter<PlaygroundState> emit) {
    // Recreate services with new config
    _poseSmoother.dispose();
    _poseSmoother = PoseSmoother(config: config);

    _errorTracker = ErrorTracker(config: config);
    _frameTimestamps = RingBuffer(config.fpsBufferSize);

    emit(state.copyWith(poseConfig: config));
    Logger.info('PlaygroundBloc', 'Pose config updated');
  }

  void _updateMotionConfig(
      MotionAnalyzerConfig config, Emitter<PlaygroundState> emit) {
    // Recreate motion analyzer with new config
    final wasActive = _motionAnalyzer.isActive;
    _motionAnalyzer.dispose();
    _motionAnalyzer = MotionAnalyzer(config: config);
    if (wasActive) {
      _motionAnalyzer.startSession();
    }

    emit(state.copyWith(motionConfig: config));
    Logger.info('PlaygroundBloc', 'Motion config updated');
  }

  // ============================================
  // UI State Event Handlers
  // ============================================

  Future<void> _onTogglePanel(
    TogglePanelEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    switch (event.panel) {
      case PanelType.config:
        emit(state.copyWith(configPanelExpanded: !state.configPanelExpanded));
        break;
      case PanelType.data:
        emit(state.copyWith(dataPanelExpanded: !state.dataPanelExpanded));
        break;
      case PanelType.smoothingSection:
        emit(state.copyWith(
            smoothingSectionExpanded: !state.smoothingSectionExpanded));
        break;
      case PanelType.confidenceSection:
        emit(state.copyWith(
            confidenceSectionExpanded: !state.confidenceSectionExpanded));
        break;
      case PanelType.motionSection:
        emit(
            state.copyWith(motionSectionExpanded: !state.motionSectionExpanded));
        break;
    }
  }

  Future<void> _onSelectJoints(
    SelectJointsEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    emit(state.copyWith(selectedJoints: event.joints));
  }

  Future<void> _onToggleAllVelocities(
    ToggleAllVelocitiesEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    emit(state.copyWith(showAllVelocities: !state.showAllVelocities));
  }

  // ============================================
  // Analysis Event Handlers
  // ============================================

  Future<void> _onResetMotionAnalysis(
    ResetMotionAnalysisEvent event,
    Emitter<PlaygroundState> emit,
  ) async {
    _motionAnalyzer.reset();
    emit(state.copyWith(clearMotionData: true));
    Logger.info('PlaygroundBloc', 'Motion analysis reset');
  }

  // ============================================
  // Error Handling
  // ============================================

  void _emitError(Emitter<PlaygroundState> emit, dynamic error) {
    if (error is PoseDetectionException) {
      emit(state.copyWith(
        isInitializing: false,
        errorMessage: error.message,
        errorCode: error.code,
      ));
    } else {
      emit(state.copyWith(
        isInitializing: false,
        errorMessage: 'An unexpected error occurred: $error',
        errorCode: PoseDetectionErrorCode.unknown,
      ));
    }
  }
}
