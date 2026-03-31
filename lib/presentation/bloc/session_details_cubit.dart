import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages video playback with synchronized landmark overlay.
///
/// Uses [VideoPlayerController] for hardware-accelerated video playback.
/// Matches the current video position to the nearest stored [TrackedFrame]
/// via binary search, so landmarks stay in sync with the displayed frame.
///
/// An optional [ExerciseAnalyzer] is called during frame processing to
/// provide exercise-specific analysis (e.g. rep counting). When null,
/// the page shows a raw landmark view.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;
  final ExerciseAnalyzer? _analyzer;
  VideoPlayerController? _controller;

  /// Direct repaint signal for the landmark overlay painter.
  ///
  /// Updated synchronously in the video position listener so the overlay
  /// repaints on the next render frame — bypassing the BLoC rebuild pipeline
  /// to eliminate visible lag between video and landmarks.
  final frameNotifier = ValueNotifier<TrackedFrame?>(null);

  /// Throttle state for scrub video seeks.
  DateTime _lastScrubSeek = DateTime(0);
  static const _scrubSeekInterval = Duration(milliseconds: 100);

  /// Exposes the video controller for the page to build the [VideoPlayer] widget.
  VideoPlayerController? get videoController => _controller;

  /// The exercise analyzer, if any. The page queries this for UI extensions.
  ExerciseAnalyzer? get analyzer => _analyzer;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
    ExerciseAnalyzer? analyzer,
  }) : _repository = repository,
       _analyzer = analyzer,
       super(const SessionDetailsLoading());

  /// Load tracked frames from DB and initialize the video player.
  Future<void> initialize() async {
    try {
      final frames = await _repository.getFramesForSession(session.id);

      if (frames.isEmpty) {
        emit(const SessionDetailsError(message: 'Keine Frames gefunden'));
        return;
      }

      // Initialize video player
      final videoFile = File(session.videoPath);
      if (!videoFile.existsSync()) {
        emit(const SessionDetailsError(message: 'Video nicht gefunden'));
        return;
      }

      _controller = VideoPlayerController.file(videoFile);
      await _controller!.initialize();

      // Seek to start to ensure position is exactly 0
      await _controller!.seekTo(Duration.zero);

      // Set initial frame for the painter
      frameNotifier.value = frames.first;

      // Let the analyzer pre-compute over all frames (e.g. rep counting).
      _analyzer?.precompute(frames);

      emit(
        SessionDetailsLoaded(
          session: session,
          frames: frames,
          isVideoReady: true,
          videoDuration: _controller!.value.duration,
        ),
      );

      // Add listener AFTER initial state is emitted, so any early
      // callbacks find a valid SessionDetailsLoaded state
      _controller!.addListener(_onVideoPositionChanged);
    } catch (e) {
      emit(SessionDetailsError(message: 'Fehler beim Laden: $e'));
    }
  }

  /// Available playback speed options for analysis mode.
  static const availableSpeeds = [0.25, 0.5, 0.75, 1.0];

  /// Base lookahead at 1.0x, compensating for iOS AVPlayer platform channel
  /// reporting delay (~2 frames at 30 FPS).
  static const _baseLookAheadMicros = 66000;

  /// Scaled lookahead for a given playback speed.
  static int _scaledLookAheadMicros(double speed) =>
      (_baseLookAheadMicros * speed).round();

  /// Listener called by [VideoPlayerController] on position/state changes.
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

    // Update painter directly for instant overlay sync
    if (newIndex != current.currentFrameIndex) {
      frameNotifier.value = current.frames[newIndex];

      // Delegate frame processing to the analyzer
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

    // Only emit BLoC state when something actually changed
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

  /// Binary search for the frame closest to [positionMicros].
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

  /// Toggle play/pause.
  Future<void> togglePlayPause() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      // If at the last frame, restart from the beginning
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

  /// Set the video playback speed.
  Future<void> setPlaybackSpeed(double speed) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    await _controller?.setPlaybackSpeed(speed);
    emit(current.copyWith(playbackSpeed: speed));
  }

  /// Seek to a specific frame by index.
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

  /// Update overlay and state, with throttled video seeks.
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

  /// Seek the video controller to the current frame position.
  Future<void> commitScrub() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final timestampMicros =
        current.frames[current.currentFrameIndex].timestampMicros;
    await _controller?.seekTo(Duration(microseconds: timestampMicros));
  }

  /// Advance to the next frame (pauses if playing).
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

  /// Go back one frame (pauses if playing).
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

  /// Select a landmark by ID, or clear selection with null.
  void selectLandmark(int? id) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;
    emit(current.copyWith(selectedLandmarkId: () => id));
  }

  /// Toggle injury marking for a landmark.
  void toggleLandmarkInjury(int id) {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final updated = Set<int>.from(current.injuredLandmarkIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    emit(current.copyWith(injuredLandmarkIds: updated));
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
