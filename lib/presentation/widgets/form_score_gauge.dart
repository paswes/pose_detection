import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular gauge widget displaying form score (0-100%)
class FormScoreGauge extends StatelessWidget {
  /// Form score from 0.0 to 1.0
  final double score;

  /// Size of the gauge
  final double size;

  /// Whether to show the percentage label
  final bool showLabel;

  const FormScoreGauge({
    super.key,
    required this.score,
    this.size = 80,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0.0, 1.0);
    final color = _getScoreColor(clampedScore);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background arc
          CustomPaint(
            size: Size(size, size),
            painter: _GaugeBackgroundPainter(
              strokeWidth: size * 0.1,
            ),
          ),
          // Score arc
          CustomPaint(
            size: Size(size, size),
            painter: _GaugeProgressPainter(
              progress: clampedScore,
              color: color,
              strokeWidth: size * 0.1,
            ),
          ),
          // Center content
          if (showLabel)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(clampedScore * 100).round()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'FORM',
                  style: TextStyle(
                    color: color,
                    fontSize: size * 0.11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.greenAccent;
    if (score >= 0.6) return Colors.yellowAccent;
    if (score >= 0.4) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _GaugeBackgroundPainter extends CustomPainter {
  final double strokeWidth;

  _GaugeBackgroundPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc from 135° to 405° (270° sweep)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _degToRad(135),
      _degToRad(270),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeBackgroundPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth;
  }
}

class _GaugeProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _GaugeProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Create gradient shader
    final gradient = SweepGradient(
      startAngle: _degToRad(135),
      endAngle: _degToRad(405),
      colors: [
        color.withValues(alpha: 0.6),
        color,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw progress arc (270° * progress)
    final sweepAngle = 270 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _degToRad(135),
      _degToRad(sweepAngle),
      false,
      paint,
    );

    // Draw glow effect at the end
    if (progress > 0.05) {
      final endAngle = 135 + sweepAngle;
      final endX = center.dx + radius * math.cos(_degToRad(endAngle));
      final endY = center.dy + radius * math.sin(_degToRad(endAngle));

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(endX, endY), strokeWidth / 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

double _degToRad(double degrees) => degrees * math.pi / 180;
