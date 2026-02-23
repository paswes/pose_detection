/// A suggested exercise for a muscle group.
class ExerciseInfo {
  /// German exercise name.
  final String nameDE;

  /// Equipment needed (e.g., 'Langhantel', 'Koerpergewicht').
  final String equipment;

  const ExerciseInfo({
    required this.nameDE,
    required this.equipment,
  });
}
