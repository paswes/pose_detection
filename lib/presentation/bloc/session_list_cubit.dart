import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/services/demo_session_service.dart';
import 'package:pose_detection/core/services/video_processing_service.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_list_state.dart';

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  final DemoSessionService _demoService;
  final VideoProcessingService _processingService;

  SessionListCubit({
    required SessionRepository repository,
    required DemoSessionService demoService,
    required VideoProcessingService processingService,
  })  : _repository = repository,
        _demoService = demoService,
        _processingService = processingService,
        super(const SessionListLoaded(sessions: []));

  /// Load all sessions from the database.
  Future<void> loadSessions() async {
    final sessions = await _repository.getAllSessions();
    emit(SessionListLoaded(sessions: sessions));
  }

  /// Process and load the bundled demo RDL video on demand.
  Future<void> loadDemoSession() async {
    emit(const SessionListInitializing());
    await _demoService.ensureDemoSession(
      onProgress: (completed, total) {
        emit(SessionListInitializing(
          completedFrames: completed,
          totalFrames: total,
        ));
      },
    );
    final sessions = await _repository.getAllSessions();
    emit(SessionListLoaded(sessions: sessions));
  }

  /// Pick, process, and save a video — shows a processing placeholder in the list.
  Future<void> processVideoFromPath(String videoPath) async {
    final current = state;
    final currentSessions =
        current is SessionListLoaded ? current.sessions : <Session>[];

    // Show placeholder card immediately
    emit(SessionListLoaded(
      sessions: currentSessions,
      processingVideo: true,
    ));

    try {
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      final result = await _processingService.processVideo(
        videoPath,
        sessionId,
        onProgress: (completed, total) {
          final s = state;
          if (s is SessionListLoaded) {
            emit(s.copyWith(
              processingCompleted: completed,
              processingTotal: total,
            ));
          }
        },
      );

      final isLandscape = result.imageWidth > result.imageHeight;
      final session = Session(
        id: result.sessionId,
        title: 'Video Upload',
        createdAt: DateTime.now(),
        durationMs: result.durationMs,
        videoPath: result.videoPath,
        frameCount: result.frames.length,
        isFrontCamera: false,
        isLandscape: isLandscape,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
        sensorOrientation: 0,
      );

      await _repository.saveSession(session, result.frames);
    } catch (_) {
      // fall through to reload — placeholder will disappear
    }

    final sessions = await _repository.getAllSessions();
    emit(SessionListLoaded(sessions: sessions));
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    final sessions = await _repository.getAllSessions();
    emit(SessionListLoaded(sessions: sessions));
  }
}
