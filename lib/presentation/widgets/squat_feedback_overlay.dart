import 'package:flutter/material.dart';
import 'package:pose_detection/domain/analyzers/squat_phase.dart';
import 'package:pose_detection/domain/models/squat_metrics.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';
import 'package:pose_detection/presentation/widgets/depth_indicator.dart';
import 'package:pose_detection/presentation/widgets/form_score_gauge.dart';
import 'package:pose_detection/presentation/widgets/rep_counter_widget.dart';

/// Overlay widget showing real-time squat feedback
///
/// Displays:
/// - Rep counter (top left)
/// - Form score gauge (bottom left)
/// - Depth indicator (right side)
/// - Phase indicator (bottom center)
/// - Knee tracking feedback (bottom bar)
class SquatFeedbackOverlay extends StatelessWidget {
  /// Current squat metrics
  final SquatMetrics metrics;

  /// Last completed rep (for animations)
  final SquatRep? lastCompletedRep;

  /// Session duration
  final Duration sessionDuration;

  const SquatFeedbackOverlay({
    super.key,
    required this.metrics,
    this.lastCompletedRep,
    required this.sessionDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top stats bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),

        // Rep counter (top left, below top bar)
        Positioned(
          top: 80,
          left: 16,
          child: RepCounterWidget(
            repCount: metrics.totalReps,
            lastCompletedRep: lastCompletedRep,
            size: 70,
          ),
        ),

        // Form score gauge (bottom left)
        Positioned(
          bottom: 140,
          left: 16,
          child: FormScoreGauge(
            score: metrics.currentFormScore,
            size: 70,
          ),
        ),

        // Depth indicator (right side)
        Positioned(
          top: 120,
          right: 16,
          child: DepthIndicator(
            currentKneeAngle: metrics.currentKneeAngle,
            height: 180,
            width: 28,
          ),
        ),

        // Bottom feedback bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomFeedbackBar(),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Timer
            _buildStatChip(
              icon: Icons.timer_outlined,
              label: _formatDuration(sessionDuration),
              color: Colors.white,
            ),

            // Average form score
            if (metrics.totalReps > 0)
              _buildStatChip(
                icon: Icons.trending_up,
                label: '${(metrics.averageFormScore * 100).round()}%',
                sublabel: 'Avg',
                color: _getFormColor(metrics.averageFormScore),
              ),

            // Landmark confidence
            if (metrics.landmarkConfidence != null)
              _buildStatChip(
                icon: Icons.visibility,
                label: '${(metrics.landmarkConfidence! * 100).round()}%',
                sublabel: 'Track',
                color: _getConfidenceColor(metrics.landmarkConfidence!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomFeedbackBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Phase indicator
            _buildPhaseIndicator(),
            const SizedBox(height: 12),

            // Feedback chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeedbackChip(
                  label: metrics.kneeTrackingFeedback,
                  icon: _getKneeIcon(),
                  color: _getKneeTrackingColor(),
                ),
                const SizedBox(width: 12),
                _buildFeedbackChip(
                  label: metrics.depthDescription,
                  icon: Icons.height,
                  color: _getDepthColor(),
                ),
                if (metrics.isInRep) ...[
                  const SizedBox(width: 12),
                  _buildFeedbackChip(
                    label: _formatDuration(metrics.currentRepDuration ?? Duration.zero),
                    icon: Icons.timer,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    final phase = metrics.currentPhase;
    final color = _getPhaseColor(phase);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPhaseIcon(phase),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            phase.displayName.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    String? sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _getPhaseColor(SquatPhase phase) {
    switch (phase) {
      case SquatPhase.standing:
        return Colors.white70;
      case SquatPhase.descending:
        return Colors.orangeAccent;
      case SquatPhase.bottom:
        return Colors.greenAccent;
      case SquatPhase.ascending:
        return Colors.cyanAccent;
    }
  }

  IconData _getPhaseIcon(SquatPhase phase) {
    switch (phase) {
      case SquatPhase.standing:
        return Icons.accessibility_new;
      case SquatPhase.descending:
        return Icons.arrow_downward;
      case SquatPhase.bottom:
        return Icons.pause_circle_outline;
      case SquatPhase.ascending:
        return Icons.arrow_upward;
    }
  }

  IconData _getKneeIcon() {
    if (metrics.kneeTrackingStatus < -2) return Icons.warning;
    if (metrics.kneeTrackingStatus > 2) return Icons.warning;
    return Icons.check_circle_outline;
  }

  Color _getKneeTrackingColor() {
    final status = metrics.kneeTrackingStatus.abs();
    if (status < 2) return Colors.greenAccent;
    if (status < 5) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  Color _getDepthColor() {
    if (metrics.currentKneeAngle <= 90) return Colors.greenAccent;
    if (metrics.currentKneeAngle <= 110) return Colors.yellowAccent;
    if (metrics.currentKneeAngle <= 130) return Colors.orangeAccent;
    return Colors.white70;
  }

  Color _getFormColor(double score) {
    if (score >= 0.8) return Colors.greenAccent;
    if (score >= 0.6) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.greenAccent;
    if (confidence >= 0.5) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}
