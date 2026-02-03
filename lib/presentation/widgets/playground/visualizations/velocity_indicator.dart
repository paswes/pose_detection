import 'package:flutter/material.dart' hide Velocity;
import 'package:pose_detection/domain/motion/models/velocity.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Widget for displaying velocity with direction and speed category.
class VelocityIndicator extends StatelessWidget {
  final String label;
  final Velocity? velocity;

  const VelocityIndicator({
    super.key,
    required this.label,
    this.velocity,
  });

  @override
  Widget build(BuildContext context) {
    final speed = velocity?.speed ?? 0;
    final category = velocity?.category ?? VelocityCategory.stationary;
    final color = _categoryColor(category);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlaygroundTheme.spacingXs),
      child: Row(
        children: [
          // Direction arrow
          _DirectionArrow(velocity: velocity),
          const SizedBox(width: PlaygroundTheme.spacingSm),

          // Label
          Expanded(
            child: Text(
              label,
              style: PlaygroundTheme.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Speed value
          Text(
            velocity != null ? '${speed.toInt()}' : '--',
            style: PlaygroundTheme.valueSmallStyle.copyWith(
              color: velocity != null ? color : PlaygroundTheme.textMuted,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'px/s',
            style: PlaygroundTheme.labelStyle.copyWith(fontSize: 8),
          ),

          const SizedBox(width: PlaygroundTheme.spacingSm),

          // Category badge
          _CategoryBadge(category: category),
        ],
      ),
    );
  }

  Color _categoryColor(VelocityCategory category) {
    switch (category) {
      case VelocityCategory.stationary:
        return PlaygroundTheme.textMuted;
      case VelocityCategory.slow:
        return PlaygroundTheme.success;
      case VelocityCategory.moderate:
        return PlaygroundTheme.warning;
      case VelocityCategory.fast:
        return PlaygroundTheme.warningOrange;
      case VelocityCategory.veryFast:
        return PlaygroundTheme.error;
    }
  }
}

class _DirectionArrow extends StatelessWidget {
  final Velocity? velocity;

  const _DirectionArrow({this.velocity});

  @override
  Widget build(BuildContext context) {
    if (velocity == null || velocity!.isStationary()) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PlaygroundTheme.textMuted, width: 1),
        ),
      );
    }

    // Calculate direction angle from velocity vector
    final vx = velocity!.velocity.x;
    final vy = velocity!.velocity.y;
    final angle = _getDirectionAngle(vx, vy);

    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.arrow_upward,
        size: 16,
        color: _getCategoryColor(velocity!.category),
      ),
    );
  }

  double _getDirectionAngle(double x, double y) {
    // Convert velocity to angle (0 = up, clockwise)
    // Note: In Flutter, positive Y is down
    if (x == 0 && y == 0) return 0;

    // atan2 gives angle from positive X axis, counter-clockwise
    // We want angle from positive Y axis (down), clockwise
    final angle = -1 * (3.14159 / 2 - _atan2(y, x));
    return angle;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159;
    if (x == 0 && y > 0) return 3.14159 / 2;
    if (x == 0 && y < 0) return -3.14159 / 2;
    return 0;
  }

  double _atan(double x) {
    // Simple atan approximation for small angles
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }

  Color _getCategoryColor(VelocityCategory category) {
    switch (category) {
      case VelocityCategory.stationary:
        return PlaygroundTheme.textMuted;
      case VelocityCategory.slow:
        return PlaygroundTheme.success;
      case VelocityCategory.moderate:
        return PlaygroundTheme.warning;
      case VelocityCategory.fast:
        return PlaygroundTheme.warningOrange;
      case VelocityCategory.veryFast:
        return PlaygroundTheme.error;
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  final VelocityCategory category;

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

  String _categoryText(VelocityCategory category) {
    switch (category) {
      case VelocityCategory.stationary:
        return 'STILL';
      case VelocityCategory.slow:
        return 'SLOW';
      case VelocityCategory.moderate:
        return 'MED';
      case VelocityCategory.fast:
        return 'FAST';
      case VelocityCategory.veryFast:
        return 'V.FAST';
    }
  }

  Color _categoryColor(VelocityCategory category) {
    switch (category) {
      case VelocityCategory.stationary:
        return PlaygroundTheme.textMuted;
      case VelocityCategory.slow:
        return PlaygroundTheme.success;
      case VelocityCategory.moderate:
        return PlaygroundTheme.warning;
      case VelocityCategory.fast:
        return PlaygroundTheme.warningOrange;
      case VelocityCategory.veryFast:
        return PlaygroundTheme.error;
    }
  }
}

/// Summary widget for overall body movement
class BodyMovementIndicator extends StatelessWidget {
  final bool isStationary;
  final double averageSpeed;

  const BodyMovementIndicator({
    super.key,
    required this.isStationary,
    this.averageSpeed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final label = isStationary ? 'STATIONARY' : 'MOVING';
    final color = isStationary ? PlaygroundTheme.textMuted : PlaygroundTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PlaygroundTheme.spacingMd,
        vertical: PlaygroundTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStationary ? Icons.accessibility_new : Icons.directions_run,
            color: color,
            size: 16,
          ),
          const SizedBox(width: PlaygroundTheme.spacingSm),
          Text(
            label,
            style: PlaygroundTheme.badgeStyle.copyWith(color: color),
          ),
          if (!isStationary) ...[
            const SizedBox(width: PlaygroundTheme.spacingSm),
            Text(
              '${averageSpeed.toInt()} px/s',
              style: PlaygroundTheme.labelStyle.copyWith(
                color: color,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
