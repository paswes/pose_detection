import 'package:flutter/material.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Generic painter for drawing all 33 pose landmarks
/// High-visibility cyan skeleton for analysis purposes
class PosePainter extends CustomPainter {
  final TimestampedPose pose;
  final Size imageSize;
  final Size widgetSize;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // High-visibility cyan color scheme
    final Paint landmarkPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 5
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw all skeletal connections
    _drawAllConnections(canvas, linePaint);

    // Draw all landmark points
    for (final landmark in pose.landmarks) {
      final point = CoordinateTranslator.translateLandmark(
        landmark,
        imageSize,
        widgetSize,
      );

      // Draw confidence indicator (larger = higher confidence)
      final confidence = landmark.likelihood;
      canvas.drawCircle(
        point,
        10 + (confidence * 5),
        Paint()..color = Colors.yellow.withValues(alpha: confidence * 0.5),
      );

      // Draw landmark point
      canvas.drawCircle(point, 7, landmarkPaint);
    }
  }

  /// Draw all skeletal connections for the complete pose
  void _drawAllConnections(Canvas canvas, Paint paint) {
    // Complete pose skeleton connections using landmark IDs (0-32)
    final connections = [
      // Face (11 connections)
      [1, 2], [2, 3], [3, 7], // Left eye to ear
      [4, 5], [5, 6], [6, 8], // Right eye to ear
      [9, 10], // Mouth
      [0, 1], [0, 4], // Nose to eyes
      [9, 7], [10, 8], // Mouth to ears

      // Torso (4 connections)
      [11, 12], // Shoulders
      [11, 23], [12, 24], // Shoulders to hips
      [23, 24], // Hips

      // Left arm (6 connections)
      [11, 13], [13, 15], // Shoulder to wrist
      [15, 17], [15, 19], [17, 19], [15, 21], // Hand

      // Right arm (6 connections)
      [12, 14], [14, 16], // Shoulder to wrist
      [16, 18], [16, 20], [18, 20], [16, 22], // Hand

      // Left leg (5 connections)
      [23, 25], [25, 27], // Hip to ankle
      [27, 29], [27, 31], [29, 31], // Foot

      // Right leg (5 connections)
      [24, 26], [26, 28], // Hip to ankle
      [28, 30], [28, 32], [30, 32], // Foot
    ];

    for (final connection in connections) {
      final id1 = connection[0];
      final id2 = connection[1];

      // Find landmarks by ID
      final landmark1 = pose.landmarks.where((l) => l.id == id1).firstOrNull;
      final landmark2 = pose.landmarks.where((l) => l.id == id2).firstOrNull;

      if (landmark1 != null && landmark2 != null) {
        final point1 = CoordinateTranslator.translateLandmark(
          landmark1,
          imageSize,
          widgetSize,
        );
        final point2 = CoordinateTranslator.translateLandmark(
          landmark2,
          imageSize,
          widgetSize,
        );

        // Uniform cyan color - no conditional coloring
        canvas.drawLine(point1, point2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
