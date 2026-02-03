import 'package:flutter/material.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/range_of_motion.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Widget for displaying Range of Motion data with progress bar.
class RomProgressBar extends StatelessWidget {
  final String label;
  final RangeOfMotion? rom;
  final JointAngle? currentAngle;

  const RomProgressBar({
    super.key,
    required this.label,
    this.rom,
    this.currentAngle,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = rom != null && rom!.hasMeaningfulData;
    final category = rom?.category ?? RangeOfMotionCategory.minimal;
    final color = _categoryColor(category);

    return Container(
      padding: const EdgeInsets.all(PlaygroundTheme.spacingSm),
      decoration: PlaygroundTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PlaygroundTheme.labelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _CategoryBadge(category: category),
            ],
          ),

          const SizedBox(height: PlaygroundTheme.spacingSm),

          // Min/Max labels
          if (hasData)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min: ${rom!.minDegrees.toInt()}°',
                  style: PlaygroundTheme.labelStyle.copyWith(fontSize: 9),
                ),
                Text(
                  'Max: ${rom!.maxDegrees.toInt()}°',
                  style: PlaygroundTheme.labelStyle.copyWith(fontSize: 9),
                ),
              ],
            ),

          const SizedBox(height: PlaygroundTheme.spacingXs),

          // Progress bar with markers
          _RomBar(
            rom: rom,
            currentAngle: currentAngle,
            color: color,
          ),

          const SizedBox(height: PlaygroundTheme.spacingSm),

          // Range value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasData
                    ? 'Range: ${rom!.rangeDegrees.toInt()}°'
                    : 'No data',
                style: PlaygroundTheme.valueSmallStyle.copyWith(
                  color: hasData ? color : PlaygroundTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              if (hasData)
                Text(
                  '${rom!.sampleCount} samples',
                  style: PlaygroundTheme.labelStyle.copyWith(fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _categoryColor(RangeOfMotionCategory category) {
    switch (category) {
      case RangeOfMotionCategory.minimal:
        return PlaygroundTheme.textMuted;
      case RangeOfMotionCategory.limited:
        return PlaygroundTheme.error;
      case RangeOfMotionCategory.moderate:
        return PlaygroundTheme.warningOrange;
      case RangeOfMotionCategory.good:
        return PlaygroundTheme.warning;
      case RangeOfMotionCategory.full:
        return PlaygroundTheme.success;
    }
  }
}

class _RomBar extends StatelessWidget {
  final RangeOfMotion? rom;
  final JointAngle? currentAngle;
  final Color color;

  const _RomBar({
    this.rom,
    this.currentAngle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final hasRom = rom != null && rom!.hasMeaningfulData;

          // Calculate positions (0-180 degrees mapped to 0-width)
          final minPos = hasRom ? (rom!.minDegrees / 180) * width : 0.0;
          final maxPos = hasRom ? (rom!.maxDegrees / 180) * width : width;
          final currentPos = currentAngle != null
              ? (currentAngle!.degrees / 180) * width
              : null;

          return Stack(
            children: [
              // Background bar (full 0-180 range)
              Container(
                height: 4,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: PlaygroundTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ROM range highlight
              if (hasRom)
                Positioned(
                  left: minPos,
                  top: 4,
                  child: Container(
                    width: maxPos - minPos,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

              // Min marker
              if (hasRom)
                Positioned(
                  left: minPos - 1,
                  top: 0,
                  child: Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

              // Max marker
              if (hasRom)
                Positioned(
                  left: maxPos - 1,
                  top: 0,
                  child: Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),

              // Current position marker
              if (currentPos != null)
                Positioned(
                  left: currentPos - 3,
                  top: 0,
                  child: Container(
                    width: 6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: PlaygroundTheme.accent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: PlaygroundTheme.textPrimary,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final RangeOfMotionCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    final text = _categoryText(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: PlaygroundTheme.badgeStyle.copyWith(color: color),
      ),
    );
  }

  String _categoryText(RangeOfMotionCategory category) {
    switch (category) {
      case RangeOfMotionCategory.minimal:
        return 'MINIMAL';
      case RangeOfMotionCategory.limited:
        return 'LIMITED';
      case RangeOfMotionCategory.moderate:
        return 'MODERATE';
      case RangeOfMotionCategory.good:
        return 'GOOD';
      case RangeOfMotionCategory.full:
        return 'FULL';
    }
  }

  Color _categoryColor(RangeOfMotionCategory category) {
    switch (category) {
      case RangeOfMotionCategory.minimal:
        return PlaygroundTheme.textMuted;
      case RangeOfMotionCategory.limited:
        return PlaygroundTheme.error;
      case RangeOfMotionCategory.moderate:
        return PlaygroundTheme.warningOrange;
      case RangeOfMotionCategory.good:
        return PlaygroundTheme.warning;
      case RangeOfMotionCategory.full:
        return PlaygroundTheme.success;
    }
  }
}

/// Compact ROM summary widget
class RomSummaryCard extends StatelessWidget {
  final int jointCount;
  final double averageRom;
  final double sessionDuration;
  final int totalSamples;

  const RomSummaryCard({
    super.key,
    required this.jointCount,
    required this.averageRom,
    required this.sessionDuration,
    required this.totalSamples,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlaygroundTheme.spacingSm),
      decoration: PlaygroundTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Joints', value: '$jointCount'),
          _StatItem(label: 'Avg ROM', value: '${averageRom.toInt()}°'),
          _StatItem(label: 'Duration', value: _formatDuration(sessionDuration)),
          _StatItem(label: 'Samples', value: _formatNumber(totalSamples)),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: PlaygroundTheme.valueSmallStyle),
        const SizedBox(height: 2),
        Text(
          label,
          style: PlaygroundTheme.labelStyle.copyWith(fontSize: 8),
        ),
      ],
    );
  }
}
