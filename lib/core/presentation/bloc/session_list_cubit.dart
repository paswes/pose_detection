import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/presentation/bloc/session_list_state.dart';

typedef BeforeLoadHook = Future<void> Function();

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
