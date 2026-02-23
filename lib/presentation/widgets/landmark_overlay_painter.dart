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
  final ValueNotifier<TrackedFrame?> frameNotifier;
  final Size videoSize;
  final double rawImageWidth;
  final double rawImageHeight;
  final bool isFrontCamera;
  final FitMode fitMode;
  final LandmarkSchema _schema;
  final Set<int>? _visibleIds;
  final int? selectedLandmarkId;
  final Set<int> injuredLandmarkIds;
  final double alignY;

  LandmarkOverlayPainter({
    required this.frameNotifier,
    required this.videoSize,
    required this.rawImageWidth,
    required this.rawImageHeight,
    this.isFrontCamera = false,
    this.fitMode = FitMode.cover,
    this.selectedLandmarkId,
    this.injuredLandmarkIds = const {},
    this.alignY = 0.5,
    LandmarkSchema? schema,
    Set<int>? visibleLandmarkIds,
  }) : _schema = schema ?? sl<LandmarkSchema>(),
       _visibleIds = visibleLandmarkIds,
       super(repaint: frameNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameNotifier.value;
    if (frame == null || !frame.isPersonDetected || frame.landmarks.isEmpty) {
      return;
    }

    _drawLandmarks(canvas, size, frame);
  }

  void _drawLandmarks(Canvas canvas, Size size, TrackedFrame frame) {
    // Convert stored landmarks to domain Landmark objects,
    // normalizing from raw ML Kit buffer space to video pixel space.
    // When a visible set is provided, skip landmarks outside it.
    final landmarks = <Landmark>[];
    for (final l in frame.landmarks) {
      if (_visibleIds != null && !_visibleIds.contains(l.id)) continue;

      var x = (l.x / rawImageWidth) * videoSize.width;
      final y = (l.y / rawImageHeight) * videoSize.height;

      // Front camera: mirror x
      if (isFrontCamera) {
        x = videoSize.width - x;
      }

      landmarks.add(
        Landmark(
          id: l.id,
          x: x,
          y: y,
          z: l.z,
          likelihood: l.likelihood,
        ),
      );
    }

    // Translate to widget coordinates using the matching BoxFit transform
    final translatedPoints =
        CoordinateTranslator.translateAllLandmarksWithDepth(
          landmarks,
          videoSize,
          size,
          fitMode: fitMode,
          alignY: alignY,
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
    final hasSelection = selectedLandmarkId != null;

    for (final entry in points.entries) {
      final id = entry.key;
      final position = entry.value.position;
      final depth = entry.value.normalizedDepth;
      final likelihood = likelihoodMap[id] ?? 0.5;
      final isSelected = id == selectedLandmarkId;

      final baseRadius = 4.0 + (depth * 4.0);
      final isInjured = injuredLandmarkIds.contains(id);
      final color = isInjured
          ? const Color(0xFFF44336)
          : _getLikelihoodColor(likelihood);
      final dimFactor = hasSelection && !isSelected ? 0.2 : 1.0;
      final drawRadius = isSelected ? baseRadius * 2.0 : baseRadius;

      if (isSelected) {
        // Outer pulse glow — very large, soft
        final outerGlow = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 24);
        canvas.drawCircle(position, drawRadius + 20, outerGlow);

        // Inner selection glow — bright white
        final selectionGlow = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14);
        canvas.drawCircle(position, drawRadius + 10, selectionGlow);
      }

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3 * dimFactor)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(position, drawRadius + 3, glowPaint);

      // Fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: dimFactor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, drawRadius, fillPaint);

      // Outline
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (isSelected ? 1.0 : 0.5) * dimFactor,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 1.0;
      canvas.drawCircle(position, drawRadius, outlinePaint);
    }
  }

  void _drawConnections(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth})> points,
    Map<int, double> likelihoodMap,
  ) {
    final hasSelection = selectedLandmarkId != null;

    for (final connection in _schema.skeletonConnections) {
      final id1 = connection[0];
      final id2 = connection[1];

      final p1 = points[id1];
      final p2 = points[id2];

      if (p1 != null && p2 != null) {
        final avgDepth = (p1.normalizedDepth + p2.normalizedDepth) / 2;
        final avgLikelihood =
            ((likelihoodMap[id1] ?? 0.5) + (likelihoodMap[id2] ?? 0.5)) / 2;
        final baseLineWidth = 1.5 + (avgDepth * 2.0);
        final touchesSelected =
            id1 == selectedLandmarkId || id2 == selectedLandmarkId;
        final dimFactor = hasSelection && !touchesSelected ? 0.3 : 1.0;
        final alpha = (0.3 + (avgLikelihood * 0.5)) * dimFactor;

        final lineColor = touchesSelected
            ? _getLikelihoodColor(avgLikelihood)
            : Colors.white;
        final lineWidth = touchesSelected ? baseLineWidth * 2.0 : baseLineWidth;
        final lineAlpha = touchesSelected ? 0.9 : alpha;

        if (touchesSelected) {
          // Connection glow behind the line
          final glowPaint = Paint()
            ..color = lineColor.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = lineWidth + 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
          canvas.drawLine(p1.position, p2.position, glowPaint);
        }

        final linePaint = Paint()
          ..color = lineColor.withValues(alpha: lineAlpha)
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
    // Repaints are driven by the frameNotifier listenable (via super.repaint),
    // not by widget rebuilds. Only repaint on config changes.
    return oldDelegate.videoSize != videoSize ||
        oldDelegate.rawImageWidth != rawImageWidth ||
        oldDelegate.rawImageHeight != rawImageHeight ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.fitMode != fitMode ||
        oldDelegate._schema != _schema ||
        oldDelegate._visibleIds != _visibleIds ||
        oldDelegate.selectedLandmarkId != selectedLandmarkId ||
        oldDelegate.injuredLandmarkIds != injuredLandmarkIds ||
        oldDelegate.alignY != alignY;
  }
}
