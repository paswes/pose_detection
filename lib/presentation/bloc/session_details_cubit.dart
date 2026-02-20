import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/services/playback_sync_engine.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages video playback and landmark frame synchronization
/// for a recorded session.
///
/// Exposes [syncEngine] for direct use by the overlay painter,
/// bypassing BLoC rebuild latency for frame-accurate rendering.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;

  VideoPlayerController? _videoController;
  PlaybackSyncEngine? _syncEngine;

  /// Access the video controller for the UI layer.
  VideoPlayerController? get videoController => _videoController;

  /// Access the sync engine for direct use by the overlay painter.
  PlaybackSyncEngine? get syncEngine => _syncEngine;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
  }) : _repository = repository,
       super(const SessionDetailsLoading());

  /// Load frames and initialize the video player.
  Future<void> initialize() async {
    try {
      final videoFile = File(session.videoPath);
      if (!videoFile.existsSync()) {
        emit(const SessionDetailsError(
          message: 'Videodatei nicht gefunden',
        ));
        return;
      }

      final frames = await _repository.getFramesForSession(session.id);

      _syncEngine = PlaybackSyncEngine(frames: frames);

      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      _videoController!.addListener(_onVideoPositionChanged);

      final duration = _videoController!.value.duration;

      emit(SessionDetailsLoaded(
        session: session,
        frames: frames,
        isPlaying: false,
        position: Duration.zero,
        duration: duration,
        currentFrameIndex: 0,
        totalFrames: frames.length,
      ));
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  /// Listener for VideoPlayerController — updates play/pause state
  /// and slider position only. The overlay painter reads position directly.
  void _onVideoPositionChanged() {
    final controller = _videoController;
    if (controller == null) return;

    final currentState = state;
    if (currentState is! SessionDetailsLoaded) return;

    final position = controller.value.position;
    final isPlaying = controller.value.isPlaying;

    final playStateChanged = isPlaying != currentState.isPlaying;
    final positionChanged = position != currentState.position;

    if (!playStateChanged && !positionChanged) return;

    // When playback starts, switch to continuous mode
    PlaybackMode? mode;
    if (isPlaying && currentState.playbackMode == PlaybackMode.frameStepping) {
      mode = PlaybackMode.continuous;
    }

    // Update frame index from current position for the controls
    final engine = _syncEngine;
    int? frameIndex;
    if (engine != null && engine.hasFrames) {
      frameIndex = engine.findNearestFrameIndex(position);
    }

    emit(currentState.copyWith(
      position: position,
      isPlaying: isPlaying,
      playbackMode: mode,
      currentFrameIndex: frameIndex,
      clearSelectedLandmark: isPlaying,
    ));
  }

  /// Toggle between play and pause.
  Future<void> togglePlayback() async {
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      // Clear landmark selection when starting playback
      final currentState = state;
      if (currentState is SessionDetailsLoaded &&
          currentState.selectedLandmarkId != null) {
        emit(currentState.copyWith(clearSelectedLandmark: true));
      }
      await controller.play();
    }
  }

  /// Step to the next frame (enters frame-stepping mode).
  Future<void> stepForward() async {
    await _stepToFrame(1);
  }

  /// Step to the previous frame (enters frame-stepping mode).
  Future<void> stepBackward() async {
    await _stepToFrame(-1);
  }

  Future<void> _stepToFrame(int delta) async {
    final controller = _videoController;
    final engine = _syncEngine;
    if (controller == null || engine == null || !engine.hasFrames) return;

    // Pause if playing
    if (controller.value.isPlaying) {
      await controller.pause();
    }

    final currentState = state;
    if (currentState is! SessionDetailsLoaded) return;

    final newIndex = (currentState.currentFrameIndex + delta)
        .clamp(0, engine.frameCount - 1);

    final frame = engine.getFrameByIndex(newIndex);
    if (frame == null) return;

    // Seek video to the frame's timestamp
    await controller.seekTo(Duration(microseconds: frame.timestampMicros));

    emit(currentState.copyWith(
      currentFrameIndex: newIndex,
      position: Duration(microseconds: frame.timestampMicros),
      isPlaying: false,
      playbackMode: PlaybackMode.frameStepping,
      clearSelectedLandmark: true,
    ));
  }

  /// Seek to a specific position (from slider drag).
  Future<void> seekToPosition(Duration position) async {
    final controller = _videoController;
    final engine = _syncEngine;
    if (controller == null) return;

    await controller.seekTo(position);

    final currentState = state;
    if (currentState is! SessionDetailsLoaded) return;

    int? frameIndex;
    if (engine != null && engine.hasFrames) {
      frameIndex = engine.findNearestFrameIndex(position);
    }

    emit(currentState.copyWith(
      position: position,
      currentFrameIndex: frameIndex,
      clearSelectedLandmark: true,
    ));
  }

  /// Select a landmark to show its detail card.
  void selectLandmark(int? landmarkId) {
    final currentState = state;
    if (currentState is! SessionDetailsLoaded) return;

    if (landmarkId == null) {
      emit(currentState.copyWith(clearSelectedLandmark: true));
    } else {
      emit(currentState.copyWith(selectedLandmarkId: landmarkId));
    }
  }

  @override
  Future<void> close() {
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    return super.close();
  }
}
