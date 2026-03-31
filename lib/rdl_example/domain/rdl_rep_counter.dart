import 'dart:math';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

/// Phase of a single RDL repetition.
enum RdlPhase { standing, descending }

/// Per-rep analytics data captured during RDL tracking.
class RdlRepData {
  final int repNumber;
  final double minHipAngle;
  final int startFrameIndex;
  final int bottomFrameIndex;
  final int endFrameIndex;
  final Duration descentDuration;
  final Duration totalDuration;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? leftKneeAngle;
  final double? rightKneeAngle;

  const RdlRepData({
    required this.repNumber,
    required this.minHipAngle,
    required this.startFrameIndex,
    required this.bottomFrameIndex,
    required this.endFrameIndex,
    required this.descentDuration,
    required this.totalDuration,
    this.leftHipAngle,
    this.rightHipAngle,
    this.leftKneeAngle,
    this.rightKneeAngle,
  });

  /// Absolute difference between left and right hip angles (degrees).
  double? get hipAsymmetry {
    if (leftHipAngle == null || rightHipAngle == null) return null;
    return (leftHipAngle! - rightHipAngle!).abs();
  }
}

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

  /// Angle drop from peak required to mark descent onset.
  /// Small enough to catch early movement, large enough to ignore sensor noise.
  static const _onsetThreshold = 3.0;

  /// Max recent angle entries to keep for backtracking (~2s at 30 FPS).
  static const _recentAnglesCapacity = 60;

  int _repCount = 0;
  RdlPhase _phase = RdlPhase.standing;
  double? _currentAngle;
  final List<double> _angleBuffer = [];

  /// Recent (frameIndex, rawAngle) pairs for backtracking descent onset.
  final List<(int, double)> _recentAngles = [];

  /// Frames spent in the current descending phase.
  int _descentFrameCount = 0;

  /// Consecutive null-angle frames.
  int _nullStreak = 0;

  /// Max consecutive null frames before clearing the angle buffer.
  /// At 30 FPS, 15 frames = 500ms — brief occlusions won't reset state.
  static const _maxNullStreak = 15;

  // Per-rep tracking state
  final List<RdlRepData> _reps = [];
  int _descentStartFrameIndex = 0;
  int _descentStartTimestampMicros = 0;
  double _minAngleDuringDescent = double.infinity;
  int _bottomFrameIndex = 0;
  int _bottomTimestampMicros = 0;
  TrackedFrame? _bottomFrame;

  int get repCount => _repCount;
  RdlPhase get phase => _phase;
  double? get currentAngle => _currentAngle;
  List<RdlRepData> get reps => List.unmodifiable(_reps);

  int _frameIndex = 0;

  /// Process a single frame. Returns `true` if the rep count changed.
  ///
  /// [globalFrameIndex] is the index into the full frames list (for rep data).
  bool processFrame(TrackedFrame frame, {int? globalFrameIndex}) {
    final angle = calculateHipAngle(frame);
    _currentAngle = angle;
    _frameIndex++;
    final frameIdx = globalFrameIndex ?? (_frameIndex - 1);

    if (angle == null) {
      _nullStreak++;
      if (_nullStreak >= _maxNullStreak) {
        _angleBuffer.clear();
      }
      return false;
    }

    _nullStreak = 0;

    // Store for descent onset backtracking
    _recentAngles.add((frameIdx, angle));
    if (_recentAngles.length > _recentAnglesCapacity) {
      _recentAngles.removeAt(0);
    }

    _angleBuffer.add(angle);
    if (_angleBuffer.length > _smoothingWindow) {
      _angleBuffer.removeAt(0);
    }

    final smoothed = _smoothedAngle();
    if (smoothed == null) return false;

    // Track min angle during descent
    if (_phase == RdlPhase.descending && smoothed < _minAngleDuringDescent) {
      _minAngleDuringDescent = smoothed;
      _bottomFrameIndex = frameIdx;
      _bottomTimestampMicros = frame.timestampMicros;
      _bottomFrame = frame;
    }

    return _updatePhase(smoothed, frameIdx, frame);
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
      processFrame(frames[i], globalFrameIndex: i);
    }
  }

  /// Replay frames 0..[targetIndex] to get the correct rep count
  /// at any arbitrary position (handles backward seeks).
  void countRepsUpTo(List<TrackedFrame> frames, int targetIndex) {
    reset();
    final end = targetIndex.clamp(0, frames.length - 1);
    for (int i = 0; i <= end; i++) {
      processFrame(frames[i], globalFrameIndex: i);
    }
  }

  /// Reset all state to initial values.
  void reset() {
    _repCount = 0;
    _phase = RdlPhase.standing;
    _currentAngle = null;
    _angleBuffer.clear();
    _recentAngles.clear();
    _descentFrameCount = 0;
    _nullStreak = 0;
    _frameIndex = 0;
    _reps.clear();
    _descentStartFrameIndex = 0;
    _descentStartTimestampMicros = 0;
    _minAngleDuringDescent = double.infinity;
    _bottomFrameIndex = 0;
    _bottomTimestampMicros = 0;
    _bottomFrame = null;
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

  /// Calculate hip angle using only one side's landmarks.
  /// shoulder → hip → knee for the specified side.
  static double? calculateSideHipAngle(
    TrackedFrame frame, {
    required bool left,
  }) {
    if (!frame.isPersonDetected) return null;

    final shoulder = _findLandmark(
      frame,
      left ? LandmarkSchema.leftShoulder : LandmarkSchema.rightShoulder,
    );
    final hip = _findLandmark(
      frame,
      left ? LandmarkSchema.leftHip : LandmarkSchema.rightHip,
    );
    final knee = _findLandmark(
      frame,
      left ? LandmarkSchema.leftKnee : LandmarkSchema.rightKnee,
    );

    if (shoulder == null || hip == null || knee == null) return null;

    return _angle3Point(
      shoulder.x,
      shoulder.y,
      hip.x,
      hip.y,
      knee.x,
      knee.y,
    );
  }

  /// Calculate torso lean angle relative to vertical.
  ///
  /// Returns degrees from vertical (0° = perfectly upright,
  /// larger values = more forward lean).
  /// Uses shoulder-center → hip-center line vs vertical.
  /// Returns `null` if required landmarks are missing or low-confidence.
  static double? calculateTorsoLean(TrackedFrame frame) {
    if (!frame.isPersonDetected) return null;

    final lShoulder = _findLandmark(frame, LandmarkSchema.leftShoulder);
    final rShoulder = _findLandmark(frame, LandmarkSchema.rightShoulder);
    final lHip = _findLandmark(frame, LandmarkSchema.leftHip);
    final rHip = _findLandmark(frame, LandmarkSchema.rightHip);

    if (lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null) {
      return null;
    }

    final sx = (lShoulder.x + rShoulder.x) / 2;
    final sy = (lShoulder.y + rShoulder.y) / 2;
    final hx = (lHip.x + rHip.x) / 2;
    final hy = (lHip.y + rHip.y) / 2;

    // Angle between shoulder→hip line and vertical.
    // In image coords, Y increases downward, so hip is below shoulder.
    // atan2(dx, dy) gives angle from vertical (0° = straight down = upright).
    final dx = hx - sx;
    final dy = hy - sy;
    return atan2(dx.abs(), dy.abs()) * (180.0 / pi);
  }

  /// Calculate knee angle using one side's landmarks.
  /// hip → knee → ankle for the specified side.
  static double? calculateKneeAngle(
    TrackedFrame frame, {
    required bool left,
  }) {
    if (!frame.isPersonDetected) return null;

    final hip = _findLandmark(
      frame,
      left ? LandmarkSchema.leftHip : LandmarkSchema.rightHip,
    );
    final knee = _findLandmark(
      frame,
      left ? LandmarkSchema.leftKnee : LandmarkSchema.rightKnee,
    );
    final ankle = _findLandmark(
      frame,
      left ? LandmarkSchema.leftAnkle : LandmarkSchema.rightAnkle,
    );

    if (hip == null || knee == null || ankle == null) return null;

    return _angle3Point(
      hip.x,
      hip.y,
      knee.x,
      knee.y,
      ankle.x,
      ankle.y,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Update the state machine. Returns `true` if a rep was counted.
  bool _updatePhase(
    double smoothedAngle,
    int frameIdx,
    TrackedFrame frame,
  ) {
    switch (_phase) {
      case RdlPhase.standing:
        if (smoothedAngle < _hingeAngle - _hysteresisMargin) {
          final onsetFrameIdx = _findDescentOnset(frameIdx);
          _phase = RdlPhase.descending;
          _descentFrameCount = 0;
          _descentStartFrameIndex = onsetFrameIdx;
          _descentStartTimestampMicros = frame.timestampMicros;
          _minAngleDuringDescent = smoothedAngle;
          _bottomFrameIndex = frameIdx;
          _bottomTimestampMicros = frame.timestampMicros;
          _bottomFrame = frame;
        }
        return false;

      case RdlPhase.descending:
        _descentFrameCount++;
        if (smoothedAngle > _standingAngle + _hysteresisMargin &&
            _descentFrameCount >= _minDescentFrames) {
          _repCount++;

          // Snapshot per-rep data
          final bottomFrame = _bottomFrame;
          _reps.add(
            RdlRepData(
              repNumber: _repCount,
              minHipAngle: _minAngleDuringDescent,
              startFrameIndex: _descentStartFrameIndex,
              bottomFrameIndex: _bottomFrameIndex,
              endFrameIndex: frameIdx,
              descentDuration: Duration(
                microseconds:
                    _bottomTimestampMicros - _descentStartTimestampMicros,
              ),
              totalDuration: Duration(
                microseconds:
                    frame.timestampMicros - _descentStartTimestampMicros,
              ),
              leftHipAngle: bottomFrame != null
                  ? calculateSideHipAngle(bottomFrame, left: true)
                  : null,
              rightHipAngle: bottomFrame != null
                  ? calculateSideHipAngle(bottomFrame, left: false)
                  : null,
              leftKneeAngle: bottomFrame != null
                  ? calculateKneeAngle(bottomFrame, left: true)
                  : null,
              rightKneeAngle: bottomFrame != null
                  ? calculateKneeAngle(bottomFrame, left: false)
                  : null,
            ),
          );

          _phase = RdlPhase.standing;
          return true;
        }
        return false;
    }
  }

  /// Walk backward through recent angles to find where descent truly began.
  ///
  /// Finds the local peak angle before the transition, then scans forward
  /// to the first frame where the angle drops by [_onsetThreshold] from
  /// that peak. Falls back to [transitionFrameIdx] if the buffer is empty.
  int _findDescentOnset(int transitionFrameIdx) {
    if (_recentAngles.isEmpty) return transitionFrameIdx;

    // Find the peak angle in the buffer (highest = most upright)
    int peakIdx = 0;
    double peakAngle = _recentAngles[0].$2;
    for (int i = 1; i < _recentAngles.length; i++) {
      if (_recentAngles[i].$2 > peakAngle) {
        peakAngle = _recentAngles[i].$2;
        peakIdx = i;
      }
    }

    // Scan forward from peak to find first frame where angle drops
    // below peak - threshold (= movement onset)
    final threshold = peakAngle - _onsetThreshold;
    for (int i = peakIdx + 1; i < _recentAngles.length; i++) {
      if (_recentAngles[i].$2 < threshold) {
        return _recentAngles[i].$1;
      }
    }

    // No clear onset found — use the transition frame
    return transitionFrameIdx;
  }

  double? _smoothedAngle() {
    if (_angleBuffer.isEmpty) return null;
    final sorted = List<double>.from(_angleBuffer)..sort();
    // Median filter — more robust to outliers than arithmetic mean.
    return sorted[sorted.length ~/ 2];
  }

  /// Find a landmark by ID with minimum confidence, or return `null`.
  static Landmark? _findLandmark(TrackedFrame frame, int id) {
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
