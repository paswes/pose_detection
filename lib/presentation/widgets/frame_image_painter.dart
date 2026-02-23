import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/utils/coordinate_translator.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Paints a video frame image and its landmarks in a single pass.
///
/// By rendering both the frame and landmarks in one [paint] call,
/// we guarantee perfect synchronization — no async lag between
/// the displayed image and the overlay.
class FrameImagePainter extends CustomPainter {
  final ui.Image frameImage;
  final TrackedFrame? trackedFrame;
  final double rawImageWidth;
  final double rawImageHeight;
  final bool isFrontCamera;
  final LandmarkSchema _schema;

  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  FrameImagePainter({
    required this.frameImage,
    this.trackedFrame,
    required this.rawImageWidth,
    required this.rawImageHeight,
    this.isFrontCamera = false,
    LandmarkSchema? schema,
  }) : _schema = schema ?? sl<LandmarkSchema>();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw frame image (BoxFit.cover)
    _drawFrameImage(canvas, size);

    // 2. Draw landmarks on top if person detected
    if (trackedFrame != null &&
        trackedFrame!.isPersonDetected &&
        trackedFrame!.landmarks.isNotEmpty) {
      _drawLandmarks(canvas, size);
    }
  }

  void _drawFrameImage(Canvas canvas, Size size) {
    final imgW = frameImage.width.toDouble();
    final imgH = frameImage.height.toDouble();

    // BoxFit.cover: scale uniformly to fill, center, clip overflow
    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final fittedW = imgW * scale;
    final fittedH = imgH * scale;
    final offsetX = (size.width - fittedW) / 2;
    final offsetY = (size.height - fittedH) / 2;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Rect.fromLTWH(offsetX, offsetY, fittedW, fittedH);

    canvas.drawImageRect(frameImage, src, dst, _imagePaint);
  }

  void _drawLandmarks(Canvas canvas, Size size) {
    final frame = trackedFrame!;

    // Convert stored landmarks to domain Landmark objects,
    // normalizing from raw ML Kit buffer space to video pixel space.
    final videoSize = Size(
      frameImage.width.toDouble(),
      frameImage.height.toDouble(),
    );

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
    final translatedPoints = CoordinateTranslator.translateAllLandmarksWithDepth(
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
  bool shouldRepaint(covariant FrameImagePainter oldDelegate) {
    return oldDelegate.frameImage != frameImage ||
        oldDelegate.trackedFrame != trackedFrame;
  }
}
