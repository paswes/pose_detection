import 'package:get_it/get_it.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/core/interfaces/person_validator_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/person_validator.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/core/services/recording_service.dart';
import 'package:pose_detection/core/data/database/app_database.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/core/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/core/presentation/bloc/session_list_cubit.dart'
    show SessionListCubit, BeforeLoadHook;

/// Callback for features to register their own dependencies.
typedef FeatureRegistrar = void Function(GetIt sl);

/// Resolves which [ExerciseAnalyzer] to use for a given session.
/// Returns `null` for sessions that need no exercise analysis.
typedef AnalyzerResolver = ExerciseAnalyzer? Function(Session session);

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies({
  LandmarkSchema? schema,
  List<FeatureRegistrar>? featureRegistrars,
  AnalyzerResolver? analyzerResolver,
  BeforeLoadHook? beforeLoad,
}) async {
  // -- Core singletons --

  sl.registerSingleton<LandmarkSchema>(
    schema ?? LandmarkSchema.mlKit33,
  );

  final database = AppDatabase();
  await database.initialize();
  sl.registerSingleton<AppDatabase>(database);

  sl.registerLazySingleton<SessionRepository>(
    () => SessionRepository(database: sl<AppDatabase>()),
  );

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

  // -- Feature registration --

  for (final registrar in featureRegistrars ?? []) {
    registrar(sl);
  }

  final resolveAnalyzer = analyzerResolver;

  // -- Factories (BLoC / Cubit) --

  sl.registerFactory<PoseDetectionBloc>(
    () => PoseDetectionBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      personValidator: sl<IPersonValidator>(),
      recordingService: sl<RecordingService>(),
      sessionRepository: sl<SessionRepository>(),
    ),
  );

  sl.registerFactory<SessionListCubit>(
    () => SessionListCubit(
      repository: sl<SessionRepository>(),
      beforeLoad: beforeLoad,
    ),
  );

  sl.registerFactoryParam<SessionDetailsCubit, Session, void>(
    (session, _) => SessionDetailsCubit(
      session: session,
      repository: sl<SessionRepository>(),
      analyzer: resolveAnalyzer?.call(session),
    ),
  );
}

Future<void> resetDependencies() async {
  await sl.reset();
}

bool get dependenciesInitialized => sl.isRegistered<AppDatabase>();
