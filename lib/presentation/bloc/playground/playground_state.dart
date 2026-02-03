import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/errors/pose_detection_errors.dart';
import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/detection_metrics.dart';
import 'package:pose_detection/domain/motion/services/motion_analyzer.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';

/// Extended metrics for the playground UI
class PlaygroundMetrics extends Equatable {
  /// Standard detection metrics (FPS, latency)
  final DetectionMetrics detection;

  /// Total poses detected in this session
  final int poseCount;

  /// Frames dropped due to processing backlog
  final int droppedFrames;

  /// Whether the body is currently stationary
  final bool isStationary;

  /// Session start timestamp
  final DateTime? sessionStartTime;

  const PlaygroundMetrics({
    this.detection = const DetectionMetrics(),
    this.poseCount = 0,
    this.droppedFrames = 0,
    this.isStationary = true,
    this.sessionStartTime,
  });

  /// Session duration in seconds
  double get sessionDurationSeconds {
    if (sessionStartTime == null) return 0;
    return DateTime.now().difference(sessionStartTime!).inMilliseconds / 1000;
  }

  PlaygroundMetrics copyWith({
    DetectionMetrics? detection,
    int? poseCount,
    int? droppedFrames,
    bool? isStationary,
    DateTime? sessionStartTime,
  }) {
    return PlaygroundMetrics(
      detection: detection ?? this.detection,
      poseCount: poseCount ?? this.poseCount,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      isStationary: isStationary ?? this.isStationary,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }

  @override
  List<Object?> get props => [
        detection,
        poseCount,
        droppedFrames,
        isStationary,
        sessionStartTime,
      ];
}

/// State for PlaygroundBloc
class PlaygroundState extends Equatable {
  // ============================================
  // Detection State
  // ============================================

  /// Camera controller (null if not initialized)
  final CameraController? cameraController;

  /// Current detected pose
  final DetectedPose? currentPose;

  /// Extended metrics for playground
  final PlaygroundMetrics metrics;

  /// Whether multiple cameras are available
  final bool canSwitchCamera;

  /// Whether front camera is active
  final bool isFrontCamera;

  /// Whether detection is actively running
  final bool isDetecting;

  /// Whether the system is initializing
  final bool isInitializing;

  // ============================================
  // Motion Analysis Data
  // ============================================

  /// Current motion analysis result
  final MotionAnalysisResult? motionData;

  // ============================================
  // Configuration
  // ============================================

  /// Current pose detection config
  final PoseDetectionConfig poseConfig;

  /// Current motion analyzer config
  final MotionAnalyzerConfig motionConfig;

  /// Currently active preset (if any)
  final ConfigPreset? activePreset;

  // ============================================
  // UI State
  // ============================================

  /// Config panel expanded state
  final bool configPanelExpanded;

  /// Data panel expanded state
  final bool dataPanelExpanded;

  /// Smoothing section expanded within config panel
  final bool smoothingSectionExpanded;

  /// Confidence section expanded within config panel
  final bool confidenceSectionExpanded;

  /// Motion section expanded within config panel
  final bool motionSectionExpanded;

  /// Selected joints for display (empty = show all primary)
  final Set<BodyJoint> selectedJoints;

  /// Show all landmark velocities vs just key ones
  final bool showAllVelocities;

  // ============================================
  // Error State
  // ============================================

  /// Error message (null if no error)
  final String? errorMessage;

  /// Structured error code
  final PoseDetectionErrorCode? errorCode;

  const PlaygroundState({
    // Detection
    this.cameraController,
    this.currentPose,
    this.metrics = const PlaygroundMetrics(),
    this.canSwitchCamera = false,
    this.isFrontCamera = false,
    this.isDetecting = false,
    this.isInitializing = false,
    // Motion
    this.motionData,
    // Config
    this.poseConfig = const PoseDetectionConfig(),
    this.motionConfig = const MotionAnalyzerConfig(),
    this.activePreset = ConfigPreset.defaultConfig,
    // UI
    this.configPanelExpanded = false,
    this.dataPanelExpanded = false,
    this.smoothingSectionExpanded = true,
    this.confidenceSectionExpanded = false,
    this.motionSectionExpanded = false,
    this.selectedJoints = const {},
    this.showAllVelocities = false,
    // Error
    this.errorMessage,
    this.errorCode,
  });

  /// Whether the state has an error
  bool get hasError => errorMessage != null;

  /// Whether the error is recoverable
  bool get isRecoverable {
    if (errorCode == null) return true;
    switch (errorCode!) {
      case PoseDetectionErrorCode.mlKitDetectionFailed:
      case PoseDetectionErrorCode.processingTimeout:
      case PoseDetectionErrorCode.unknown:
        return true;
      case PoseDetectionErrorCode.cameraInitFailed:
      case PoseDetectionErrorCode.cameraNotInitialized:
      case PoseDetectionErrorCode.streamStartFailed:
      case PoseDetectionErrorCode.cameraSwitchFailed:
      case PoseDetectionErrorCode.imageConversionFailed:
      case PoseDetectionErrorCode.tooManyConsecutiveErrors:
        return false;
    }
  }

  /// Whether camera is ready (initialized but not detecting)
  bool get isCameraReady =>
      cameraController != null && !isDetecting && !isInitializing && !hasError;

  /// Joints to display (selected or primary joints if none selected)
  Set<BodyJoint> get displayJoints =>
      selectedJoints.isEmpty ? BodyJoint.primaryJoints.toSet() : selectedJoints;

  PlaygroundState copyWith({
    CameraController? cameraController,
    DetectedPose? currentPose,
    bool clearPose = false,
    PlaygroundMetrics? metrics,
    bool? canSwitchCamera,
    bool? isFrontCamera,
    bool? isDetecting,
    bool? isInitializing,
    MotionAnalysisResult? motionData,
    bool clearMotionData = false,
    PoseDetectionConfig? poseConfig,
    MotionAnalyzerConfig? motionConfig,
    ConfigPreset? activePreset,
    bool clearActivePreset = false,
    bool? configPanelExpanded,
    bool? dataPanelExpanded,
    bool? smoothingSectionExpanded,
    bool? confidenceSectionExpanded,
    bool? motionSectionExpanded,
    Set<BodyJoint>? selectedJoints,
    bool? showAllVelocities,
    String? errorMessage,
    bool clearError = false,
    PoseDetectionErrorCode? errorCode,
  }) {
    return PlaygroundState(
      cameraController: cameraController ?? this.cameraController,
      currentPose: clearPose ? null : (currentPose ?? this.currentPose),
      metrics: metrics ?? this.metrics,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isDetecting: isDetecting ?? this.isDetecting,
      isInitializing: isInitializing ?? this.isInitializing,
      motionData: clearMotionData ? null : (motionData ?? this.motionData),
      poseConfig: poseConfig ?? this.poseConfig,
      motionConfig: motionConfig ?? this.motionConfig,
      activePreset:
          clearActivePreset ? null : (activePreset ?? this.activePreset),
      configPanelExpanded: configPanelExpanded ?? this.configPanelExpanded,
      dataPanelExpanded: dataPanelExpanded ?? this.dataPanelExpanded,
      smoothingSectionExpanded:
          smoothingSectionExpanded ?? this.smoothingSectionExpanded,
      confidenceSectionExpanded:
          confidenceSectionExpanded ?? this.confidenceSectionExpanded,
      motionSectionExpanded:
          motionSectionExpanded ?? this.motionSectionExpanded,
      selectedJoints: selectedJoints ?? this.selectedJoints,
      showAllVelocities: showAllVelocities ?? this.showAllVelocities,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [
        cameraController,
        currentPose,
        metrics,
        canSwitchCamera,
        isFrontCamera,
        isDetecting,
        isInitializing,
        motionData,
        poseConfig,
        motionConfig,
        activePreset,
        configPanelExpanded,
        dataPanelExpanded,
        smoothingSectionExpanded,
        confidenceSectionExpanded,
        motionSectionExpanded,
        selectedJoints,
        showAllVelocities,
        errorMessage,
        errorCode,
      ];
}
