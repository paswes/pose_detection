import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages video playback and landmark frame synchronization
/// for a recorded session.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;

  VideoPlayerController? _videoController;
  List<TrackedFrame> _frames = [];
  List<int> _relativeOffsetsMicros = [];
  int _lastEmittedFrameTimestamp = -1;

  /// Access the video controller for the UI layer.
  VideoPlayerController? get videoController => _videoController;

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

      _frames = await _repository.getFramesForSession(session.id);

      // Pre-compute relative offsets for binary search
      if (_frames.isNotEmpty) {
        final baseTimestamp = _frames.first.timestampMicros;
        _relativeOffsetsMicros = _frames
            .map((f) => f.timestampMicros - baseTimestamp)
            .toList();
      }

      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      _videoController!.addListener(_onVideoPositionChanged);

      final duration = _videoController!.value.duration;
      final initialFrame = _frames.isNotEmpty ? _frames.first : null;

      emit(SessionDetailsLoaded(
        session: session,
        frames: _frames,
        isPlaying: false,
        position: Duration.zero,
        duration: duration,
        currentFrame: initialFrame,
      ));
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  void _onVideoPositionChanged() {
    final controller = _videoController;
    if (controller == null) return;

    final currentState = state;
    if (currentState is! SessionDetailsLoaded) return;

    final position = controller.value.position;
    final isPlaying = controller.value.isPlaying;
    final frame = _findNearestFrame(position);

    final frameTimestamp = frame?.timestampMicros ?? -1;
    final frameChanged = frameTimestamp != _lastEmittedFrameTimestamp;
    final playStateChanged = isPlaying != currentState.isPlaying;
    final positionChanged = position != currentState.position;

    if (!frameChanged && !playStateChanged && !positionChanged) return;

    _lastEmittedFrameTimestamp = frameTimestamp;

    emit(currentState.copyWith(
      position: position,
      isPlaying: isPlaying,
      currentFrame: frame,
    ));
  }

  /// Find the nearest tracked frame for a given video position.
  TrackedFrame? _findNearestFrame(Duration position) {
    if (_frames.isEmpty || _relativeOffsetsMicros.isEmpty) return null;

    final targetMicros = position.inMicroseconds;

    // Binary search for the closest frame
    int low = 0;
    int high = _relativeOffsetsMicros.length - 1;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_relativeOffsetsMicros[mid] < targetMicros) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    // Check neighbors to find the true closest
    if (low > 0) {
      final diffLow = (targetMicros - _relativeOffsetsMicros[low - 1]).abs();
      final diffHigh = (targetMicros - _relativeOffsetsMicros[low]).abs();
      if (diffLow < diffHigh) {
        return _frames[low - 1];
      }
    }

    return _frames[low];
  }

  /// Toggle between play and pause.
  Future<void> togglePlayback() async {
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  @override
  Future<void> close() {
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    return super.close();
  }
}
