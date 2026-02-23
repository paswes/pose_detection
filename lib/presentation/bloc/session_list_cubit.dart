import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/services/demo_session_service.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_list_state.dart';

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  final DemoSessionService _demoService;

  SessionListCubit({
    required SessionRepository repository,
    required DemoSessionService demoService,
  })  : _repository = repository,
        _demoService = demoService,
        super(const SessionListInitializing());

  /// Seed the demo session (if needed) and load all sessions.
  Future<void> loadSessions() async {
    final needsDemo = await _demoService.needsProcessing();

    if (needsDemo) {
      emit(const SessionListInitializing());
      await _demoService.ensureDemoSession(
        onProgress: (completed, total) {
          emit(SessionListInitializing(
            completedFrames: completed,
            totalFrames: total,
          ));
        },
      );
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
