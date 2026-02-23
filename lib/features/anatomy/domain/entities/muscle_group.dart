import 'package:pose_detection/features/anatomy/domain/entities/exercise_info.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// A muscle group that can be displayed on the anatomy avatar.
class MuscleGroup {
  /// Unique identifier (e.g., 'chest', 'biceps').
  final String id;

  /// German display name (e.g., 'Brustmuskel').
  final String nameDE;

  /// Latin/anatomical name (e.g., 'M. pectoralis major').
  final String nameLatin;

  /// Anatomical origin (Ursprung).
  final String origin;

  /// Anatomical insertion (Ansatz).
  final String insertion;

  /// Primary function (Funktion).
  final String function;

  /// Suggested exercises for this muscle.
  final List<ExerciseInfo> exercises;

  /// Current status for visualization.
  final MuscleStatus status;

  const MuscleGroup({
    required this.id,
    required this.nameDE,
    required this.nameLatin,
    required this.origin,
    required this.insertion,
    required this.function,
    required this.exercises,
    this.status = const NormalStatus(),
  });

  MuscleGroup copyWith({MuscleStatus? status}) {
    return MuscleGroup(
      id: id,
      nameDE: nameDE,
      nameLatin: nameLatin,
      origin: origin,
      insertion: insertion,
      function: function,
      exercises: exercises,
      status: status ?? this.status,
    );
  }
}
