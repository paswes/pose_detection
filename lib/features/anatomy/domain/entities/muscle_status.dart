/// Status of a muscle group for visualization on the anatomy avatar.
sealed class MuscleStatus {
  const MuscleStatus();
}

/// Default state — muscle has no special status.
class NormalStatus extends MuscleStatus {
  const NormalStatus();
}

/// Muscle was recently trained.
class TrainedStatus extends MuscleStatus {
  final DateTime trainedAt;

  const TrainedStatus({required this.trainedAt});
}

/// Muscle has a complaint or injury.
class ComplaintStatus extends MuscleStatus {
  final String note;

  const ComplaintStatus({this.note = ''});
}

/// Muscle is identified as a weak point.
class WeakStatus extends MuscleStatus {
  const WeakStatus();
}
