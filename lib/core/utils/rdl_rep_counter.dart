import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// Phase of a single RDL repetition.
enum RdlPhase { standing, descending }

/// Counts Romanian Deadlift reps by tracking the hip hinge angle
/// (shoulder-center → hip-center → knee-center) through a state machine.
///
/// Pure logic — no Flutter dependencies.
class RdlRepCounter {
  /// Angle above which the lifter is considered standing (top of rep).
  /// Real data shows standing phases peak at ~155-158° smoothed.
  /// 150° safely captures return to upright without requiring full extension.
  static const _standingAngle = 150.0;

  /// Angle below which the lifter has reached the bottom of the hinge.
  /// Real data shows bottom of hinge at ~77-91° raw. 110° captures
  /// the start of a meaningful descent with margin.
  static const _hingeAngle = 110.0;

  /// Hysteresis margin added to thresholds to prevent oscillation
  /// at threshold boundaries from noisy angle readings.
  /// Effective entry: < 105°, effective exit: > 155°.
  static const _hysteresisMargin = 5.0;

  /// Minimum landmark confidence to trust a coordinate.
  static const _minLikelihood = 0.5;

  /// Number of recent angles for the median filter.
  /// 3-frame median removes single-frame outliers while adding minimal
  /// lag (~50ms at 30 FPS). The wide hysteresis band handles the rest.
  static const _smoothingWindow = 3;

  /// Minimum frames a descent must last before a rep can be counted.
  /// With corrected thresholds (55° travel), this primarily guards
  /// against erratic tracking data. At 30 FPS, 8 frames ≈ 267ms.
  static const _minDescentFrames = 8;

  int _repCount = 0;
  RdlPhase _phase = RdlPhase.standing;
  double? _currentAngle;
  final List<double> _angleBuffer = [];

  // DEBUG: Track angle range across all frames
  double _minAngleSeen = double.infinity;
  double _maxAngleSeen = double.negativeInfinity;

  /// Frames spent in the current descending phase.
  int _descentFrameCount = 0;

  /// Consecutive null-angle frames.
  int _nullStreak = 0;

  /// Max consecutive null frames before clearing the angle buffer.
  /// At 30 FPS, 15 frames = 500ms — brief occlusions won't reset state.
  static const _maxNullStreak = 15;

  int get repCount => _repCount;
  RdlPhase get phase => _phase;
  double? get currentAngle => _currentAngle;

  // TODO: Remove debug logging after calibration
  int _frameIndex = 0;

  /// Process a single frame. Returns `true` if the rep count changed.
  bool processFrame(TrackedFrame frame) {
    final angle = calculateHipAngle(frame);
    _currentAngle = angle;
    _frameIndex++;

    if (angle == null) {
      _nullStreak++;
      if (_nullStreak >= _maxNullStreak) {
        _angleBuffer.clear();
      }
      return false;
    }

    _nullStreak = 0;

    // DEBUG: Track angle range
    if (angle < _minAngleSeen) _minAngleSeen = angle;
    if (angle > _maxAngleSeen) _maxAngleSeen = angle;

    _angleBuffer.add(angle);
    if (_angleBuffer.length > _smoothingWindow) {
      _angleBuffer.removeAt(0);
    }

    final smoothed = _smoothedAngle();
    if (smoothed == null) return false;

    // DEBUG: Log every 10th frame + all state transitions
    if (_frameIndex % 10 == 0) {
      debugPrint('[RepCounter] frame=$_frameIndex raw=${angle.toStringAsFixed(1)} '
          'smoothed=${smoothed.toStringAsFixed(1)} phase=$_phase '
          'descent=$_descentFrameCount reps=$_repCount');
    }

    return _updatePhase(smoothed);
  }

  /// Process a range of frames sequentially, from [startIndex] to
  /// [endIndex] inclusive.
  void processFrameRange(
    List<TrackedFrame> frames,
    int startIndex,
    int endIndex,
  ) {
    final start = startIndex.clamp(0, frames.length - 1);
    final end = endIndex.clamp(0, frames.length - 1);
    for (int i = start; i <= end; i++) {
      processFrame(frames[i]);
    }
  }

  /// Replay frames 0..[targetIndex] to get the correct rep count
  /// at any arbitrary position (handles backward seeks).
  void countRepsUpTo(List<TrackedFrame> frames, int targetIndex) {
    reset();
    final end = targetIndex.clamp(0, frames.length - 1);
    for (int i = 0; i <= end; i++) {
      processFrame(frames[i]);
    }
    debugPrint('[RepCounter] countRepsUpTo($targetIndex) → reps=$_repCount '
        'angleRange=${_minAngleSeen.toStringAsFixed(1)}..${_maxAngleSeen.toStringAsFixed(1)}');
  }

  /// Reset all state to initial values.
  void reset() {
    _repCount = 0;
    _phase = RdlPhase.standing;
    _currentAngle = null;
    _angleBuffer.clear();
    _descentFrameCount = 0;
    _nullStreak = 0;
    _frameIndex = 0;
    _minAngleSeen = double.infinity;
    _maxAngleSeen = double.negativeInfinity;
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
        if (smoothedAngle < _hingeAngle - _hysteresisMargin) {
          debugPrint('[RepCounter] STANDING→DESCENDING at frame=$_frameIndex '
              'smoothed=${smoothedAngle.toStringAsFixed(1)} '
              '(threshold: <${(_hingeAngle - _hysteresisMargin).toStringAsFixed(0)})');
          _phase = RdlPhase.descending;
          _descentFrameCount = 0;
        }
        return false;

      case RdlPhase.descending:
        _descentFrameCount++;
        if (smoothedAngle > _standingAngle + _hysteresisMargin &&
            _descentFrameCount >= _minDescentFrames) {
          _repCount++;
          debugPrint('[RepCounter] DESCENDING→STANDING REP #$_repCount at frame=$_frameIndex '
              'smoothed=${smoothedAngle.toStringAsFixed(1)} descent=$_descentFrameCount '
              '(threshold: >${(_standingAngle + _hysteresisMargin).toStringAsFixed(0)})');
          _phase = RdlPhase.standing;
          return true;
        }
        return false;
    }
  }

  double? _smoothedAngle() {
    if (_angleBuffer.isEmpty) return null;
    final sorted = List<double>.from(_angleBuffer)..sort();
    // Median filter — more robust to outliers than arithmetic mean.
    return sorted[sorted.length ~/ 2];
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
