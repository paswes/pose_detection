import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// Contract for anatomy data access.
abstract interface class IAnatomyRepository {
  /// Get all muscle groups with their current status.
  List<MuscleGroup> getAllMuscleGroups();

  /// Update the status of a muscle group.
  void updateMuscleStatus(String muscleId, MuscleStatus status);
}
