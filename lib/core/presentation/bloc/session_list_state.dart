import 'package:pose_detection/core/data/models/session.dart';

sealed class SessionListState {
  const SessionListState();
}

class SessionListLoading extends SessionListState {
  const SessionListLoading();
}

class SessionListLoaded extends SessionListState {
  final List<Session> sessions;

  const SessionListLoaded({required this.sessions});
}
