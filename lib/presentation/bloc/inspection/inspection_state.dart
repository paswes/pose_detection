import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/inspection_snapshot.dart';

/// Base class for inspection states
abstract class InspectionState extends Equatable {
  const InspectionState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no data yet
class InspectionInitial extends InspectionState {
  const InspectionInitial();
}

/// Active inspection state with data
class InspectionActive extends InspectionState {
  /// Current inspection snapshot with all metrics
  final InspectionSnapshot snapshot;

  /// Currently selected landmark ID for detail view (null if none)
  final int? selectedLandmarkId;

  const InspectionActive({
    required this.snapshot,
    this.selectedLandmarkId,
  });

  /// Create a copy with updated values
  InspectionActive copyWith({
    InspectionSnapshot? snapshot,
    int? selectedLandmarkId,
    bool clearSelectedLandmark = false,
  }) {
    return InspectionActive(
      snapshot: snapshot ?? this.snapshot,
      selectedLandmarkId:
          clearSelectedLandmark ? null : (selectedLandmarkId ?? this.selectedLandmarkId),
    );
  }

  @override
  List<Object?> get props => [snapshot, selectedLandmarkId];
}
