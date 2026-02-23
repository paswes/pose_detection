import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/services/frame_image_cache.dart';
import 'package:pose_detection/core/services/frame_image_decoder.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages frame-based playback for a recorded session.
///
/// Uses a sliding window [FrameImageCache] to keep only a small number
/// of decoded frames in memory, preventing OOM crashes on long videos.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;
  final FrameImageDecoder _decoder;
  Timer? _autoPlayTimer;
  FrameImageCache? _frameCache;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
    required FrameImageDecoder decoder,
  })  : _repository = repository,
        _decoder = decoder,
        super(const SessionDetailsLoading());

  /// Load tracked frames from DB and prepare the frame cache.
  Future<void> initialize() async {
    try {
      final frames = await _repository.getFramesForSession(session.id);

      if (frames.isEmpty) {
        emit(const SessionDetailsError(message: 'Keine Frames gefunden'));
        return;
      }

      final timestamps = frames.map((f) => f.timestampMicros).toList();

      // Create the sliding window cache (no bulk decode)
      _frameCache = FrameImageCache(
        videoPath: session.videoPath,
        timestampsMicros: timestamps,
        decoder: _decoder,
      );

      // Decode first frame to show immediately
      final firstImage = await _frameCache!.getFrame(0);

      emit(SessionDetailsLoaded(
        session: session,
        frames: frames,
        currentImage: firstImage,
      ));

      // Prefetch frames around the start
      _frameCache!.prefetchAround(0);
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  /// Jump to a specific frame by index.
  Future<void> goToFrame(int index) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final clamped = index.clamp(0, current.totalFrames - 1);
    final image = await _frameCache?.getFrame(clamped);

    emit(current.copyWith(
      currentFrameIndex: clamped,
      currentImage: () => image,
    ));

    _frameCache?.prefetchAround(clamped);
  }

  /// Advance to the next frame.
  Future<void> nextFrame() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex < current.totalFrames - 1) {
      final nextIndex = current.currentFrameIndex + 1;
      final image = await _frameCache?.getFrame(nextIndex);

      emit(current.copyWith(
        currentFrameIndex: nextIndex,
        currentImage: () => image,
      ));

      _frameCache?.prefetchAround(nextIndex);
    }
  }

  /// Go back one frame.
  Future<void> previousFrame() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex > 0) {
      final prevIndex = current.currentFrameIndex - 1;
      final image = await _frameCache?.getFrame(prevIndex);

      emit(current.copyWith(
        currentFrameIndex: prevIndex,
        currentImage: () => image,
      ));

      _frameCache?.prefetchAround(prevIndex);
    }
  }

  /// Select a landmark by ID, or clear selection with null.
  void selectLandmark(int? id) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;
    emit(current.copyWith(selectedLandmarkId: () => id));
  }

  /// Toggle auto-play at the video's natural frame rate.
  void toggleAutoPlay() {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.isAutoPlaying) {
      stopAutoPlay();
    } else {
      _startAutoPlay(current);
    }
  }

  /// Stop auto-play if running.
  void stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;

    final current = state;
    if (current is! SessionDetailsLoaded) return;
    if (current.isAutoPlaying) {
      emit(current.copyWith(isAutoPlaying: false));
    }
  }

  void _startAutoPlay(SessionDetailsLoaded loaded) {
    final intervalMs = _calculateFrameIntervalMs(loaded);

    emit(loaded.copyWith(isAutoPlaying: true));

    _autoPlayTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) async {
        final current = state;
        if (current is! SessionDetailsLoaded) return;

        if (current.currentFrameIndex < current.totalFrames - 1) {
          final nextIndex = current.currentFrameIndex + 1;
          final image = await _frameCache?.getFrame(nextIndex);

          emit(current.copyWith(
            currentFrameIndex: nextIndex,
            currentImage: () => image,
          ));

          _frameCache?.prefetchAround(nextIndex);
        } else {
          // Reached end — loop back to start and stop
          _autoPlayTimer?.cancel();
          _autoPlayTimer = null;

          final firstImage = await _frameCache?.getFrame(0);
          emit(current.copyWith(
            currentFrameIndex: 0,
            currentImage: () => firstImage,
            isAutoPlaying: false,
          ));
        }
      },
    );
  }

  /// Calculate frame interval from stored timestamps.
  int _calculateFrameIntervalMs(SessionDetailsLoaded loaded) {
    if (loaded.frames.length < 2) return 33;

    final first = loaded.frames.first.timestampMicros;
    final last = loaded.frames.last.timestampMicros;
    final totalMs = (last - first) / 1000;
    return (totalMs / (loaded.frames.length - 1)).round().clamp(16, 100);
  }

  @override
  Future<void> close() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    _frameCache?.dispose();
    _frameCache = null;
    return super.close();
  }
}
