import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';
import 'package:pose_detection/core/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/core/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/core/presentation/widgets/landmark_detail_sheet.dart';
import 'package:pose_detection/core/presentation/widgets/landmark_overlay_painter.dart';

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
        backgroundColor: Colors.black,
        body: BlocBuilder<SessionDetailsCubit, SessionDetailsState>(
          builder: (context, state) => switch (state) {
            SessionDetailsLoading() => _buildLoading(),
            SessionDetailsLoaded() => _buildLoaded(state),
            SessionDetailsError() => _buildError(state),
          },
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
    final analyticsPage = _cubit.analyzer?.buildAnalyticsPage(state.session);

    return Stack(
      children: [
        Positioned.fill(
          child: _VideoWithOverlay(
            cubit: _cubit,
            state: state,
            onBack: () => Navigator.pop(context),
            onAnalyticsTapped: analyticsPage != null
                ? () => _openAnalytics(state)
                : null,
            onLandmarkTapped: (landmark) {
              _cubit.selectLandmark(landmark.id);
              showLandmarkDetailSheet(
                context: context,
                landmark: landmark,
                allLandmarks: state.currentFrame?.landmarks ?? [],
                frame: state.currentFrame,
                analyzer: _cubit.analyzer,
                onLandmarkSelected: (id) => _cubit.selectLandmark(id),
                onDismissed: () => _cubit.selectLandmark(null),
              );
            },
          ),
        ),
        _ControlsSheet(cubit: _cubit, state: state),
      ],
    );
  }

  Future<void> _openAnalytics(SessionDetailsLoaded state) async {
    final page = _cubit.analyzer!.buildAnalyticsPage(state.session)!;
    final frameIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (frameIndex != null && mounted) {
      _cubit.seekToFrame(frameIndex);
    }
  }
}

// =============================================================================
// Video with overlay + HUD elements
// =============================================================================

class _VideoWithOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;
  final VoidCallback onBack;
  final VoidCallback? onAnalyticsTapped;
  final ValueChanged<Landmark> onLandmarkTapped;

  const _VideoWithOverlay({
    required this.cubit,
    required this.state,
    required this.onBack,
    this.onAnalyticsTapped,
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
    final topPadding = MediaQuery.of(context).padding.top;
    final analyzer = cubit.analyzer;

    return Container(
      color: Colors.black,
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
                // Layer 1: Video
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: videoWidth,
                      height: videoHeight,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                // Layer 2: Landmark overlay
                Positioned.fill(
                  child: CustomPaint(
                    size: widgetSize,
                    painter: LandmarkOverlayPainter(
                      frameNotifier: cubit.frameNotifier,
                      videoSize: Size(videoWidth, videoHeight),
                      rawImageWidth: state.session.imageWidth,
                      rawImageHeight: state.session.imageHeight,
                      isFrontCamera: state.session.isFrontCamera,
                      fitMode: FitMode.contain,
                      alignY: 0.0,
                      schema: analyzer?.schema,
                      visibleLandmarkIds: analyzer?.visibleLandmarkIds,
                      selectedLandmarkId: state.selectedLandmarkId,
                    ),
                  ),
                ),
                // Layer 3: Top HUD
                Positioned(
                  top: topPadding + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _OverlayButton(
                        onTap: onBack,
                        icon: Icons.chevron_left_rounded,
                        size: 28,
                      ),
                      const Spacer(),
                      if (analyzer != null)
                        analyzer.buildHud(
                              context,
                              state.currentFrameIndex,
                            ) ??
                            const SizedBox.shrink(),
                      const Spacer(),
                      if (onAnalyticsTapped != null)
                        _OverlayButton(
                          onTap: onAnalyticsTapped!,
                          icon: Icons.bar_chart_rounded,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset tapPosition, Size widgetSize) {
    final frame = state.currentFrame;
    if (frame == null || !frame.isPersonDetected || frame.landmarks.isEmpty) {
      return;
    }

    final videoSize = Size(
      state.session.imageWidth,
      state.session.imageHeight,
    );

    final visibleIds = cubit.analyzer?.visibleLandmarkIds;
    final landmarks = <Landmark>[];
    for (final l in frame.landmarks) {
      if (visibleIds != null && !visibleIds.contains(l.id)) continue;

      var x = (l.x / state.session.imageWidth) * videoSize.width;
      final y = (l.y / state.session.imageHeight) * videoSize.height;
      if (state.session.isFrontCamera) {
        x = videoSize.width - x;
      }
      landmarks.add(
        Landmark(
          id: l.id,
          x: x,
          y: y,
          z: l.z,
          likelihood: l.likelihood,
        ),
      );
    }

    final translatedPoints =
        CoordinateTranslator.translateAllLandmarksWithDepth(
          landmarks,
          videoSize,
          widgetSize,
          fitMode: FitMode.contain,
          alignY: 0.0,
        );

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

// =============================================================================
// Overlay HUD widgets
// =============================================================================

class _OverlayButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final double size;

  const _OverlayButton({
    required this.onTap,
    required this.icon,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

// =============================================================================
// Draggable controls sheet
// =============================================================================

class _ControlsSheet extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  static const double _initialChildSize = 0.34;
  static const double _maxChildSize = 0.7;

  const _ControlsSheet({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final sliderExtras = cubit.analyzer?.buildSliderExtras(
      context,
      totalFrames: state.totalFrames,
      currentFrameIndex: state.currentFrameIndex,
      onSeekToFrame: cubit.seekToFrame,
    );

    return DraggableScrollableSheet(
      initialChildSize: _initialChildSize,
      minChildSize: _initialChildSize,
      maxChildSize: _maxChildSize,
      snap: true,
      snapSizes: const [_initialChildSize, _maxChildSize],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sliderExtras != null) ...[
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: sliderExtras,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _FrameScrubber(cubit: cubit, state: state),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 32,
                        children: [
                          _ControlButton(
                            onTap: cubit.previousFrame,
                            icon: Icons.chevron_left_rounded,
                          ),
                          _ControlButton(
                            onTap: cubit.togglePlayPause,
                            icon: state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            isActive: state.isPlaying,
                          ),
                          _ControlButton(
                            onTap: cubit.nextFrame,
                            icon: Icons.chevron_right_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        spacing: 8,
                        children: [
                          for (final speed
                              in SessionDetailsCubit.availableSpeeds)
                            Expanded(
                              child: _SpeedPill(
                                speed: speed,
                                isActive: state.playbackSpeed == speed,
                                onTap: () => cubit.setPlaybackSpeed(speed),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FrameScrubber extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _FrameScrubber({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: const Color(0xFF4CAF50),
        inactiveTrackColor: const Color(0xFF333333),
        thumbColor: const Color(0xFF4CAF50),
        overlayShape: SliderComponentShape.noOverlay,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        value: state.currentFrameIndex.toDouble(),
        max: (state.totalFrames - 1).toDouble().clamp(0, double.infinity),
        onChanged: (value) => cubit.scrubToFrame(value.round()),
        onChangeEnd: (_) => cubit.commitScrub(),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool isActive;

  const _ControlButton({
    required this.onTap,
    required this.icon,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF2A2A2A),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          _formatSpeed(speed),
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF888888),
            fontSize: 14,
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
