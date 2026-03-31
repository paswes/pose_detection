import 'package:get_it/get_it.dart';

import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/interfaces/demo_session_service.dart';
import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/core/services/video_processing_service.dart';
import 'package:pose_detection/rdl_example/data/rdl_demo_session_service.dart';
import 'package:pose_detection/rdl_example/presentation/rdl_analyzer.dart';

/// Register RDL-specific dependencies.
void registerRdlDependencies(GetIt sl) {
  sl.registerLazySingleton<RdlDemoSessionService>(
    () => RdlDemoSessionService(
      repository: sl<SessionRepository>(),
      processingService: sl<VideoProcessingService>(),
    ),
  );
}

/// Provides the [DemoSessionService] for the RDL feature.
DemoSessionService rdlDemoService(GetIt sl) => sl<RdlDemoSessionService>();

/// Resolves the [ExerciseAnalyzer] for a given session.
///
/// Demo sessions get the [RdlAnalyzer]; all others get none.
ExerciseAnalyzer? rdlAnalyzerResolver(Session session) {
  if (session.isDemo) return RdlAnalyzer();
  return null;
}
