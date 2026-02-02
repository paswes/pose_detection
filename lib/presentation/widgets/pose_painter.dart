import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/domain/models/detected_pose.dart';

/// High-performance painter for pose landmarks with confidence heatmap.
///
/// Visual features:
/// - Confidence heatmap: Green (>0.8), Yellow (0.5-0.8), Red (<0.5)
/// - Depth-based sizing (closer = larger)
/// - Minimal, academic aesthetic
class PosePainter extends CustomPainter {
  final DetectedPose pose;
  final Size imageSize;
  final Size widgetSize;
  final LandmarkSchema _schema;

  /// Get skeleton connections from injected schema
  List<List<int>> get _connections => _schema.skeletonConnections;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    LandmarkSchema? schema,
  }) : _schema = schema ?? sl<LandmarkSchema>();

  /// Get confidence-based color (heatmap)
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return const Color(0xFF4CAF50); // Green
    } else if (confidence > 0.5) {
      return const Color(0xFFFFEB3B); // Yellow
    } else {
      return const Color(0xFFF44336); // Red
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.landmarks.isEmpty) return;

    // Pre-compute ALL translations with depth info ONCE
    final translatedPoints =
        CoordinateTranslator.translateAllLandmarksWithDepth(
          pose.landmarks,
          imageSize,
          widgetSize,
        );

    // Build a quick lookup for confidence values
    final confidenceMap = <int, double>{};
    for (final landmark in pose.landmarks) {
      confidenceMap[landmark.id] = landmark.confidence;
    }

    // Draw all skeletal connections first (below landmarks)
    _drawAllConnections(canvas, translatedPoints, confidenceMap);

    // Draw all landmark points on top
    _drawAllLandmarks(canvas, translatedPoints, confidenceMap);
  }

  /// Draw all landmark points with confidence heatmap coloring
  void _drawAllLandmarks(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth})> points,
    Map<int, double> confidenceMap,
  ) {
    for (final entry in points.entries) {
      final id = entry.key;
      final position = entry.value.position;
      final depth = entry.value.normalizedDepth;
      final confidence = confidenceMap[id] ?? 0.5;

      // Depth-based radius: closer = larger
      final baseRadius = 4.0 + (depth * 4.0);

      // Get confidence-based color
      final confidenceColor = _getConfidenceColor(confidence);

      // Draw subtle glow based on confidence
      final glowPaint = Paint()
        ..color = confidenceColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(position, baseRadius + 3, glowPaint);

      // Draw main landmark point with confidence color
      final landmarkPaint = Paint()
        ..color = confidenceColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, baseRadius, landmarkPaint);

      // Draw thin white outline for visibility
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(position, baseRadius, outlinePaint);
    }
  }

  /// Draw all skeletal connections with confidence-based coloring
  void _drawAllConnections(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth})> points,
    Map<int, double> confidenceMap,
  ) {
    for (final connection in _connections) {
      final id1 = connection[0];
      final id2 = connection[1];

      final point1Data = points[id1];
      final point2Data = points[id2];

      if (point1Data != null && point2Data != null) {
        // Average depth for line thickness
        final avgDepth =
            (point1Data.normalizedDepth + point2Data.normalizedDepth) / 2;

        // Average confidence for color
        final avgConfidence =
            ((confidenceMap[id1] ?? 0.5) + (confidenceMap[id2] ?? 0.5)) / 2;

        // Depth-based line thickness
        final lineWidth = 1.5 + (avgDepth * 2.0);

        // Use gray with confidence-based alpha (minimal, academic look)
        final alpha = 0.3 + (avgConfidence * 0.5);

        final linePaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(point1Data.position, point2Data.position, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize;
  }
}
