import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Paints pose landmarks and skeleton connections over a video player.
///
/// Draws only the landmark overlay — not the frame image.
/// The video is rendered by a separate [VideoPlayer] widget
/// underneath in a [Stack].
class LandmarkOverlayPainter extends CustomPainter {
  final TrackedFrame? trackedFrame;
  final Size videoSize;
  final double rawImageWidth;
  final double rawImageHeight;
  final bool isFrontCamera;
  final LandmarkSchema _schema;

  LandmarkOverlayPainter({
    required this.trackedFrame,
    required this.videoSize,
    required this.rawImageWidth,
    required this.rawImageHeight,
    this.isFrontCamera = false,
    LandmarkSchema? schema,
  }) : _schema = schema ?? sl<LandmarkSchema>();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = trackedFrame;
    if (frame == null || !frame.isPersonDetected || frame.landmarks.isEmpty) {
      return;
    }

    _drawLandmarks(canvas, size, frame);
  }

  void _drawLandmarks(Canvas canvas, Size size, TrackedFrame frame) {
    // Convert stored landmarks to domain Landmark objects,
    // normalizing from raw ML Kit buffer space to video pixel space.
    final landmarks = frame.landmarks.map((l) {
      var x = (l.x / rawImageWidth) * videoSize.width;
      final y = (l.y / rawImageHeight) * videoSize.height;

      // Front camera: mirror x
      if (isFrontCamera) {
        x = videoSize.width - x;
      }

      return Landmark(
        id: l.id,
        x: x,
        y: y,
        z: l.z,
        likelihood: l.likelihood,
      );
    }).toList();

    // Translate to widget coordinates using the same BoxFit.cover transform
    final translatedPoints =
        CoordinateTranslator.translateAllLandmarksWithDepth(
      landmarks,
      videoSize,
      size,
    );

    final likelihoodMap = <int, double>{};
    for (final l in landmarks) {
      likelihoodMap[l.id] = l.likelihood;
    }

    // Draw connections first (below landmarks)
    _drawConnections(canvas, translatedPoints, likelihoodMap);

    // Draw landmarks on top
    _drawLandmarkPoints(canvas, translatedPoints, likelihoodMap);
  }

  void _drawLandmarkPoints(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth})> points,
    Map<int, double> likelihoodMap,
  ) {
    for (final entry in points.entries) {
      final id = entry.key;
      final position = entry.value.position;
      final depth = entry.value.normalizedDepth;
      final likelihood = likelihoodMap[id] ?? 0.5;

      final baseRadius = 4.0 + (depth * 4.0);
      final color = _getLikelihoodColor(likelihood);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(position, baseRadius + 3, glowPaint);

      // Fill
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, baseRadius, fillPaint);

      // Outline
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(position, baseRadius, outlinePaint);
    }
  }

  void _drawConnections(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth})> points,
    Map<int, double> likelihoodMap,
  ) {
    for (final connection in _schema.skeletonConnections) {
      final id1 = connection[0];
      final id2 = connection[1];

      final p1 = points[id1];
      final p2 = points[id2];

      if (p1 != null && p2 != null) {
        final avgDepth = (p1.normalizedDepth + p2.normalizedDepth) / 2;
        final avgLikelihood =
            ((likelihoodMap[id1] ?? 0.5) + (likelihoodMap[id2] ?? 0.5)) / 2;
        final lineWidth = 1.5 + (avgDepth * 2.0);
        final alpha = 0.3 + (avgLikelihood * 0.5);

        final linePaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(p1.position, p2.position, linePaint);
      }
    }
  }

  Color _getLikelihoodColor(double likelihood) {
    if (likelihood > 0.8) return const Color(0xFF4CAF50);
    if (likelihood > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  @override
  bool shouldRepaint(covariant LandmarkOverlayPainter oldDelegate) {
    return oldDelegate.trackedFrame != trackedFrame;
  }
}
