import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/utils/rdl_rep_counter.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/presentation/bloc/session_details_cubit.dart';
import 'package:pose_detection/presentation/bloc/session_details_state.dart';
import 'package:pose_detection/presentation/pages/session_analytics_page.dart';
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
            onAnalyticsTapped: () => _openAnalytics(state),
            onLandmarkTapped: (landmark) {
              _cubit.selectLandmark(landmark.id);
              showLandmarkDetailSheet(
                context: context,
                landmark: landmark,
                allLandmarks: state.currentFrame?.landmarks ?? [],
                frame: state.currentFrame,
                injuredLandmarkIds: state.injuredLandmarkIds,
                onLandmarkSelected: (id) => _cubit.selectLandmark(id),
                onInjuryToggled: (id) => _cubit.toggleLandmarkInjury(id),
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
    final frameIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionAnalyticsPage(
          session: state.session,
          reps: state.reps,
        ),
      ),
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
  final ValueChanged<LandmarkData> onLandmarkTapped;

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
                      injuredLandmarkIds: state.injuredLandmarkIds,
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
                      const Spacer(),
                      _OverlayBadge(
                        value: '${state.repCount} of ${state.reps.length}',
                        label: 'Reps',
                      ),
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

class _OverlayBadge extends StatelessWidget {
  final String value;
  final String label;

  const _OverlayBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
                  padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPadding + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rep pills (tap to seek to rep start)
                      if (state.reps.isNotEmpty)
                        _RepPillRow(cubit: cubit, state: state),
                      if (state.reps.isNotEmpty) const SizedBox(height: 16),
                      // Frame scrubber
                      _RepMarkerSlider(
                        cubit: cubit,
                        state: state,
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

class _RepMarkerSlider extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  const _RepMarkerSlider({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
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
        max: (state.totalFrames - 1).toDouble().clamp(0, double.infinity),
        onChanged: (value) => cubit.seekToFrame(value.round()),
      ),
    );
  }
}

/// Circular rep markers positioned at each rep's timestamp on the slider track.
/// Tap to seek to that rep's start frame.
class _RepPillRow extends StatelessWidget {
  final SessionDetailsCubit cubit;
  final SessionDetailsLoaded state;

  /// Must match the Slider's internal track offset:
  /// max(overlayRadius, thumbRadius) = max(0, 8) = 8.
  static const _trackPadding = 8.0;
  static const _markerDiameter = 22.0;

  const _RepPillRow({required this.cubit, required this.state});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) => _handleTap(details.localPosition, context),
      child: CustomPaint(
        painter: _RepCirclePainter(
          reps: state.reps,
          totalFrames: state.totalFrames,
        ),
        child: const SizedBox(height: _markerDiameter, width: double.infinity),
      ),
    );
  }

  void _handleTap(Offset tap, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final trackWidth = box.size.width - _trackPadding * 2;
    final maxFrames = (state.totalFrames - 1).clamp(1, state.totalFrames);

    for (final rep in state.reps) {
      final x = _trackPadding + (rep.startFrameIndex / maxFrames) * trackWidth;
      if ((tap.dx - x).abs() < _markerDiameter / 2 + 6) {
        HapticFeedback.selectionClick();
        cubit.seekToFrame(rep.startFrameIndex);
        return;
      }
    }
  }
}

class _RepCirclePainter extends CustomPainter {
  final List<RdlRepData> reps;
  final int totalFrames;

  static const _trackPadding = 8.0;
  static const _diameter = 22.0;

  _RepCirclePainter({required this.reps, required this.totalFrames});

  @override
  void paint(Canvas canvas, Size size) {
    if (reps.isEmpty || totalFrames <= 1) return;

    final trackWidth = size.width - _trackPadding * 2;
    final maxFrames = totalFrames - 1;
    final circlePaint = Paint()..color = const Color(0xFF2A2A2A);
    final cy = size.height / 2;

    for (final rep in reps) {
      final cx = _trackPadding + (rep.startFrameIndex / maxFrames) * trackWidth;

      canvas.drawCircle(Offset(cx, cy), _diameter / 2, circlePaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${rep.repNumber}',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RepCirclePainter old) =>
      old.reps.length != reps.length || old.totalFrames != totalFrames;
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
