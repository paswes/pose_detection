import 'package:get_it/get_it.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/core/services/pose_smoother.dart';
import 'package:pose_detection/domain/motion/services/motion_analyzer.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';

final GetIt sl = GetIt.instance;

/// Initialize all dependencies.
/// Call this in main() before runApp().
Future<void> initializeDependencies({
  PoseDetectionConfig? config,
  LandmarkSchema? schema,
  MotionAnalyzerConfig? motionConfig,
}) async {
  // ============================================
  // Configuration
  // ============================================

  sl.registerSingleton<PoseDetectionConfig>(
    config ?? PoseDetectionConfig.defaultConfig(),
  );

  sl.registerSingleton<LandmarkSchema>(
    schema ?? LandmarkSchema.mlKit33,
  );

  sl.registerSingleton<MotionAnalyzerConfig>(
    motionConfig ?? MotionAnalyzerConfig.defaultConfig(),
  );

  // ============================================
  // Core Services (lazy singletons)
  // ============================================

  sl.registerLazySingleton<ICameraService>(
    () => CameraService(),
  );

  sl.registerLazySingleton<IPoseDetector>(
    () => PoseDetectionService(),
  );

  // Pose Smoother (uses config for smoothing parameters)
  sl.registerLazySingleton<PoseSmoother>(
    () => PoseSmoother(config: sl<PoseDetectionConfig>()),
  );

  // ============================================
  // Domain Services (lazy singletons)
  // ============================================

  sl.registerLazySingleton<MotionAnalyzer>(
    () => MotionAnalyzer(config: sl<MotionAnalyzerConfig>()),
  );

  // ============================================
  // BLoC (lazy singleton)
  // ============================================

  sl.registerLazySingleton<PoseDetectionBloc>(
    () => PoseDetectionBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      config: sl<PoseDetectionConfig>(),
      poseSmoother: sl<PoseSmoother>(),
    ),
  );
}

/// Reset all dependencies.
/// Useful for testing.
Future<void> resetDependencies() async {
  await sl.reset();
}

/// Check if dependencies have been initialized
bool get dependenciesInitialized => sl.isRegistered<PoseDetectionConfig>();

/// Get the config instance
PoseDetectionConfig get config => sl<PoseDetectionConfig>();

/// Get the landmark schema instance
LandmarkSchema get landmarkSchema => sl<LandmarkSchema>();

/// Get the motion analyzer instance
MotionAnalyzer get motionAnalyzer => sl<MotionAnalyzer>();

/// Get the pose smoother instance
PoseSmoother get poseSmoother => sl<PoseSmoother>();

// ============================================
// Dynamic Config Updates (for Playground)
// ============================================

/// Update PoseDetectionConfig at runtime.
/// Recreates dependent services with new config.
void updatePoseConfig(PoseDetectionConfig newConfig) {
  // Unregister old instances
  if (sl.isRegistered<PoseDetectionConfig>()) {
    sl.unregister<PoseDetectionConfig>();
  }
  if (sl.isRegistered<PoseSmoother>()) {
    sl.unregister<PoseSmoother>();
  }

  // Register new config
  sl.registerSingleton<PoseDetectionConfig>(newConfig);

  // Recreate dependent services
  sl.registerLazySingleton<PoseSmoother>(
    () => PoseSmoother(config: sl<PoseDetectionConfig>()),
  );
}

/// Update MotionAnalyzerConfig at runtime.
/// Recreates MotionAnalyzer with new config.
void updateMotionConfig(MotionAnalyzerConfig newConfig) {
  // Unregister old instances
  if (sl.isRegistered<MotionAnalyzerConfig>()) {
    sl.unregister<MotionAnalyzerConfig>();
  }
  if (sl.isRegistered<MotionAnalyzer>()) {
    sl.unregister<MotionAnalyzer>();
  }

  // Register new config
  sl.registerSingleton<MotionAnalyzerConfig>(newConfig);

  // Recreate motion analyzer
  sl.registerLazySingleton<MotionAnalyzer>(
    () => MotionAnalyzer(config: sl<MotionAnalyzerConfig>()),
  );
}
