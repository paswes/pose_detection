import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/services/playback_sync_engine.dart';
import 'package:pose_detection/core/utils/transform_calculator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/widgets/landmark_detail_card.dart';
import 'package:pose_detection/presentation/widgets/playback_overlay_painter.dart';

/// Page for viewing a recorded session with video playback
/// and synchronized landmark overlay.
class SessionDetailsPage extends StatefulWidget {
  final Session session;

  const SessionDetailsPage({super.key, required this.session});

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage>
    with TickerProviderStateMixin {
  late final SessionDetailsCubit _cubit;
  late final Ticker _overlayTicker;
  final _tickerNotifier = _TickerNotifier();

  @override
  void initState() {
    super.initState();
    _cubit = sl<SessionDetailsCubit>(param1: widget.session);
    _cubit.initialize();

    _overlayTicker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    _tickerNotifier.notify();
  }

  void _startTickerIfNeeded(bool isPlaying) {
    if (isPlaying && !_overlayTicker.isActive) {
      _overlayTicker.start();
    } else if (!isPlaying && _overlayTicker.isActive) {
      _overlayTicker.stop();
      // One final repaint to show the paused state
      _tickerNotifier.notify();
    }
  }

  @override
  void dispose() {
    _overlayTicker.dispose();
    _tickerNotifier.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.session.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<SessionDetailsCubit, SessionDetailsState>(
            listener: (context, state) {
              if (state is SessionDetailsLoaded) {
                _startTickerIfNeeded(state.isPlaying);
              }
            },
            builder: (context, state) {
              return switch (state) {
                SessionDetailsLoading() => _buildLoading(),
                SessionDetailsLoaded() => _buildLoaded(state),
                SessionDetailsError() => _buildError(state),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Laden...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(SessionDetailsError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFFF5252),
          ),
          const SizedBox(height: 16),
          Text(
            state.message,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded(SessionDetailsLoaded state) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: _VideoWithOverlay(
            cubit: _cubit,
            state: state,
            tickerNotifier: _tickerNotifier,
          ),
        ),
        const SizedBox(height: 24),
        _PlaybackControls(cubit: _cubit, state: state),
      ],
    );
  }
}

/// Custom [ChangeNotifier] driven by the ticker to trigger repaints.
class _TickerNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Video player with ticker-driven landmark overlay stack.
class _VideoWithOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;
  final _TickerNotifier tickerNotifier;

  const _VideoWithOverlay({
    required this.cubit,
    required this.state,
    required this.tickerNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final controller = cubit.videoController;
    final syncEngine = cubit.syncEngine;
    if (controller == null || !controller.value.isInitialized || syncEngine == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final videoSize = controller.value.size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widgetSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            // Determine forced frame index for frame-stepping mode
            final forcedIndex = state.playbackMode == PlaybackMode.frameStepping
                ? state.currentFrameIndex
                : null;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Video layer
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                // Landmark overlay — ticker-driven CustomPainter
                RepaintBoundary(
                  child: _buildOverlay(
                    controller,
                    syncEngine,
                    videoSize,
                    widgetSize,
                    forcedIndex,
                  ),
                ),
                // Landmark tap detection
                _LandmarkTapDetector(
                  cubit: cubit,
                  syncEngine: syncEngine,
                  videoSize: videoSize,
                  widgetSize: widgetSize,
                  session: state.session,
                ),
                // Landmark detail card overlay
                if (state.selectedLandmarkId != null)
                  _LandmarkDetailOverlay(
                    cubit: cubit,
                    state: state,
                    syncEngine: syncEngine,
                    videoSize: videoSize,
                    widgetSize: widgetSize,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverlay(
    VideoPlayerController controller,
    PlaybackSyncEngine syncEngine,
    ui.Size videoSize,
    Size widgetSize,
    int? forcedIndex,
  ) {
    Widget overlay = CustomPaint(
      size: widgetSize,
      painter: PlaybackOverlayPainter(
        controller: controller,
        syncEngine: syncEngine,
        videoSize: videoSize,
        session: state.session,
        repaint: tickerNotifier,
        forcedFrameIndex: forcedIndex,
      ),
    );

    if (state.session.isFrontCamera) {
      overlay = Transform.flip(flipX: true, child: overlay);
    }

    return overlay;
  }
}

/// Transparent gesture detector for landmark tap hit-testing.
class _LandmarkTapDetector extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final PlaybackSyncEngine syncEngine;
  final ui.Size videoSize;
  final Size widgetSize;
  final Session session;

  const _LandmarkTapDetector({
    required this.cubit,
    required this.syncEngine,
    required this.videoSize,
    required this.widgetSize,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _onTap(details.localPosition),
      child: const SizedBox.expand(),
    );
  }

  void _onTap(Offset tapPosition) {
    final currentState = cubit.state;
    if (currentState is! SessionDetailsLoaded) return;

    // Get the currently displayed frame
    TrackedFrame? frame;
    if (currentState.playbackMode == PlaybackMode.frameStepping) {
      frame = syncEngine.getFrameByIndex(currentState.currentFrameIndex);
    } else {
      final controller = cubit.videoController;
      if (controller == null) return;
      final result = syncEngine.findFramePair(controller.value.position);
      if (result == null) return;
      frame = result.frameA;
    }

    if (frame == null || !frame.isPersonDetected) return;

    // Transform landmarks to widget space and find nearest
    final rawW = session.imageWidth;
    final rawH = session.imageHeight;
    if (rawW <= 0 || rawH <= 0) return;

    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: videoSize,
      screenSize: widgetSize,
    );

    // Account for front camera mirror flip
    final effectiveTapX = session.isFrontCamera
        ? widgetSize.width - tapPosition.dx
        : tapPosition.dx;
    final effectiveTap = Offset(effectiveTapX, tapPosition.dy);

    const hitRadius = 30.0;
    double closestDistance = hitRadius;
    int? closestId;

    for (final l in frame.landmarks) {
      final vx = (l.x / rawW) * videoSize.width;
      final vy = (l.y / rawH) * videoSize.height;
      final wx = vx * transform.scale + transform.offset.dx;
      final wy = vy * transform.scale + transform.offset.dy;

      final dist = (effectiveTap - Offset(wx, wy)).distance;
      if (dist < closestDistance) {
        closestDistance = dist;
        closestId = l.id;
      }
    }

    cubit.selectLandmark(closestId);
  }
}

/// Positioned overlay for the landmark detail card.
class _LandmarkDetailOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;
  final PlaybackSyncEngine syncEngine;
  final ui.Size videoSize;
  final Size widgetSize;

  const _LandmarkDetailOverlay({
    required this.cubit,
    required this.state,
    required this.syncEngine,
    required this.videoSize,
    required this.widgetSize,
  });

  @override
  Widget build(BuildContext context) {
    final landmarkId = state.selectedLandmarkId;
    if (landmarkId == null) return const SizedBox.shrink();

    // Get current frame
    TrackedFrame? frame;
    if (state.playbackMode == PlaybackMode.frameStepping) {
      frame = syncEngine.getFrameByIndex(state.currentFrameIndex);
    } else {
      final controller = cubit.videoController;
      if (controller == null) return const SizedBox.shrink();
      final result = syncEngine.findFramePair(controller.value.position);
      frame = result?.frameA;
    }

    if (frame == null || !frame.isPersonDetected) return const SizedBox.shrink();

    // Find the selected landmark
    LandmarkData? landmark;
    for (final l in frame.landmarks) {
      if (l.id == landmarkId) {
        landmark = l;
        break;
      }
    }
    if (landmark == null) return const SizedBox.shrink();

    // Position the card near the landmark
    final rawW = state.session.imageWidth;
    final rawH = state.session.imageHeight;
    if (rawW <= 0 || rawH <= 0) return const SizedBox.shrink();

    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: videoSize,
      screenSize: widgetSize,
    );

    var wx = (landmark.x / rawW) * videoSize.width * transform.scale + transform.offset.dx;
    final wy = (landmark.y / rawH) * videoSize.height * transform.scale + transform.offset.dy;

    // Mirror for front camera
    if (state.session.isFrontCamera) {
      wx = widgetSize.width - wx;
    }

    // Offset card to the right of the landmark, clamped to widget bounds
    final cardX = (wx + 20).clamp(8.0, widgetSize.width - 228.0);
    final cardY = (wy - 40).clamp(8.0, widgetSize.height - 200.0);

    return Positioned(
      left: cardX,
      top: cardY,
      child: LandmarkDetailCard(
        landmark: landmark,
        session: state.session,
        frameIndex: state.currentFrameIndex,
        timestampMicros: frame.timestampMicros,
        onDismiss: () => cubit.selectLandmark(null),
      ),
    );
  }
}

/// Playback controls: slider, timestamps, play/pause, frame step.
class _PlaybackControls extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _PlaybackControls({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    final positionMs = state.position.inMilliseconds.toDouble();
    final durationMs = state.duration.inMilliseconds.toDouble();
    final sliderValue = durationMs > 0
        ? positionMs.clamp(0.0, durationMs)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Interactive progress bar
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF4CAF50),
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: const Color(0xFF4CAF50),
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: sliderValue,
              max: durationMs > 0 ? durationMs : 1.0,
              onChanged: (value) {
                cubit.seekToPosition(
                  Duration(milliseconds: value.round()),
                );
              },
            ),
          ),
          // Timestamps + frame counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                  ),
                ),
                if (state.totalFrames > 0)
                  Text(
                    'Frame ${state.currentFrameIndex + 1} / ${state.totalFrames}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Transport controls: step back, play/pause, step forward
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: [
              // Step backward
              GestureDetector(
                onTap: cubit.stepBackward,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              // Play / Pause
              GestureDetector(
                onTap: cubit.togglePlayback,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              // Step forward
              GestureDetector(
                onTap: cubit.stepForward,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }
}
