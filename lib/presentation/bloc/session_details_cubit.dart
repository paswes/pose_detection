import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/services/frame_image_decoder.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages frame-based playback for a recorded session.
///
/// Uses pre-decoded frame images for guaranteed
/// landmark-video synchronization.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;
  final FrameImageDecoder _decoder;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
    required FrameImageDecoder decoder,
  }) : _repository = repository,
       _decoder = decoder,
       super(const SessionDetailsLoading());

  /// Load tracked frames from DB, then decode video frames to images.
  Future<void> initialize() async {
    try {
      final frames = await _repository.getFramesForSession(session.id);

      if (frames.isEmpty) {
        emit(const SessionDetailsError(message: 'Keine Frames gefunden'));
        return;
      }

      emit(const SessionDetailsDecoding(completed: 0, total: 0));

      final timestamps = frames.map((f) => f.timestampMicros).toList();

      final images = await _decoder.decodeAllFrames(
        session.videoPath,
        timestamps,
        onProgress: (completed, total) {
          emit(SessionDetailsDecoding(completed: completed, total: total));
        },
      );

      if (images.isEmpty) {
        emit(const SessionDetailsError(
          message: 'Frames konnten nicht geladen werden',
        ));
        return;
      }

      emit(SessionDetailsLoaded(
        session: session,
        frames: frames,
        frameImages: images,
      ));
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  /// Jump to a specific frame by index.
  void goToFrame(int index) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final clamped = index.clamp(0, current.totalFrames - 1);
    emit(current.copyWith(currentFrameIndex: clamped));
  }

  /// Advance to the next frame.
  void nextFrame() {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex < current.totalFrames - 1) {
      emit(current.copyWith(
        currentFrameIndex: current.currentFrameIndex + 1,
      ));
    }
  }

  /// Go back one frame.
  void previousFrame() {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex > 0) {
      emit(current.copyWith(
        currentFrameIndex: current.currentFrameIndex - 1,
      ));
    }
  }

  /// Select a landmark by ID, or clear selection with null.
  void selectLandmark(int? id) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;
    emit(current.copyWith(selectedLandmarkId: () => id));
  }
}
