import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/utils/rdl_rep_counter.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/data/repositories/session_repository.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';

/// Manages video playback with synchronized landmark overlay.
///
/// Uses [VideoPlayerController] for hardware-accelerated video playback.
/// Matches the current video position to the nearest stored [TrackedFrame]
/// via binary search, so landmarks stay in sync with the displayed frame.
class SessionDetailsCubit extends Cubit<SessionDetailsState> {
  final Session session;
  final SessionRepository _repository;
  final RdlRepCounter _repCounter = RdlRepCounter();
  VideoPlayerController? _controller;

  /// Direct repaint signal for the landmark overlay painter.
  ///
  /// Updated synchronously in the video position listener so the overlay
  /// repaints on the next render frame — bypassing the BLoC rebuild pipeline
  /// to eliminate visible lag between video and landmarks.
  final frameNotifier = ValueNotifier<TrackedFrame?>(null);

  /// Exposes the video controller for the page to build the [VideoPlayer] widget.
  VideoPlayerController? get videoController => _controller;

  SessionDetailsCubit({
    required this.session,
    required SessionRepository repository,
  })  : _repository = repository,
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

      // Process first frame for initial angle
      _repCounter.processFrame(frames.first, globalFrameIndex: 0);

      emit(SessionDetailsLoaded(
        session: session,
        frames: frames,
        isVideoReady: true,
        videoDuration: _controller!.value.duration,
        hipAngle: _repCounter.currentAngle,
        reps: _repCounter.reps,
      ));

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
  ///
  /// The platform channel delay is constant in real time (~66 ms), but at
  /// reduced speeds the video advances slower through that same real-time
  /// window. Scaling keeps the landmark overlay aligned with the displayed
  /// frame at any speed.
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

    // Compensate for iOS platform channel delay during playback,
    // scaled by the current playback speed.
    final positionMicros = isPlaying
        ? position.inMicroseconds +
            _scaledLookAheadMicros(current.playbackSpeed)
        : position.inMicroseconds;
    final newIndex = _findNearestFrameIndex(current.frames, positionMicros);

    // Update painter directly for instant overlay sync (bypasses BLoC pipeline)
    if (newIndex != current.currentFrameIndex) {
      frameNotifier.value = current.frames[newIndex];

      // Process ALL intermediate frames so the rep counter never skips
      // state transitions when the position listener fires infrequently.
      final prevIndex = current.currentFrameIndex;
      if (newIndex > prevIndex) {
        _repCounter.processFrameRange(
          current.frames,
          prevIndex + 1,
          newIndex,
        );
      } else {
        // Jumped backward (rare during playback) — replay from start
        _repCounter.countRepsUpTo(current.frames, newIndex);
      }
    }

    // Only emit BLoC state when something actually changed (for UI controls)
    if (newIndex == current.currentFrameIndex &&
        isPlaying == current.isPlaying &&
        position == current.videoPosition) {
      return;
    }

    emit(current.copyWith(
      currentFrameIndex: newIndex,
      videoPosition: position,
      isPlaying: isPlaying,
      repCount: _repCounter.repCount,
      hipAngle: () => _repCounter.currentAngle,
      reps: _repCounter.reps,
    ));
  }

  /// Binary search for the frame closest to [positionMicros].
  ///
  /// Frames are sorted by timestampMicros (guaranteed by DB ORDER BY).
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

    // Check if lo-1 is closer than lo
    if (lo > 0) {
      final diffLo = (frames[lo].timestampMicros - positionMicros).abs();
      final diffPrev = (frames[lo - 1].timestampMicros - positionMicros).abs();
      if (diffPrev < diffLo) return lo - 1;
    }

    return lo;
  }

  /// Toggle play/pause.
  ///
  /// When playback has finished (position at the last frame), pressing
  /// play resets to the beginning so the video can be re-watched.
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
        _repCounter.reset();
        _repCounter.processFrame(current.frames.first, globalFrameIndex: 0);
        frameNotifier.value = current.frames.first;
        await controller.seekTo(Duration.zero);
        emit(current.copyWith(
          currentFrameIndex: 0,
          videoPosition: Duration.zero,
          repCount: _repCounter.repCount,
          hipAngle: () => _repCounter.currentAngle,
          reps: _repCounter.reps,
        ));
        await controller.play();
        return;
      }

      // Seek to the current frame's exact timestamp before playing,
      // so playback starts from what the user sees — not from wherever
      // the controller's internal position drifted to.
      final targetMicros =
          current.frames[current.currentFrameIndex].timestampMicros;
      await controller.seekTo(Duration(microseconds: targetMicros));
      await controller.play();
    }
  }

  /// Set the video playback speed.
  ///
  /// Applies the speed to [VideoPlayerController] immediately and updates
  /// state so the UI reflects the active speed. The lookahead compensation
  /// scales automatically via [_scaledLookAheadMicros].
  Future<void> setPlaybackSpeed(double speed) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    await _controller?.setPlaybackSpeed(speed);
    emit(current.copyWith(playbackSpeed: speed));
  }

  /// Seek to a specific frame by index.
  ///
  /// Recalculates rep count from frame 0 to handle arbitrary jumps.
  Future<void> seekToFrame(int index) async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    final clamped = index.clamp(0, current.totalFrames - 1);
    final timestampMicros = current.frames[clamped].timestampMicros;

    _repCounter.countRepsUpTo(current.frames, clamped);

    frameNotifier.value = current.frames[clamped];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(current.copyWith(
      currentFrameIndex: clamped,
      videoPosition: Duration(microseconds: timestampMicros),
      repCount: _repCounter.repCount,
      hipAngle: () => _repCounter.currentAngle,
      reps: _repCounter.reps,
    ));
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

    _repCounter.processFrame(
      current.frames[nextIndex],
      globalFrameIndex: nextIndex,
    );

    frameNotifier.value = current.frames[nextIndex];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(current.copyWith(
      currentFrameIndex: nextIndex,
      videoPosition: Duration(microseconds: timestampMicros),
      isPlaying: false,
      repCount: _repCounter.repCount,
      hipAngle: () => _repCounter.currentAngle,
      reps: _repCounter.reps,
    ));
  }

  /// Go back one frame (pauses if playing).
  ///
  /// Recalculates rep count from scratch since stepping backward
  /// can't be handled by the forward-only state machine.
  Future<void> previousFrame() async {
    final current = state;
    if (current is! SessionDetailsLoaded) return;

    if (current.currentFrameIndex <= 0) return;

    if (_controller?.value.isPlaying == true) {
      await _controller?.pause();
    }

    final prevIndex = current.currentFrameIndex - 1;
    final timestampMicros = current.frames[prevIndex].timestampMicros;

    _repCounter.countRepsUpTo(current.frames, prevIndex);

    frameNotifier.value = current.frames[prevIndex];
    await _controller?.seekTo(Duration(microseconds: timestampMicros));

    emit(current.copyWith(
      currentFrameIndex: prevIndex,
      videoPosition: Duration(microseconds: timestampMicros),
      isPlaying: false,
      repCount: _repCounter.repCount,
      hipAngle: () => _repCounter.currentAngle,
      reps: _repCounter.reps,
    ));
  }

  /// Select a landmark by ID, or clear selection with null.
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
