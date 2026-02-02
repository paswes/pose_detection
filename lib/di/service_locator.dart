import 'package:get_it/get_it.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/config/inspection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/interfaces/angle_calculator_interface.dart';
import 'package:pose_detection/core/interfaces/velocity_tracker_interface.dart';
import 'package:pose_detection/core/interfaces/motion_analyzer_interface.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/core/services/angle_calculator.dart';
import 'package:pose_detection/core/services/velocity_tracker.dart';
import 'package:pose_detection/core/services/motion_analyzer.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/inspection/inspection_bloc.dart';

final GetIt sl = GetIt.instance;

/// Initialize all dependencies.
/// Call this in main() before runApp().
Future<void> initializeDependencies({
  PoseDetectionConfig? config,
  LandmarkSchema? schema,
}) async {
  // Configuration
  sl.registerSingleton<PoseDetectionConfig>(
    config ?? PoseDetectionConfig.mlKit33,
  );

  sl.registerSingleton<LandmarkSchema>(
    schema ?? LandmarkSchema.mlKit33,
  );

  // Core Services (lazy singletons - created on first access)
  sl.registerLazySingleton<ICameraService>(
    () => CameraService(),
  );

  sl.registerLazySingleton<IPoseDetector>(
    () => PoseDetectionService(),
  );

  // BLoC (factory - new instance each time, but we use singleton for now)
  sl.registerLazySingleton<PoseDetectionBloc>(
    () => PoseDetectionBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      config: sl<PoseDetectionConfig>(),
    ),
  );

  // === Inspection Tool ===

  // Inspection Config
  sl.registerSingleton<InspectionConfig>(
    InspectionConfig.defaultConfig,
  );

  // Motion Analysis Services
  sl.registerLazySingleton<IAngleCalculator>(
    () => AngleCalculator(config: sl<InspectionConfig>()),
  );

  sl.registerLazySingleton<IVelocityTracker>(
    () => VelocityTracker(),
  );

  sl.registerLazySingleton<IMotionAnalyzer>(
    () => MotionAnalyzer(
      angleCalculator: sl<IAngleCalculator>(),
      velocityTracker: sl<IVelocityTracker>(),
      config: sl<InspectionConfig>(),
    ),
  );

  // Inspection BLoC (factory - new instance for each inspection session)
  sl.registerFactory<InspectionBloc>(
    () => InspectionBloc(
      motionAnalyzer: sl<IMotionAnalyzer>(),
      config: sl<InspectionConfig>(),
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
