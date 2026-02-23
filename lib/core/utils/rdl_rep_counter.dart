import 'dart:math';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// Phase of a single RDL repetition.
enum RdlPhase { standing, descending, ascending }

/// Counts Romanian Deadlift reps by tracking the hip hinge angle
/// (shoulder-center → hip-center → knee-center) through a state machine.
///
/// Pure logic — no Flutter dependencies.
class RdlRepCounter {
  /// Angle above which the lifter is considered standing (top of rep).
  static const _standingAngle = 160.0;

  /// Angle below which the lifter has reached the bottom of the hinge.
  static const _hingeAngle = 145.0;

  /// Minimum landmark confidence to trust a coordinate.
  static const _minLikelihood = 0.5;

  /// Number of recent angles to average for smoothing.
  static const _smoothingWindow = 3;

  int _repCount = 0;
  RdlPhase _phase = RdlPhase.standing;
  double? _currentAngle;
  final List<double> _angleBuffer = [];

  int get repCount => _repCount;
  RdlPhase get phase => _phase;
  double? get currentAngle => _currentAngle;

  /// Process a single frame. Returns `true` if the rep count changed.
  bool processFrame(TrackedFrame frame) {
    final angle = calculateHipAngle(frame);
    _currentAngle = angle;
    if (angle == null) return false;

    _angleBuffer.add(angle);
    if (_angleBuffer.length > _smoothingWindow) {
      _angleBuffer.removeAt(0);
    }

    final smoothed = _smoothedAngle();
    if (smoothed == null) return false;

    return _updatePhase(smoothed);
  }

  /// Replay frames 0..[targetIndex] to get the correct rep count
  /// at any arbitrary position (handles backward seeks).
  void countRepsUpTo(List<TrackedFrame> frames, int targetIndex) {
    reset();
    final end = targetIndex.clamp(0, frames.length - 1);
    for (int i = 0; i <= end; i++) {
      processFrame(frames[i]);
    }
  }

  /// Reset all state to initial values.
  void reset() {
    _repCount = 0;
    _phase = RdlPhase.standing;
    _currentAngle = null;
    _angleBuffer.clear();
  }

  /// Calculate the hip hinge angle from a frame's landmarks.
  ///
  /// Returns the 3-point angle (in degrees) at the hip center:
  /// shoulder-center → hip-center → knee-center.
  /// Returns `null` if required landmarks are missing or low-confidence.
  static double? calculateHipAngle(TrackedFrame frame) {
    if (!frame.isPersonDetected) return null;

    final lShoulder = _findLandmark(frame, LandmarkSchema.leftShoulder);
    final rShoulder = _findLandmark(frame, LandmarkSchema.rightShoulder);
    final lHip = _findLandmark(frame, LandmarkSchema.leftHip);
    final rHip = _findLandmark(frame, LandmarkSchema.rightHip);
    final lKnee = _findLandmark(frame, LandmarkSchema.leftKnee);
    final rKnee = _findLandmark(frame, LandmarkSchema.rightKnee);

    if (lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lKnee == null ||
        rKnee == null) {
      return null;
    }

    // Center points (average left + right)
    final sx = (lShoulder.x + rShoulder.x) / 2;
    final sy = (lShoulder.y + rShoulder.y) / 2;
    final hx = (lHip.x + rHip.x) / 2;
    final hy = (lHip.y + rHip.y) / 2;
    final kx = (lKnee.x + rKnee.x) / 2;
    final ky = (lKnee.y + rKnee.y) / 2;

    return _angle3Point(sx, sy, hx, hy, kx, ky);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Update the state machine. Returns `true` if a rep was counted.
  bool _updatePhase(double smoothedAngle) {
    switch (_phase) {
      case RdlPhase.standing:
        if (smoothedAngle < _hingeAngle) {
          _phase = RdlPhase.descending;
        }
        return false;

      case RdlPhase.descending:
        if (smoothedAngle >= _standingAngle) {
          _repCount++;
          _phase = RdlPhase.standing;
          return true;
        }
        return false;

      case RdlPhase.ascending:
        // Not used in simplified 3-state machine, but kept for extensibility.
        if (smoothedAngle >= _standingAngle) {
          _repCount++;
          _phase = RdlPhase.standing;
          return true;
        }
        return false;
    }
  }

  double? _smoothedAngle() {
    if (_angleBuffer.isEmpty) return null;
    return _angleBuffer.reduce((a, b) => a + b) / _angleBuffer.length;
  }

  /// Find a landmark by ID with minimum confidence, or return `null`.
  static LandmarkData? _findLandmark(TrackedFrame frame, int id) {
    for (final l in frame.landmarks) {
      if (l.id == id && l.likelihood >= _minLikelihood) return l;
    }
    return null;
  }

  /// 3-point angle at vertex (bx, by) between rays to (ax, ay) and (cx, cy).
  /// Returns degrees in [0, 180].
  static double _angle3Point(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final dx1 = ax - bx;
    final dy1 = ay - by;
    final dx2 = cx - bx;
    final dy2 = cy - by;

    final dot = dx1 * dx2 + dy1 * dy2;
    final cross = dx1 * dy2 - dy1 * dx2;

    return atan2(cross.abs(), dot) * (180.0 / pi);
  }
}
