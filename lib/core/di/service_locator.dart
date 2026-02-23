import 'package:get_it/get_it.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/person_validator.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/core/services/frame_image_decoder.dart';
import 'package:pose_detection/core/services/recording_service.dart';
import 'package:pose_detection/data/database/app_database.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/features/anatomy/data/repositories/anatomy_repository.dart';
import 'package:pose_detection/features/anatomy/domain/repositories/i_anatomy_repository.dart';
import 'package:pose_detection/features/anatomy/presentation/cubit/anatomy_cubit.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_list_cubit.dart';

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

  // Database
  final database = AppDatabase();
  await database.initialize();
  sl.registerSingleton<AppDatabase>(database);

  // Repositories
  sl.registerLazySingleton<SessionRepository>(
    () => SessionRepository(database: sl<AppDatabase>()),
  );

  // Core Services (lazy singletons - created on first access)
  sl.registerLazySingleton<ICameraService>(
    () => CameraService(),
  );

  sl.registerLazySingleton<IPoseDetector>(
    () => PoseDetectionService(),
  );

  sl.registerLazySingleton<IPersonValidator>(
    () => PersonValidator(),
  );

  sl.registerLazySingleton<RecordingService>(
    () => RecordingService(),
  );

  sl.registerLazySingleton<FrameImageDecoder>(
    () => FrameImageDecoder(),
  );

  // Anatomy Feature
  sl.registerLazySingleton<IAnatomyRepository>(
    () => AnatomyRepository(),
  );

  sl.registerFactory<AnatomyCubit>(
    () => AnatomyCubit(repository: sl<IAnatomyRepository>()),
  );

  // BLoC / Cubit
  sl.registerFactory<PoseDetectionBloc>(
    () => PoseDetectionBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      config: sl<PoseDetectionConfig>(),
      personValidator: sl<IPersonValidator>(),
      recordingService: sl<RecordingService>(),
      sessionRepository: sl<SessionRepository>(),
    ),
  );

  sl.registerFactory<SessionListCubit>(
    () => SessionListCubit(repository: sl<SessionRepository>()),
  );

  sl.registerFactoryParam<SessionDetailsCubit, Session, void>(
    (session, _) => SessionDetailsCubit(
      session: session,
      repository: sl<SessionRepository>(),
      decoder: sl<FrameImageDecoder>(),
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
