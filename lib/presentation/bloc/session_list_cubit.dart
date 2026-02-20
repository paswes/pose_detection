import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<List<Session>> {
  final SessionRepository _repository;

  SessionListCubit({required SessionRepository repository})
      : _repository = repository,
        super(const []);

  Future<void> loadSessions() async {
    final sessions = await _repository.getAllSessions();
    emit(sessions);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    await loadSessions();
  }
}
