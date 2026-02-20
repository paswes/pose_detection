import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/services/frame_interpolator.dart';
import 'package:pose_detection/core/services/playback_sync_engine.dart';
import 'package:pose_detection/core/utils/transform_calculator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';

/// High-performance painter for playback pose overlay.
///
/// Polls [VideoPlayerController.value.position] directly in [paint()]
/// for minimal latency between video frame and overlay. Driven by
/// a [Listenable] (ticker) passed as [repaint] — no widget rebuilds needed.
///
/// In frame-stepping mode, [forcedFrameIndex] bypasses position polling
/// and renders the exact frame at that index.
class PlaybackOverlayPainter extends CustomPainter {
  final VideoPlayerController controller;
  final PlaybackSyncEngine syncEngine;
  final Size videoSize;
  final Session session;
  final int? forcedFrameIndex;
  final LandmarkSchema _schema;

  /// Get skeleton connections from injected schema
  List<List<int>> get _connections => _schema.skeletonConnections;

  PlaybackOverlayPainter({
    required this.controller,
    required this.syncEngine,
    required this.videoSize,
    required this.session,
    required Listenable repaint,
    this.forcedFrameIndex,
    LandmarkSchema? schema,
  }) : _schema = schema ?? sl<LandmarkSchema>(),
       super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (!syncEngine.hasFrames) return;

    // Determine which frame data to render
    List<LandmarkData> landmarks;

    if (forcedFrameIndex != null) {
      // Frame-stepping mode: use exact frame
      final frame = syncEngine.getFrameByIndex(forcedFrameIndex!);
      if (frame == null || !frame.isPersonDetected) return;
      landmarks = frame.landmarks;
    } else {
      // Continuous playback: poll position and interpolate
      final position = controller.value.position;

      // Hide overlay at start when not playing
      if (position == Duration.zero && !controller.value.isPlaying) return;

      final result = syncEngine.findFramePair(position);
      if (result == null) return;

      final (:frameA, :frameB, :t) = result;
      if (!frameA.isPersonDetected) return;

      if (frameB != null && frameB.isPersonDetected && t > 0.01) {
        landmarks = FrameInterpolator.interpolate(frameA, frameB, t);
      } else {
        landmarks = frameA.landmarks;
      }
    }

    if (landmarks.isEmpty) return;

    // Transform: raw ML Kit space → video pixel space
    final rawW = session.imageWidth;
    final rawH = session.imageHeight;
    if (rawW <= 0 || rawH <= 0) return;

    // Transform: video pixel space → widget space (BoxFit.cover)
    final transform = TransformCalculator.calculateCoverTransform(
      imageSize: videoSize,
      screenSize: size,
    );

    // Pre-compute all transformed positions and depth info
    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;
    for (final l in landmarks) {
      if (l.z < minZ) minZ = l.z;
      if (l.z > maxZ) maxZ = l.z;
    }
    final zRange = maxZ - minZ;
    final hasValidZRange = zRange > 0.001;

    final points = <int, ({Offset position, double normalizedDepth, double likelihood})>{};
    for (final l in landmarks) {
      // Raw ML Kit → video pixel space (proportional)
      final vx = (l.x / rawW) * videoSize.width;
      final vy = (l.y / rawH) * videoSize.height;

      // Video pixel space → widget space (BoxFit.cover)
      final wx = vx * transform.scale + transform.offset.dx;
      final wy = vy * transform.scale + transform.offset.dy;

      final normalizedDepth = hasValidZRange
          ? (1.0 - ((l.z - minZ) / zRange)).clamp(0.0, 1.0)
          : 0.5;

      points[l.id] = (
        position: Offset(wx, wy),
        normalizedDepth: normalizedDepth,
        likelihood: l.likelihood,
      );
    }

    // Draw connections first (below landmarks)
    _drawConnections(canvas, points);

    // Draw landmark points on top
    _drawLandmarks(canvas, points);
  }

  void _drawConnections(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth, double likelihood})> points,
  ) {
    for (final connection in _connections) {
      final id1 = connection[0];
      final id2 = connection[1];
      final p1 = points[id1];
      final p2 = points[id2];
      if (p1 == null || p2 == null) continue;

      final avgDepth = (p1.normalizedDepth + p2.normalizedDepth) / 2;
      final avgLikelihood = (p1.likelihood + p2.likelihood) / 2;
      final lineWidth = 1.5 + (avgDepth * 2.0);
      final alpha = 0.3 + (avgLikelihood * 0.5);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1.position, p2.position, paint);
    }
  }

  void _drawLandmarks(
    Canvas canvas,
    Map<int, ({Offset position, double normalizedDepth, double likelihood})> points,
  ) {
    for (final entry in points.entries) {
      final pos = entry.value.position;
      final depth = entry.value.normalizedDepth;
      final likelihood = entry.value.likelihood;

      final baseRadius = 4.0 + (depth * 4.0);
      final color = _getLikelihoodColor(likelihood);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
      canvas.drawCircle(pos, baseRadius + 3, glowPaint);

      // Point
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, baseRadius, pointPaint);

      // Outline
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(pos, baseRadius, outlinePaint);
    }
  }

  Color _getLikelihoodColor(double likelihood) {
    if (likelihood > 0.8) return const Color(0xFF4CAF50);
    if (likelihood > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  @override
  bool shouldRepaint(covariant PlaybackOverlayPainter oldDelegate) => true;
}
