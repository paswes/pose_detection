import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';
import 'package:pose_detection/core/data/repositories/session_repository.dart';
import 'package:pose_detection/core/presentation/bloc/session_details_state.dart';

class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;
  final ExerciseAnalyzer? _analyzer;
  VideoPlayerController? _controller;

  final frameNotifier = ValueNotifier<TrackedFrame?>(null);

  DateTime _lastScrubSeek = DateTime(0);
  static const _scrubSeekInterval = Duration(milliseconds: 100);

  VideoPlayerController? get videoController => _controller;

  ExerciseAnalyzer? get analyzer => _analyzer;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
    ExerciseAnalyzer? analyzer,
  }) : _repository = repository,
       _analyzer = analyzer,
       super(const SessionDetailsLoading());

  /// Load tracked frame data from DB and initialize the video player.
  Future<void> initialize() async {
    try {
      final frames = await _repository.getFramesForSession(session.id);

      if (frames.isEmpty) {
        emit(const SessionDetailsError(message: 'Keine Frames gefunden'));
        return;
      }

      final videoFile = File(session.videoPath);
      if (!videoFile.existsSync()) {
        emit(const SessionDetailsError(message: 'Video nicht gefunden'));
        return;
      }

      _controller = VideoPlayerController.file(videoFile);
      await _controller!.initialize();

      await _controller!.seekTo(Duration.zero);
      frameNotifier.value = frames.first;
      _analyzer?.precompute(frames);

      emit(
        SessionDetailsLoaded(
          session: session,
          frames: frames,
          isVideoReady: true,
          videoDuration: _controller!.value.duration,
        ),
      );

      _controller!.addListener(_onVideoPositionChanged);
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  static const availableSpeeds = [0.25, 0.5, 0.75, 1.0];

  static const _baseLookAheadMicros = 66000;

  static int _scaledLookAheadMicros(double speed) =>
      (_baseLookAheadMicros * speed).round();

  void _onVideoPositionChanged() {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final controller = _controller;
    if (controller == null) return;

    final position = controller.value.position;
    final isPlaying = controller.value.isPlaying;

    final positionMicros = isPlaying
        ? position.inMicroseconds +
              _scaledLookAheadMicros(current.playbackSpeed)
        : position.inMicroseconds;
    final newIndex = _findNearestFrameIndex(current.frames, positionMicros);

    if (newIndex != current.currentFrameIndex) {
      frameNotifier.value = current.frames[newIndex];

      if (_analyzer != null) {
        final prevIndex = current.currentFrameIndex;
        if (newIndex > prevIndex) {
          _analyzer.processFrameRange(
            current.frames,
            prevIndex + 1,
            newIndex,
          );
        } else {
          _analyzer.replayUpTo(current.frames, newIndex);
        }
      }
    }

    if (newIndex == current.currentFrameIndex &&
        isPlaying == current.isPlaying &&
        position == current.videoPosition) {
      return;
    }

    emit(
      current.copyWith(
        currentFrameIndex: newIndex,
        videoPosition: position,
        isPlaying: isPlaying,
      ),
    );
  }

  int _findNearestFrameIndex(
    List<TrackedFrame> frames,
    int positionMicros,
  ) {
    if (frames.isEmpty) return 0;
    if (frames.length == 1) return 0;

    int lo = 0;
    int hi = frames.length - 1;

    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timestampMicros < positionMicros) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    if (lo > 0) {
      final diffLo = (frames[lo].timestampMicros - positionMicros).abs();
      final diffPrev = (frames[lo - 1].timestampMicros - positionMicros).abs();
      if (diffPrev < diffLo) return lo - 1;
    }

    return lo;
  }

  Future<void> togglePlayPause() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (current.currentFrameIndex >= current.totalFrames - 1) {
        _analyzer?.reset();
        _analyzer?.processFrame(
          current.frames.first,
          globalFrameIndex: 0,
        );
        frameNotifier.value = current.frames.first;
        await controller.seekTo(Duration.zero);
        emit(
          current.copyWith(
            currentFrameIndex: 0,
            videoPosition: Duration.zero,
          ),
        );
        await controller.play();
        return;
      }

      final targetMicros =
          current.frames[current.currentFrameIndex].timestampMicros;
      await controller.seekTo(Duration(microseconds: targetMicros));
      await controller.play();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    await _controller?.setPlaybackSpeed(speed);
    emit(current.copyWith(playbackSpeed: speed));
  }

  Future<void> seekToFrame(int index) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final clamped = index.clamp(0, current.totalFrames - 1);
    final timestampMicros = current.frames[clamped].timestampMicros;

    _analyzer?.replayUpTo(current.frames, clamped);

    frameNotifier.value = current.frames[clamped];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(
      current.copyWith(
        currentFrameIndex: clamped,
        videoPosition: Duration(microseconds: timestampMicros),
      ),
    );
  }

  void scrubToFrame(int index) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final clamped = index.clamp(0, current.totalFrames - 1);
    final timestampMicros = current.frames[clamped].timestampMicros;

    _analyzer?.replayUpTo(current.frames, clamped);

    frameNotifier.value = current.frames[clamped];

    final now = DateTime.now();
    if (now.difference(_lastScrubSeek) >= _scrubSeekInterval) {
      _lastScrubSeek = now;
      _controller?.seekTo(Duration(microseconds: timestampMicros));
    }

    emit(
      current.copyWith(
        currentFrameIndex: clamped,
        videoPosition: Duration(microseconds: timestampMicros),
      ),
    );
  }

  Future<void> commitScrub() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final timestampMicros =
        current.frames[current.currentFrameIndex].timestampMicros;
    await _controller?.seekTo(Duration(microseconds: timestampMicros));
  }

  Future<void> nextFrame() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex >= current.totalFrames - 1) return;

    if (_controller?.value.isPlaying == true) {
      await _controller?.pause();
    }

    final nextIndex = current.currentFrameIndex + 1;
    final timestampMicros = current.frames[nextIndex].timestampMicros;

    _analyzer?.processFrame(
      current.frames[nextIndex],
      globalFrameIndex: nextIndex,
    );

    frameNotifier.value = current.frames[nextIndex];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(
      current.copyWith(
        currentFrameIndex: nextIndex,
        videoPosition: Duration(microseconds: timestampMicros),
        isPlaying: false,
      ),
    );
  }

  Future<void> previousFrame() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex <= 0) return;

    if (_controller?.value.isPlaying == true) {
      await _controller?.pause();
    }

    final prevIndex = current.currentFrameIndex - 1;
    final timestampMicros = current.frames[prevIndex].timestampMicros;

    _analyzer?.replayUpTo(current.frames, prevIndex);

    frameNotifier.value = current.frames[prevIndex];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(
      current.copyWith(
        currentFrameIndex: prevIndex,
        videoPosition: Duration(microseconds: timestampMicros),
        isPlaying: false,
      ),
    );
  }

  void selectLandmark(int? id) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;
    emit(current.copyWith(selectedLandmarkId: () => id));
  }

  @override
  Future<void> close() {
    _controller?.removeListener(_onVideoPositionChanged);
    _controller?.dispose();
    _controller = null;
    frameNotifier.dispose();
    return super.close();
  }
}
