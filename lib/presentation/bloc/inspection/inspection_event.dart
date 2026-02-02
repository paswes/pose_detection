import 'package:equatable/equatable.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/pose_session.dart';

/// Base class for inspection events
abstract class InspectionEvent extends Equatable {
  const InspectionEvent();

  @override
  List<Object?> get props => [];
}

/// Update inspection data from pose session
class UpdateInspectionDataEvent extends InspectionEvent {
  /// Current pose session with metrics
  final PoseSession session;

  /// Current detected pose (may be null if no pose detected)
  final TimestampedPose? currentPose;

  const UpdateInspectionDataEvent({
    required this.session,
    this.currentPose,
  });

  @override
  List<Object?> get props => [session, currentPose];
}

/// Select a specific landmark for detailed inspection
class SelectLandmarkEvent extends InspectionEvent {
  /// Landmark ID to select (null to deselect)
  final int? landmarkId;

  const SelectLandmarkEvent(this.landmarkId);

  @override
  List<Object?> get props => [landmarkId];
}

/// Clear all inspection data (e.g., when session ends)
class ClearInspectionEvent extends InspectionEvent {
  const ClearInspectionEvent();
}
