import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Stack(
      children: [
        Positioned.fill(
          child: _VideoWithOverlay(
            cubit: _cubit,
            state: state,
            onBack: () => Navigator.pop(context),
            onLandmarkTapped: (landmark) {
              _cubit.selectLandmark(landmark.id);
              showLandmarkDetailSheet(
                context: context,
                landmark: landmark,
                allLandmarks: state.currentFrame?.landmarks ?? [],
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
}

// =============================================================================
// Video with overlay + HUD elements
// =============================================================================

class _VideoWithOverlay extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;
  final VoidCallback onBack;
  final ValueChanged<LandmarkData> onLandmarkTapped;

  const _VideoWithOverlay({
    required this.cubit,
    required this.state,
    required this.onBack,
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
                // Layer 1: Video (BoxFit.contain — full frame, no crop)
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
                // Layer 2: Landmark overlay (contain to match video)
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
                      schema: LandmarkSchema.rdl,
                      visibleLandmarkIds: LandmarkSchema.rdlLandmarkIds,
                      selectedLandmarkId: state.selectedLandmarkId,
                    ),
                  ),
                ),
                // Layer 3: Top HUD (safe area aware)
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
                      const SizedBox(width: 8),
                      _FrameInfo(
                        frameIndex: state.currentFrameIndex,
                        totalFrames: state.totalFrames,
                      ),
                      const SizedBox(width: 8),
                      _RepBadge(
                        repCount: state.repCount,
                        hipAngle: state.hipAngle,
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

    final landmarks = <Landmark>[];
    for (final l in frame.landmarks) {
      if (!LandmarkSchema.rdlLandmarkIds.contains(l.id)) continue;

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

class _RepBadge extends StatelessWidget {
  final int repCount;
  final double? hipAngle;

  const _RepBadge({required this.repCount, this.hipAngle});

  static const _valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const _labelStyle = TextStyle(
    color: Color(0xFF999999),
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    final angleText = hipAngle != null
        ? '${hipAngle!.toStringAsFixed(0)}°'
        : '–';

    return Container(
      width: 140,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          Text('$repCount', style: _valueStyle),
          Text('Reps', style: _labelStyle),
          Container(width: 1, height: 16, color: const Color(0xFF555555)),
          Text(angleText, style: _valueStyle),
        ],
      ),
    );
  }
}

class _FrameInfo extends StatelessWidget {
  final int frameIndex;
  final int totalFrames;

  const _FrameInfo({required this.frameIndex, required this.totalFrames});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          'Frame ${frameIndex + 1} / $totalFrames',
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
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

  static const double _initialChildSize = 0.3;
  static const double _maxChildSize = 0.7;

  const _ControlsSheet({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: _DragHandle(),
                      ),
                      // Frame scrubber
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFF4CAF50),
                          inactiveTrackColor: const Color(0xFF333333),
                          thumbColor: const Color(0xFF4CAF50),
                          overlayShape: SliderComponentShape.noOverlay,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: state.currentFrameIndex.toDouble(),
                          max: state.totalFrames > 1
                              ? (state.totalFrames - 1).toDouble()
                              : 0,
                          onChanged: (value) =>
                              cubit.seekToFrame(value.round()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Previous / Play-Pause / Next
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

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF555555),
        borderRadius: BorderRadius.circular(2),
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
