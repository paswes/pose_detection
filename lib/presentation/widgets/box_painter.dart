import 'package:flutter/material.dart';

/// Paints a simple target box where the user should position themselves
class SilhouettePainter extends CustomPainter {
  final bool isProperlyPositioned;

  SilhouettePainter({
    this.isProperlyPositioned = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = isProperlyPositioned
        ? Colors.green
        : Colors.white;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Target box - centered, takes up ~60% of screen
    final boxWidth = size.width * 0.6;
    final boxHeight = size.height * 0.7;
    final left = (size.width - boxWidth) / 2;
    final top = (size.height - boxHeight) / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(20),
    );

    canvas.drawRRect(rect, paint);

    // Corner markers for better visibility
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // Top-right corner
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top), Offset(left + boxWidth, top), cornerPaint);
    canvas.drawLine(Offset(left + boxWidth, top), Offset(left + boxWidth, top + cornerLength), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, top + boxHeight - cornerLength), Offset(left, top + boxHeight), cornerPaint);
    canvas.drawLine(Offset(left, top + boxHeight), Offset(left + cornerLength, top + boxHeight), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top + boxHeight), Offset(left + boxWidth, top + boxHeight), cornerPaint);
    canvas.drawLine(Offset(left + boxWidth, top + boxHeight - cornerLength), Offset(left + boxWidth, top + boxHeight), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant SilhouettePainter oldDelegate) {
    return oldDelegate.isProperlyPositioned != isProperlyPositioned;
  }
}
