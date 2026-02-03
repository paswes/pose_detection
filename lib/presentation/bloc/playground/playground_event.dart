import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/motion/services/motion_analyzer.dart';

/// Events for PlaygroundBloc
abstract class PlaygroundEvent extends Equatable {
  const PlaygroundEvent();

  @override
  List<Object?> get props => [];
}

// ============================================
// Lifecycle Events
// ============================================

/// Initialize camera and services
class InitializePlaygroundEvent extends PlaygroundEvent {
  const InitializePlaygroundEvent();
}

/// Start pose detection capture
class StartCaptureEvent extends PlaygroundEvent {
  const StartCaptureEvent();
}

/// Stop pose detection capture
class StopCaptureEvent extends PlaygroundEvent {
  const StopCaptureEvent();
}

/// Process a camera frame
class ProcessFrameEvent extends PlaygroundEvent {
  final CameraImage image;
  final int sensorOrientation;
  final int timestampMicros;

  const ProcessFrameEvent(
    this.image,
    this.sensorOrientation,
    this.timestampMicros,
  );

  @override
  List<Object?> get props => [image, sensorOrientation, timestampMicros];
}

/// Switch between front and back camera
class SwitchCameraEvent extends PlaygroundEvent {
  const SwitchCameraEvent();
}

/// Dispose resources
class DisposePlaygroundEvent extends PlaygroundEvent {
  const DisposePlaygroundEvent();
}

// ============================================
// Configuration Events
// ============================================

/// Configuration preset types
enum ConfigPreset {
  // PoseDetectionConfig presets
  defaultConfig,
  smoothVisuals,
  responsive,
  raw,
  highPrecision,

  // MotionAnalyzerConfig presets
  motionDefault,
  motionMinimal,
  motionFull,
  motionRomFocused,
  motionVelocityFocused,
}

/// Apply a named preset configuration
class ApplyPresetEvent extends PlaygroundEvent {
  final ConfigPreset preset;

  const ApplyPresetEvent(this.preset);

  @override
  List<Object?> get props => [preset];
}

/// Update pose detection configuration
class UpdatePoseConfigEvent extends PlaygroundEvent {
  final PoseDetectionConfig config;

  const UpdatePoseConfigEvent(this.config);

  @override
  List<Object?> get props => [config];
}

/// Update motion analyzer configuration
class UpdateMotionConfigEvent extends PlaygroundEvent {
  final MotionAnalyzerConfig config;

  const UpdateMotionConfigEvent(this.config);

  @override
  List<Object?> get props => [config];
}

// ============================================
// UI State Events
// ============================================

/// Panel types that can be toggled
enum PanelType {
  config,
  data,
  smoothingSection,
  confidenceSection,
  motionSection,
}

/// Toggle panel visibility
class TogglePanelEvent extends PlaygroundEvent {
  final PanelType panel;

  const TogglePanelEvent(this.panel);

  @override
  List<Object?> get props => [panel];
}

/// Select which joints to display
class SelectJointsEvent extends PlaygroundEvent {
  final Set<BodyJoint> joints;

  const SelectJointsEvent(this.joints);

  @override
  List<Object?> get props => [joints];
}

/// Toggle showing all velocities vs key landmarks only
class ToggleAllVelocitiesEvent extends PlaygroundEvent {
  const ToggleAllVelocitiesEvent();
}

// ============================================
// Analysis Events
// ============================================

/// Reset motion analysis (ROM, velocities, history)
class ResetMotionAnalysisEvent extends PlaygroundEvent {
  const ResetMotionAnalysisEvent();
}
