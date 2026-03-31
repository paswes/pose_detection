import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/presentation/bloc/session_list_state.dart';

/// Optional async setup hook called before loading sessions.
/// Features can use this to seed demo data, run migrations, etc.
typedef BeforeLoadHook = Future<void> Function();

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<SessionListState> {
  final SessionRepository _repository;
  final BeforeLoadHook? _beforeLoad;
  bool _hasRunBeforeLoad = false;

  SessionListCubit({
    required SessionRepository repository,
    BeforeLoadHook? beforeLoad,
  }) : _repository = repository,
       _beforeLoad = beforeLoad,
       super(const SessionListLoading());

  /// Run optional setup hook (once) then load all sessions.
  Future<void> loadSessions() async {
    if (!_hasRunBeforeLoad && _beforeLoad != null) {
      _hasRunBeforeLoad = true;
      emit(const SessionListLoading());
      await _beforeLoad();
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
