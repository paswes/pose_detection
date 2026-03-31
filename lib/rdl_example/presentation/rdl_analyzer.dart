import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';
import 'package:pose_detection/rdl_example/domain/rdl_rep_counter.dart';
import 'package:pose_detection/rdl_example/presentation/rdl_analytics_page.dart';
import 'package:pose_detection/rdl_example/presentation/rdl_landmark_schema.dart';

/// [ExerciseAnalyzer] implementation for Romanian Deadlift rep counting
/// and biomechanical analysis.
///
/// This is the reference implementation that coworkers can copy to build
/// new exercise examples. See [ExerciseAnalyzer] for the interface contract.
class RdlAnalyzer implements ExerciseAnalyzer {
  final RdlRepCounter _counter = RdlRepCounter();
  List<RdlRepData> _allReps = const [];
  final Set<int> _injuredIds = {};

  @override
  LandmarkSchema get schema => rdlSchema;

  @override
  Set<int>? get visibleLandmarkIds => rdlLandmarkIds;

  @override
  void precompute(List<TrackedFrame> frames) {
    _counter.countRepsUpTo(frames, frames.length - 1);
    _allReps = _counter.reps;
    _counter.reset();
    _counter.processFrame(frames.first, globalFrameIndex: 0);
  }

  @override
  void processFrame(TrackedFrame frame, {required int globalFrameIndex}) {
    _counter.processFrame(frame, globalFrameIndex: globalFrameIndex);
  }

  @override
  void processFrameRange(
    List<TrackedFrame> frames,
    int startIndex,
    int endIndex,
  ) {
    _counter.processFrameRange(frames, startIndex, endIndex);
  }

  @override
  void replayUpTo(List<TrackedFrame> frames, int targetIndex) {
    _counter.countRepsUpTo(frames, targetIndex);
  }

  @override
  void reset() {
    _counter.reset();
  }

  @override
  Set<int> get injuredLandmarkIds => _injuredIds;

  @override
  void toggleInjury(int id) {
    if (_injuredIds.contains(id)) {
      _injuredIds.remove(id);
    } else {
      _injuredIds.add(id);
    }
  }

  @override
  Widget? buildHud(BuildContext context, int currentFrameIndex) {
    if (_allReps.isEmpty) return null;

    var repNum = 1;
    for (final rep in _allReps) {
      if (currentFrameIndex >= rep.startFrameIndex) {
        repNum = rep.repNumber;
      }
    }

    return _OverlayBadge(
      value: '$repNum of ${_allReps.length}',
      label: 'Reps',
    );
  }

  @override
  Widget? buildSliderExtras(
    BuildContext context, {
    required int totalFrames,
    required int currentFrameIndex,
    required void Function(int frameIndex) onSeekToFrame,
  }) {
    if (_allReps.isEmpty) return null;

    var activeRepNumber = 1;
    for (final rep in _allReps) {
      if (currentFrameIndex >= rep.startFrameIndex) {
        activeRepNumber = rep.repNumber;
      }
    }

    return _RepPillRow(
      reps: _allReps,
      totalFrames: totalFrames,
      activeRepNumber: activeRepNumber,
      onSeekToFrame: onSeekToFrame,
    );
  }

  @override
  List<({String label, String value})> computeDetailMetrics(
    TrackedFrame? frame,
  ) {
    if (frame == null) return [];

    final hipAngle = RdlRepCounter.calculateHipAngle(frame);
    final leftKnee = RdlRepCounter.calculateKneeAngle(frame, left: true);
    final rightKnee = RdlRepCounter.calculateKneeAngle(frame, left: false);
    final double? kneeAngle;
    if (leftKnee != null && rightKnee != null) {
      kneeAngle = (leftKnee + rightKnee) / 2;
    } else {
      kneeAngle = leftKnee ?? rightKnee;
    }
    final torsoLean = RdlRepCounter.calculateTorsoLean(frame);

    String fmt(double? v) => v != null ? '${v.toStringAsFixed(1)}°' : '–';

    return [
      (label: 'Hüftwinkel', value: fmt(hipAngle)),
      (label: 'Kniewinkel', value: fmt(kneeAngle)),
      (label: 'Oberkörper', value: fmt(torsoLean)),
    ];
  }

  @override
  Widget? buildAnalyticsPage(Session session) {
    if (_allReps.isEmpty) return null;
    return RdlAnalyticsPage(session: session, reps: _allReps);
  }
}

class _OverlayBadge extends StatelessWidget {
  final String value;
  final String label;

  const _OverlayBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepPillRow extends StatelessWidget {
  final List<RdlRepData> reps;
  final int totalFrames;
  final int activeRepNumber;
  final void Function(int frameIndex) onSeekToFrame;

  static const _trackPadding = 8.0;
  static const _markerDiameter = 28.0;

  const _RepPillRow({
    required this.reps,
    required this.totalFrames,
    required this.activeRepNumber,
    required this.onSeekToFrame,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) => _handleTap(details.localPosition, context),
      child: CustomPaint(
        painter: _RepCirclePainter(
          reps: reps,
          totalFrames: totalFrames,
          activeRepNumber: activeRepNumber,
        ),
        child: const SizedBox(height: _markerDiameter, width: double.infinity),
      ),
    );
  }

  void _handleTap(Offset tap, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final trackWidth = box.size.width - _trackPadding * 2;
    final maxFrames = (totalFrames - 1).clamp(1, totalFrames);

    for (final rep in reps) {
      final x = _trackPadding + (rep.startFrameIndex / maxFrames) * trackWidth;
      if ((tap.dx - x).abs() < _markerDiameter / 2 + 6) {
        HapticFeedback.selectionClick();
        onSeekToFrame(rep.startFrameIndex);
        return;
      }
    }
  }
}

class _RepCirclePainter extends CustomPainter {
  final List<RdlRepData> reps;
  final int totalFrames;
  final int activeRepNumber;

  static const _trackPadding = 8.0;
  static const _diameter = 28.0;
  static const _activeColor = Color(0xFF4CAF50);
  static const _inactiveColor = Color(0xFF2A2A2A);

  _RepCirclePainter({
    required this.reps,
    required this.totalFrames,
    required this.activeRepNumber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (reps.isEmpty || totalFrames <= 1) return;

    final trackWidth = size.width - _trackPadding * 2;
    final maxFrames = totalFrames - 1;
    final cy = size.height / 2;

    for (final rep in reps) {
      final cx = _trackPadding + (rep.startFrameIndex / maxFrames) * trackWidth;
      final isActive = rep.repNumber <= activeRepNumber;

      final circlePaint = Paint()
        ..color = isActive ? _activeColor : _inactiveColor;
      canvas.drawCircle(Offset(cx, cy), _diameter / 2, circlePaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${rep.repNumber}',
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF888888),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RepCirclePainter old) =>
      old.reps.length != reps.length ||
      old.totalFrames != totalFrames ||
      old.activeRepNumber != activeRepNumber;
}
