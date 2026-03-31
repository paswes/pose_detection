import 'package:pose_detection/core/data/models/session.dart';

/// States for the session list on the home page.
sealed class SessionListState {
  const SessionListState();
}

/// Loading sessions (and optionally running feature setup like demo seeding).
class SessionListLoading extends SessionListState {
  const SessionListLoading();
}

/// Sessions loaded successfully.
class SessionListLoaded extends SessionListState {
  final List<Session> sessions;

  const SessionListLoaded({required this.sessions});
}
