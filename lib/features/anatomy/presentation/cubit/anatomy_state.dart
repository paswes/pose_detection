import 'package:equatable/equatable.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// State for the anatomy avatar page.
sealed class AnatomyState extends Equatable {
  const AnatomyState();
}

/// Initial loading state.
class AnatomyLoading extends AnatomyState {
  const AnatomyLoading();

  @override
  List<Object?> get props => [];
}

/// Muscles loaded and ready for display.
class AnatomyLoaded extends AnatomyState {
  final List<MuscleGroup> muscles;
  final BodyView currentView;
  final String? selectedMuscleId;

  const AnatomyLoaded({
    required this.muscles,
    this.currentView = BodyView.front,
    this.selectedMuscleId,
  });

  /// Muscles visible in the current body view.
  List<MuscleGroup> get visibleMuscles =>
      muscles.where((m) => m.view == currentView).toList();

  /// Find a muscle by ID across all views.
  MuscleGroup? muscleById(String id) {
    for (final m in muscles) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Summary counts.
  int get trainedCount =>
      muscles.where((m) => m.status is TrainedStatus).length;

  int get complaintCount =>
      muscles.where((m) => m.status is ComplaintStatus).length;

  int get weakCount =>
      muscles.where((m) => m.status is WeakStatus).length;

  AnatomyLoaded copyWith({
    List<MuscleGroup>? muscles,
    BodyView? currentView,
    String? Function()? selectedMuscleId,
  }) {
    return AnatomyLoaded(
      muscles: muscles ?? this.muscles,
      currentView: currentView ?? this.currentView,
      selectedMuscleId:
          selectedMuscleId != null ? selectedMuscleId() : this.selectedMuscleId,
    );
  }

  @override
  List<Object?> get props => [muscles, currentView, selectedMuscleId];
}

/// Error state.
class AnatomyError extends AnatomyState {
  final String message;

  const AnatomyError({required this.message});

  @override
  List<Object?> get props => [message];
}
