import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';
import 'package:pose_detection/features/anatomy/domain/repositories/i_anatomy_repository.dart';
import 'package:pose_detection/features/anatomy/presentation/cubit/anatomy_state.dart';

/// Manages the anatomy avatar state.
class AnatomyCubit extends Cubit<AnatomyState> {
  final IAnatomyRepository _repository;

  AnatomyCubit({required IAnatomyRepository repository})
      : _repository = repository,
        super(const AnatomyLoading());

  /// Load all muscle groups from repository.
  void loadMuscles() {
    try {
      final muscles = _repository.getAllMuscleGroups();
      emit(AnatomyLoaded(muscles: muscles));
    } catch (e) {
      emit(AnatomyError(message: e.toString()));
    }
  }

  /// Toggle between front and back body view.
  void toggleView() {
    final current = state;
    if (current is! AnatomyLoaded) return;

    final newView = current.currentView == BodyView.front
        ? BodyView.back
        : BodyView.front;

    emit(current.copyWith(
      currentView: newView,
      selectedMuscleId: () => null,
    ));
  }

  /// Set current view directly.
  void setView(BodyView view) {
    final current = state;
    if (current is! AnatomyLoaded) return;

    emit(current.copyWith(
      currentView: view,
      selectedMuscleId: () => null,
    ));
  }

  /// Select a muscle to show its detail sheet.
  void selectMuscle(String muscleId) {
    final current = state;
    if (current is! AnatomyLoaded) return;

    emit(current.copyWith(selectedMuscleId: () => muscleId));
  }

  /// Clear the current muscle selection.
  void clearSelection() {
    final current = state;
    if (current is! AnatomyLoaded) return;

    emit(current.copyWith(selectedMuscleId: () => null));
  }

  /// Update a muscle's status.
  void updateStatus(String muscleId, MuscleStatus status) {
    final current = state;
    if (current is! AnatomyLoaded) return;

    _repository.updateMuscleStatus(muscleId, status);

    final updatedMuscles = _repository.getAllMuscleGroups();
    emit(current.copyWith(muscles: updatedMuscles));
  }

  /// Apply a simulated training session for demo purposes.
  ///
  /// Randomly marks 4–6 muscles as trained.
  void applyDemoTraining() {
    final current = state;
    if (current is! AnatomyLoaded) return;

    final random = Random();
    final muscles = List.of(current.muscles);
    final count = 4 + random.nextInt(3); // 4-6 muscles

    // Shuffle and pick
    final indices = List.generate(muscles.length, (i) => i)..shuffle(random);
    final now = DateTime.now();

    for (var i = 0; i < count && i < indices.length; i++) {
      final muscle = muscles[indices[i]];
      _repository.updateMuscleStatus(
        muscle.id,
        TrainedStatus(trainedAt: now),
      );
    }

    final updatedMuscles = _repository.getAllMuscleGroups();
    emit(current.copyWith(muscles: updatedMuscles));
  }

  /// Reset all muscles to normal status.
  void resetAll() {
    final current = state;
    if (current is! AnatomyLoaded) return;

    for (final muscle in current.muscles) {
      _repository.updateMuscleStatus(muscle.id, const NormalStatus());
    }

    final updatedMuscles = _repository.getAllMuscleGroups();
    emit(current.copyWith(muscles: updatedMuscles));
  }
}
