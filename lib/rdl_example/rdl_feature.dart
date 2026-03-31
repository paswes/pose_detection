import 'package:get_it/get_it.dart';

import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/rdl_example/data/rdl_demo_session_service.dart';
import 'package:pose_detection/rdl_example/data/static_image_pose_detector.dart';
import 'package:pose_detection/rdl_example/data/video_processing_service.dart';
import 'package:pose_detection/rdl_example/presentation/rdl_analyzer.dart';

/// Register RDL-specific dependencies.
void registerRdlDependencies(GetIt sl) {
  sl.registerLazySingleton<StaticImagePoseDetector>(
    () => StaticImagePoseDetector(),
  );

  sl.registerLazySingleton<VideoProcessingService>(
    () => VideoProcessingService(
      poseDetector: sl<StaticImagePoseDetector>(),
    ),
  );

  sl.registerLazySingleton<RdlDemoSessionService>(
    () => RdlDemoSessionService(
      repository: sl<SessionRepository>(),
      processingService: sl<VideoProcessingService>(),
    ),
  );
}

/// Seed the demo session if needed. Call before runApp().
Future<void> ensureRdlDemo(GetIt sl) async {
  final demoService = sl<RdlDemoSessionService>();
  if (await demoService.needsProcessing()) {
    await demoService.ensureDemoSession();
  }
}

/// Resolves the [ExerciseAnalyzer] for a given session.
///
/// Demo sessions get the [RdlAnalyzer]; all others get none.
ExerciseAnalyzer? rdlAnalyzerResolver(Session session) {
  if (session.isDemo) return RdlAnalyzer();
  return null;
}
