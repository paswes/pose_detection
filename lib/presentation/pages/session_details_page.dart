import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/widgets/pose_painter.dart';

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
        _SessionMetadata(
          session: state.session,
          frameCount: state.frames.length,
        ),
        Expanded(
          child: _VideoWithOverlay(
            cubit: _cubit,
            state: state,
          ),
        ),
        SizedBox(height: 24),
        _PlaybackControls(cubit: _cubit, state: state),
      ],
    );
  }
}

/// Displays session metadata in a compact card.
class _SessionMetadata extends StatelessWidget {
  final Session session;
  final int frameCount;

  const _SessionMetadata({required this.session, required this.frameCount});

  @override
  Widget build(BuildContext context) {
    final duration = session.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final dateStr =
        '${session.createdAt.day.toString().padLeft(2, '0')}.${session.createdAt.month.toString().padLeft(2, '0')}.${session.createdAt.year}';
    final timeStr =
        '${session.createdAt.hour.toString().padLeft(2, '0')}:${session.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$dateStr $timeStr',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            '${minutes}m ${seconds}s',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            '$frameCount Frames',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${session.isFrontCamera ? 'Front' : 'Back'} • ${session.isLandscape ? 'Landscape' : 'Portrait'}',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Video player with landmark overlay stack.
class _VideoWithOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _VideoWithOverlay({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    final controller = cubit.videoController;
    if (controller == null || !controller.value.isInitialized) {
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
                // Landmark overlay
                if (state.currentFrame != null &&
                    state.currentFrame!.isPersonDetected)
                  CustomPaint(
                    size: widgetSize,
                    painter: PosePainter(
                      pose: _buildDetectedPose(
                        state.currentFrame!,
                        videoSize,
                      ),
                      imageSize: videoSize,
                      widgetSize: widgetSize,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  DetectedPose _buildDetectedPose(TrackedFrame frame, ui.Size videoSize) {
    return DetectedPose(
      landmarks: frame.landmarks.map((l) => l.toLandmark()).toList(),
      imageSize: videoSize,
      timestampMicros: frame.timestampMicros,
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
          // Progress bar (read-only)
          IgnorePointer(
            child: SliderTheme(
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
                onChanged: (_) {},
              ),
            ),
          ),
          // Timestamps
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
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
