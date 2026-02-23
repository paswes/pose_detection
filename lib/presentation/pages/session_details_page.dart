import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/widgets/frame_image_painter.dart';

/// Page for viewing a recorded session with frame-based playback
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
                SessionDetailsDecoding() => _buildDecoding(state),
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

  Widget _buildDecoding(SessionDetailsDecoding state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              color: const Color(0xFF4CAF50),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            state.total > 0
                ? 'Frames dekodieren: ${state.completed} / ${state.total}'
                : 'Frames werden vorbereitet...',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
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
          child: _FrameWithOverlay(
            state: state,
          ),
        ),
        const SizedBox(height: 24),
        _FramePlaybackControls(cubit: _cubit, state: state),
      ],
    );
  }
}

/// Renders the current frame image with landmarks in a single paint pass.
class _FrameWithOverlay extends StatelessWidget {
  final SessionDetailsLoaded state;

  const _FrameWithOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final image = state.currentImage;
    if (image == null) {
      return const Center(
        child: Text(
          'Kein Frame verfügbar',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      );
    }

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
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: FrameImagePainter(
                frameImage: image,
                trackedFrame: state.currentFrame,
                rawImageWidth: state.session.imageWidth,
                rawImageHeight: state.session.imageHeight,
                isFrontCamera: state.session.isFrontCamera,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Playback controls: slider, frame counter, prev/play/next buttons.
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
              onChanged: (value) => cubit.goToFrame(value.round()),
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
          const SizedBox(height: 12),
          // Prev / Play-Pause / Next
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 24,
            children: [
              // Previous
              GestureDetector(
                onTap: cubit.previousFrame,
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
                onTap: cubit.toggleAutoPlay,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.isAutoPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              // Next
              GestureDetector(
                onTap: cubit.nextFrame,
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
}
