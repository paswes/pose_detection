import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/interfaces/demo_session_service.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/presentation/bloc/session_list_state.dart';

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  final DemoSessionService? _demoService;

  SessionListCubit({
    required SessionRepository repository,
    DemoSessionService? demoService,
  }) : _repository = repository,
       _demoService = demoService,
       super(const SessionListInitializing());

  /// Seed the demo session (if needed) and load all sessions.
  Future<void> loadSessions() async {
    final demoService = _demoService;
    if (demoService != null) {
      final needsDemo = await demoService.needsProcessing();
      if (needsDemo) {
        emit(const SessionListInitializing());
        await demoService.ensureDemoSession(
          onProgress: (completed, total) {
            emit(
              SessionListInitializing(
                completedFrames: completed,
                totalFrames: total,
              ),
            );
          },
        );
      }
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
