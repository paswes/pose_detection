import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/widgets/landmark_detail_sheet.dart';
import 'package:pose_detection/presentation/widgets/landmark_overlay_painter.dart';

/// Page for viewing a recorded session with video playback
/// and synchronized landmark overlay.
class SessionDetailsPage extends StatefulWidget {
  final Session session;

  const SessionDetailsPage({super.key, required this.session});

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  late final SessionDetailsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<SessionDetailsCubit>(param1: widget.session);
    _cubit.initialize();
  }

  @override
  void dispose() {
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
          child: BlocBuilder<SessionDetailsCubit, SessionDetailsState>(
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
            onLandmarkTapped: (landmark) {
              _cubit.selectLandmark(landmark.id);
              showLandmarkDetailSheet(
                context: context,
                landmark: landmark,
                onDismissed: () => _cubit.selectLandmark(null),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        _FramePlaybackControls(cubit: _cubit, state: state),
      ],
    );
  }
}

/// Renders the video player with landmark overlay on top.
/// Detects taps on landmark points and reports the tapped landmark.
class _VideoWithOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;
  final ValueChanged<LandmarkData> onLandmarkTapped;

  const _VideoWithOverlay({
    required this.cubit,
    required this.state,
    required this.onLandmarkTapped,
  });

  @override
  Widget build(BuildContext context) {
    final controller = cubit.videoController;
    if (controller == null || !state.isVideoReady) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF888888)),
      );
    }

    final videoWidth = state.session.imageWidth;
    final videoHeight = state.session.imageHeight;

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
            return GestureDetector(
              onTapUp: (details) => _handleTap(
                details.localPosition,
                widgetSize,
              ),
              child: Stack(
                children: [
                  // Layer 1: Video player (BoxFit.cover)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: videoWidth,
                        height: videoHeight,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                  // Layer 2: Landmark overlay — driven by ValueNotifier
                  // for instant repaint (bypasses BLoC rebuild pipeline)
                  Positioned.fill(
                    child: CustomPaint(
                      size: widgetSize,
                      painter: LandmarkOverlayPainter(
                        frameNotifier: cubit.frameNotifier,
                        videoSize: Size(videoWidth, videoHeight),
                        rawImageWidth: state.session.imageWidth,
                        rawImageHeight: state.session.imageHeight,
                        isFrontCamera: state.session.isFrontCamera,
                        schema: LandmarkSchema.rdl,
                        visibleLandmarkIds: LandmarkSchema.rdlLandmarkIds,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hit-tests the tap position against painted landmark positions.
  ///
  /// Uses the same coordinate translation as [LandmarkOverlayPainter]
  /// to ensure tap targets match the visual positions exactly.
  void _handleTap(Offset tapPosition, Size widgetSize) {
    final frame = state.currentFrame;
    if (frame == null || !frame.isPersonDetected || frame.landmarks.isEmpty) {
      return;
    }

    final videoSize = Size(
      state.session.imageWidth,
      state.session.imageHeight,
    );

    // Same normalization and filtering as LandmarkOverlayPainter._drawLandmarks()
    final landmarks = <Landmark>[];
    for (final l in frame.landmarks) {
      if (!LandmarkSchema.rdlLandmarkIds.contains(l.id)) continue;

      var x = (l.x / state.session.imageWidth) * videoSize.width;
      final y = (l.y / state.session.imageHeight) * videoSize.height;
      if (state.session.isFrontCamera) {
        x = videoSize.width - x;
      }
      landmarks.add(Landmark(
        id: l.id,
        x: x,
        y: y,
        z: l.z,
        likelihood: l.likelihood,
      ));
    }

    final translatedPoints =
        CoordinateTranslator.translateAllLandmarksWithDepth(
      landmarks,
      videoSize,
      widgetSize,
    );

    // Find closest landmark within hit radius
    const hitRadius = 30.0;
    int? closestId;
    double closestDistance = hitRadius;

    for (final entry in translatedPoints.entries) {
      final distance = (entry.value.position - tapPosition).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestId = entry.key;
      }
    }

    if (closestId != null) {
      final tappedLandmark = frame.landmarks.firstWhere(
        (l) => l.id == closestId,
      );
      onLandmarkTapped(tappedLandmark);
    }
  }
}

/// Frame-by-frame navigation controls: slider, frame counter, prev/next/play.
class _FramePlaybackControls extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _FramePlaybackControls({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    final frameIndex = state.currentFrameIndex;
    final totalFrames = state.totalFrames;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frame scrubber
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF4CAF50),
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: const Color(0xFF4CAF50),
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: frameIndex.toDouble(),
              max: totalFrames > 1 ? (totalFrames - 1).toDouble() : 0,
              onChanged: (value) => cubit.seekToFrame(value.round()),
            ),
          ),
          // Frame counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Frame ${frameIndex + 1} / $totalFrames',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Speed selector
          _SpeedSelector(cubit: cubit, state: state),
          const SizedBox(height: 12),
          // Previous / Play-Pause / Next
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 32,
            children: [
              GestureDetector(
                onTap: cubit.previousFrame,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              GestureDetector(
                onTap: cubit.togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: state.isPlaying
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2A2A2A),
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
              GestureDetector(
                onTap: cubit.nextFrame,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row of pill buttons for selecting playback speed.
class _SpeedSelector extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _SpeedSelector({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        for (final speed in SessionDetailsCubit.availableSpeeds)
          _SpeedPill(
            speed: speed,
            isActive: state.playbackSpeed == speed,
            onTap: () => cubit.setPlaybackSpeed(speed),
          ),
      ],
    );
  }
}

class _SpeedPill extends StatelessWidget {
  final double speed;
  final bool isActive;
  final VoidCallback onTap;

  const _SpeedPill({
    required this.speed,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4CAF50)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _formatSpeed(speed),
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF888888),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble() && speed >= 1.0) {
      return '${speed.toInt()}x';
    }
    return '${speed}x';
  }
}
