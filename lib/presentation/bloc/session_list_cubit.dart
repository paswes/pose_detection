import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/services/demo_session_service.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';

/// Cubit for managing the session list on the home page.
class SessionListCubit extends Cubit<List<Session>> {
  final SessionRepository _repository;
  final DemoSessionService _demoService;

  SessionListCubit({
    required SessionRepository repository,
    required DemoSessionService demoService,
  })  : _repository = repository,
        _demoService = demoService,
        super(const []);

  /// Seed the demo session (if needed) and load all sessions.
  Future<void> loadSessions() async {
    await _demoService.ensureDemoSession();
    final sessions = await _repository.getAllSessions();
    emit(sessions);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    await loadSessions();
  }
}
