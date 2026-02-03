import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// A semi-circular gauge widget for displaying joint angles.
///
/// Shows:
/// - Arc filled proportionally to angle (0-180°)
/// - Color based on confidence level
/// - Degree value centered below
/// - Confidence indicator dots
class AngleGauge extends StatelessWidget {
  final String label;
  final JointAngle? angle;
  final double size;

  const AngleGauge({
    super.key,
    required this.label,
    this.angle,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final degrees = angle?.degrees ?? 0;
    final confidence = angle?.confidence ?? 0;
    final color = PlaygroundTheme.confidenceColor(confidence);

    return Container(
      width: size + 20,
      padding: const EdgeInsets.all(PlaygroundTheme.spacingSm),
      decoration: PlaygroundTheme.cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: PlaygroundTheme.labelStyle.copyWith(fontSize: 9),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: PlaygroundTheme.spacingXs),

          // Gauge
          SizedBox(
            width: size,
            height: size / 2 + 8,
            child: CustomPaint(
              painter: _AngleGaugePainter(
                angle: degrees,
                color: color,
                confidence: confidence,
              ),
            ),
          ),

          // Degree value
          Text(
            angle != null ? '${degrees.toInt()}°' : '--',
            style: PlaygroundTheme.valueSmallStyle.copyWith(
              color: angle != null ? color : PlaygroundTheme.textMuted,
            ),
          ),

          // Confidence dots
          const SizedBox(height: 2),
          _ConfidenceDots(confidence: confidence, size: 4),
        ],
      ),
    );
  }
}

class _AngleGaugePainter extends CustomPainter {
  final double angle;
  final Color color;
  final double confidence;

  _AngleGaugePainter({
    required this.angle,
    required this.color,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.width / 2 - 4;

    // Background arc
    final bgPaint = Paint()
      ..color = PlaygroundTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // Start from left
      math.pi, // 180 degrees
      false,
      bgPaint,
    );

    // Filled arc (angle / 180 of the semicircle)
    if (angle > 0) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      final sweepAngle = (angle / 180) * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi, // Start from left
        sweepAngle,
        false,
        fillPaint,
      );
    }

    // Center dot
    final dotPaint = Paint()
      ..color = PlaygroundTheme.textMuted
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(_AngleGaugePainter oldDelegate) {
    return angle != oldDelegate.angle ||
        color != oldDelegate.color ||
        confidence != oldDelegate.confidence;
  }
}

class _ConfidenceDots extends StatelessWidget {
  final double confidence;
  final double size;

  const _ConfidenceDots({required this.confidence, required this.size});

  @override
  Widget build(BuildContext context) {
    final filledDots = (confidence * 5).ceil().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isFilled = index < filledDots;
        return Container(
          width: size,
          height: size,
          margin: EdgeInsets.symmetric(horizontal: size / 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? PlaygroundTheme.confidenceColor(confidence)
                : PlaygroundTheme.border,
          ),
        );
      }),
    );
  }
}

/// Compact angle display for lists
class AngleListItem extends StatelessWidget {
  final String label;
  final JointAngle? angle;

  const AngleListItem({
    super.key,
    required this.label,
    this.angle,
  });

  @override
  Widget build(BuildContext context) {
    final degrees = angle?.degrees ?? 0;
    final confidence = angle?.confidence ?? 0;
    final color = PlaygroundTheme.confidenceColor(confidence);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: PlaygroundTheme.spacingXs,
      ),
      child: Row(
        children: [
          // Label
          Expanded(
            child: Text(
              label,
              style: PlaygroundTheme.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Value
          Text(
            angle != null ? '${degrees.toInt()}°' : '--',
            style: PlaygroundTheme.valueSmallStyle.copyWith(
              color: angle != null ? color : PlaygroundTheme.textMuted,
            ),
          ),

          const SizedBox(width: PlaygroundTheme.spacingSm),

          // Mini progress bar
          SizedBox(
            width: 40,
            height: 4,
            child: LinearProgressIndicator(
              value: degrees / 180,
              backgroundColor: PlaygroundTheme.border,
              valueColor: AlwaysStoppedAnimation(color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
