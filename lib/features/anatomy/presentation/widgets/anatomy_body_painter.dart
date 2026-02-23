import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';
import 'package:pose_detection/features/anatomy/presentation/data/muscle_path_data.dart';

/// Paints the anatomy avatar with colored muscle regions.
///
/// Render order (back → front):
/// 1. Body silhouette outline
/// 2. Muscle fills with status-based colors
/// 3. Muscle borders
/// 4. Selected muscle glow effect
class AnatomyBodyPainter extends CustomPainter {
  final List<MuscleGroup> muscles;
  final BodyView currentView;
  final String? selectedMuscleId;

  // ── Static paints for performance ──

  static final _silhouettePaint = Paint()
    ..color = const Color(0xFF333333)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final _silhouetteFillPaint = Paint()
    ..color = const Color(0xFF1A1A1A)
    ..style = PaintingStyle.fill;

  AnatomyBodyPainter({
    required this.muscles,
    required this.currentView,
    this.selectedMuscleId,
  });

  /// Get the display color for a muscle status.
  Color _getStatusColor(MuscleStatus status) {
    return switch (status) {
      NormalStatus() => const Color(0xFF2A2A2A),
      TrainedStatus() => const Color(0xFF4CAF50),
      ComplaintStatus() => const Color(0xFFFF5252),
      WeakStatus() => const Color(0xFFFFEB3B),
    };
  }

  /// Map of muscleId → MuscleStatus for quick lookup.
  Map<String, MuscleStatus> _buildStatusMap() {
    final map = <String, MuscleStatus>{};
    for (final muscle in muscles) {
      map[muscle.id] = muscle.status;
    }
    return map;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final statusMap = _buildStatusMap();

    // 1. Draw body silhouette (fill + outline)
    _drawSilhouette(canvas, size);

    // 2. Draw muscle regions
    final paths = getMusclePathsForView(currentView);
    for (final pathDef in paths) {
      final path = pathDef.buildPath(size);
      final status = statusMap[pathDef.muscleId] ?? const NormalStatus();
      final isSelected = pathDef.muscleId == selectedMuscleId;

      _drawMuscle(canvas, path, status, isSelected);
    }
  }

  void _drawSilhouette(Canvas canvas, Size size) {
    final segments = getSilhouetteForView(currentView);
    final path = buildSilhouettePath(segments, size);

    // Fill first, then outline
    canvas.drawPath(path, _silhouetteFillPaint);
    canvas.drawPath(path, _silhouettePaint);
  }

  void _drawMuscle(
    Canvas canvas,
    Path path,
    MuscleStatus status,
    bool isSelected,
  ) {
    final color = _getStatusColor(status);

    if (isSelected) {
      // Selected: strong glow + fill
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);

      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, borderPaint);
    } else {
      // Normal: subtle fill + thin border
      final fillPaint = Paint()
        ..color = color.withValues(alpha: status is NormalStatus ? 0.15 : 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      final borderPaint = Paint()
        ..color = color.withValues(alpha: status is NormalStatus ? 0.3 : 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AnatomyBodyPainter oldDelegate) {
    return oldDelegate.muscles != muscles ||
        oldDelegate.currentView != currentView ||
        oldDelegate.selectedMuscleId != selectedMuscleId;
  }
}
