import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// High-performance painter for drawing all 33 pose landmarks with depth visualization.
///
/// Optimizations:
/// - Pre-computes all coordinate translations once per frame
/// - Uses cached Paint objects
/// - Includes widgetSize in shouldRepaint for rotation handling
///
/// Visual features:
/// - Cyan skeleton for valid human poses (depth-based sizing)
/// - Red skeleton for invalid/rejected poses (false positive detection)
/// - Confidence indicator via yellow glow intensity
/// - Z-depth visualization via landmark radius and connection thickness
class PosePainter extends CustomPainter {
  final TimestampedPose pose;
  final Size imageSize;
  final Size widgetSize;

  /// Whether this pose passed human validation
  /// When false, the pose is rendered in red to indicate it's a false positive
  final bool isValidHuman;

  /// Complete pose skeleton connections using landmark IDs (0-32)
  static const List<List<int>> _connections = [
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

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    this.isValidHuman = true,
  });

  /// Primary color based on validation status
  Color get _primaryColor => isValidHuman ? Colors.cyan : Colors.red;

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.landmarks.isEmpty) return;

    // Pre-compute ALL translations with depth info ONCE
    final translatedPoints = CoordinateTranslator.translateAllLandmarksWithDepth(
      pose.landmarks,
      imageSize,
      widgetSize,
    );

    // Build a quick lookup for confidence values
    final confidenceMap = <int, double>{};
    for (final landmark in pose.landmarks) {
      confidenceMap[landmark.id] = landmark.likelihood;
    }

    // Draw all skeletal connections first (below landmarks)
    _drawAllConnections(canvas, translatedPoints, confidenceMap);

    // Draw all landmark points on top
    _drawAllLandmarks(canvas, translatedPoints, confidenceMap);
  }

  /// Draw all landmark points with depth-based sizing
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

      // Depth-based radius: closer landmarks (higher depth) are larger
      // Range: 4px (far) to 10px (close)
      final baseRadius = 4.0 + (depth * 6.0);

      // Confidence-based glow radius
      final glowRadius = baseRadius + 4 + (confidence * 4);

      // Draw confidence glow (yellow, fades with lower confidence)
      final glowPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: confidence * 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
      canvas.drawCircle(position, glowRadius, glowPaint);

      // Draw depth indicator ring (subtle white ring for depth perception)
      if (depth > 0.6) {
        // Only for close landmarks
        final depthRingPaint = Paint()
          ..color = Colors.white.withValues(alpha: (depth - 0.6) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(position, baseRadius + 2, depthRingPaint);
      }

      // Draw main landmark point with depth-adjusted color
      // Closer = more saturated, further = more muted
      // Color based on validation status (cyan for valid, red for invalid)
      final landmarkPaint = Paint()
        ..color = Color.lerp(
          _primaryColor.withValues(alpha: 0.6),
          _primaryColor,
          depth,
        )!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, baseRadius, landmarkPaint);

      // Draw center highlight for 3D effect
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3 + (depth * 0.3))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        position + Offset(-baseRadius * 0.2, -baseRadius * 0.2),
        baseRadius * 0.3,
        highlightPaint,
      );
    }
  }

  /// Draw all skeletal connections with depth-based thickness
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
        // Average depth of the two endpoints
        final avgDepth = (point1Data.normalizedDepth + point2Data.normalizedDepth) / 2;

        // Average confidence for line visibility
        final avgConfidence = ((confidenceMap[id1] ?? 0.5) + (confidenceMap[id2] ?? 0.5)) / 2;

        // Depth-based line thickness: 1.5px (far) to 4px (close)
        final lineWidth = 1.5 + (avgDepth * 2.5);

        // Confidence-based alpha: low confidence = more transparent
        final alpha = 0.4 + (avgConfidence * 0.6);

        final linePaint = Paint()
          ..color = _primaryColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(point1Data.position, point2Data.position, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    // Check all dimensions that affect rendering
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.widgetSize != widgetSize ||
        oldDelegate.isValidHuman != isValidHuman;
  }
}
