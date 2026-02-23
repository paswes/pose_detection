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

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    final sessions = await _repository.getAllSessions();
    emit(SessionListLoaded(sessions: sessions));
  }
}
