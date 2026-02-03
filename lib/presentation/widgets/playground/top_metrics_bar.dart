import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Top bar displaying performance metrics.
///
/// Shows:
/// - FPS with color coding
/// - Latency with color coding
/// - Detection confidence
/// - Pose count
/// - Dropped frames
/// - Body state (stationary/moving)
class TopMetricsBar extends StatelessWidget {
  const TopMetricsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.metrics != curr.metrics ||
          prev.isDetecting != curr.isDetecting ||
          prev.currentPose != curr.currentPose,
      builder: (context, state) {
        if (!state.isDetecting) {
          return const SizedBox.shrink();
        }

        final metrics = state.metrics;
        final avgConfidence = state.currentPose?.avgConfidence ?? 0;

        return Container(
          decoration: PlaygroundTheme.metricsBarDecoration,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PlaygroundTheme.spacingMd,
                vertical: PlaygroundTheme.spacingSm,
              ),
              child: Row(
                children: [
                  // FPS
                  _MetricChip(
                    label: 'FPS',
                    value: metrics.detection.fps.toStringAsFixed(0),
                    color: PlaygroundTheme.fpsColor(metrics.detection.fps),
                  ),

                  const SizedBox(width: PlaygroundTheme.spacingSm),

                  // Latency
                  _MetricChip(
                    label: 'LAT',
                    value: '${metrics.detection.latencyMs.toStringAsFixed(0)}ms',
                    color: PlaygroundTheme.latencyColor(metrics.detection.latencyMs),
                  ),

                  const SizedBox(width: PlaygroundTheme.spacingSm),

                  // Confidence
                  _MetricChip(
                    label: 'CONF',
                    value: '${(avgConfidence * 100).toStringAsFixed(0)}%',
                    color: PlaygroundTheme.confidenceColor(avgConfidence),
                  ),

                  const Spacer(),

                  // Pose count
                  _MetricChip(
                    label: 'POSES',
                    value: _formatCount(metrics.poseCount),
                    color: PlaygroundTheme.textSecondary,
                    compact: true,
                  ),

                  const SizedBox(width: PlaygroundTheme.spacingSm),

                  // Dropped frames
                  if (metrics.droppedFrames > 0)
                    _MetricChip(
                      label: 'DROP',
                      value: _formatCount(metrics.droppedFrames),
                      color: PlaygroundTheme.warningOrange,
                      compact: true,
                    ),

                  // Body state indicator
                  const SizedBox(width: PlaygroundTheme.spacingSm),
                  _BodyStateIndicator(isStationary: metrics.isStationary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: PlaygroundTheme.surfaceLight,
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w500,
              color: PlaygroundTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyStateIndicator extends StatelessWidget {
  final bool isStationary;

  const _BodyStateIndicator({required this.isStationary});

  @override
  Widget build(BuildContext context) {
    final color = isStationary ? PlaygroundTheme.textMuted : PlaygroundTheme.success;
    final icon = isStationary ? Icons.accessibility_new : Icons.directions_run;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }
}

/// Compact metrics display for when panels are open
class CompactMetricsRow extends StatelessWidget {
  final double fps;
  final double latencyMs;
  final double confidence;

  const CompactMetricsRow({
    super.key,
    required this.fps,
    required this.latencyMs,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CompactMetric(
          value: fps.toStringAsFixed(0),
          unit: 'fps',
          color: PlaygroundTheme.fpsColor(fps),
        ),
        _CompactMetric(
          value: latencyMs.toStringAsFixed(0),
          unit: 'ms',
          color: PlaygroundTheme.latencyColor(latencyMs),
        ),
        _CompactMetric(
          value: (confidence * 100).toStringAsFixed(0),
          unit: '%',
          color: PlaygroundTheme.confidenceColor(confidence),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;

  const _CompactMetric({
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 8,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
