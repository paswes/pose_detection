import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/widgets/frame_image_painter.dart';
import 'package:pose_detection/presentation/widgets/landmark_detail_sheet.dart';

/// Page for viewing a recorded session with frame-by-frame navigation
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

/// Renders the current frame image with landmarks in a single paint pass.
/// Detects taps on landmark points and reports the tapped landmark.
class _FrameWithOverlay extends StatelessWidget {
  final SessionDetailsLoaded state;
  final ValueChanged<LandmarkData> onLandmarkTapped;

  const _FrameWithOverlay({
    required this.state,
    required this.onLandmarkTapped,
  });

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
            final widgetSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return GestureDetector(
              onTapUp: (details) => _handleTap(
                details.localPosition,
                widgetSize,
              ),
              child: CustomPaint(
                size: widgetSize,
                painter: FrameImagePainter(
                  frameImage: image,
                  trackedFrame: state.currentFrame,
                  rawImageWidth: state.session.imageWidth,
                  rawImageHeight: state.session.imageHeight,
                  isFrontCamera: state.session.isFrontCamera,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hit-tests the tap position against painted landmark positions.
  ///
  /// Uses the same coordinate translation as [FrameImagePainter._drawLandmarks]
  /// to ensure tap targets match the visual positions exactly.
  void _handleTap(Offset tapPosition, Size widgetSize) {
    final frame = state.currentFrame;
    if (frame == null || !frame.isPersonDetected || frame.landmarks.isEmpty) {
      return;
    }

    final image = state.currentImage!;
    final videoSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // Same normalization as FrameImagePainter._drawLandmarks()
    final landmarks = frame.landmarks.map((l) {
      var x = (l.x / state.session.imageWidth) * videoSize.width;
      final y = (l.y / state.session.imageHeight) * videoSize.height;
      if (state.session.isFrontCamera) {
        x = videoSize.width - x;
      }
      return Landmark(
        id: l.id,
        x: x,
        y: y,
        z: l.z,
        likelihood: l.likelihood,
      );
    }).toList();

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

/// Frame-by-frame navigation controls: slider, frame counter, prev/next.
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
          // Previous / Next
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
