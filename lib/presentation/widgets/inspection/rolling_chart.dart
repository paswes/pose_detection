import 'package:flutter/material.dart';

/// Threshold line for chart visualization
class ChartThreshold {
  final double value;
  final Color color;
  final bool showLine;

  const ChartThreshold({
    required this.value,
    required this.color,
    this.showLine = true,
  });
}

/// Reusable rolling time-series chart widget
/// Uses CustomPainter for performance
class RollingChart extends StatelessWidget {
  /// Data points to display
  final List<double> data;

  /// Minimum value for Y axis
  final double minValue;

  /// Maximum value for Y axis
  final double maxValue;

  /// Line color
  final Color lineColor;

  /// Fill color under the line
  final Color fillColor;

  /// Optional threshold lines
  final List<ChartThreshold>? thresholds;

  /// Optional label (top left)
  final String? label;

  /// Optional current value label (top right)
  final String? currentValueLabel;

  /// Chart height
  final double height;

  const RollingChart({
    super.key,
    required this.data,
    required this.minValue,
    required this.maxValue,
    this.lineColor = const Color(0xFF4CAF50),
    this.fillColor = const Color(0x334CAF50),
    this.thresholds,
    this.label,
    this.currentValueLabel,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null || currentValueLabel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                if (currentValueLabel != null)
                  Text(
                    currentValueLabel!,
                    style: TextStyle(
                      color: lineColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _RollingChartPainter(
                data: data,
                minValue: minValue,
                maxValue: maxValue,
                lineColor: lineColor,
                fillColor: fillColor,
                thresholds: thresholds,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingChartPainter extends CustomPainter {
  final List<double> data;
  final double minValue;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final List<ChartThreshold>? thresholds;

  _RollingChartPainter({
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    this.thresholds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final range = maxValue - minValue;
    if (range <= 0) return;

    // Draw threshold lines
    if (thresholds != null) {
      for (final threshold in thresholds!) {
        if (threshold.showLine) {
          final normalizedY = (threshold.value - minValue) / range;
          final y = size.height - (normalizedY.clamp(0.0, 1.0) * size.height);
          final paint = Paint()
            ..color = threshold.color.withValues(alpha: 0.3)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      }
    }

    // Build path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = data.length > 1 ? i / (data.length - 1) * size.width : size.width / 2;
      final normalizedY = (data[i] - minValue) / range;
      final y = size.height - (normalizedY.clamp(0.0, 1.0) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    if (data.isNotEmpty) {
      final lastX = data.length > 1 ? size.width : size.width / 2;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw current value dot
    if (data.isNotEmpty) {
      final lastX = data.length > 1 ? size.width : size.width / 2;
      final lastNormalizedY = (data.last - minValue) / range;
      final lastY = size.height - (lastNormalizedY.clamp(0.0, 1.0) * size.height);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);

      final dotOutlinePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(lastX, lastY), 4, dotOutlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RollingChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
