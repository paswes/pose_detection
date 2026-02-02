import 'package:get_it/get_it.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';

final GetIt sl = GetIt.instance;

/// Initialize all dependencies.
/// Call this in main() before runApp().
Future<void> initializeDependencies({
  PoseDetectionConfig? config,
  LandmarkSchema? schema,
}) async {
  // Configuration
  sl.registerSingleton<PoseDetectionConfig>(
    config ?? PoseDetectionConfig.defaultConfig,
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

  // BLoC
  sl.registerLazySingleton<PoseDetectionBloc>(
    () => PoseDetectionBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      config: sl<PoseDetectionConfig>(),
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
