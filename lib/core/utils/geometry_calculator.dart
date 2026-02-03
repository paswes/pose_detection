import 'dart:math' as math;

import 'package:pose_detection/core/utils/vector3.dart';
import 'package:pose_detection/domain/models/landmark.dart';

/// Geometry utilities for pose analysis.
/// Provides angle and distance calculations from landmarks.
class GeometryCalculator {
  const GeometryCalculator._();

  /// Convert a Landmark to Vector3 for math operations.
  static Vector3 toVector3(Landmark landmark) {
    return Vector3(landmark.x, landmark.y, landmark.z);
  }

  /// Calculate angle at vertex B formed by points A-B-C (in degrees).
  /// Returns angle in range [0, 180].
  ///
  /// Example: For elbow angle, A=shoulder, B=elbow, C=wrist
  static double angleBetweenPoints(
    Landmark a,
    Landmark b,
    Landmark c,
  ) {
    final vecBA = Vector3.fromPoints(toVector3(b), toVector3(a));
    final vecBC = Vector3.fromPoints(toVector3(b), toVector3(c));
    return vecBA.angleToInDegrees(vecBC);
  }

  /// Calculate 2D angle at vertex B (ignoring Z coordinate).
  /// Useful when depth data is unreliable.
  static double angleBetweenPoints2D(
    Landmark a,
    Landmark b,
    Landmark c,
  ) {
    final ba = Vector3(a.x - b.x, a.y - b.y, 0);
    final bc = Vector3(c.x - b.x, c.y - b.y, 0);
    return ba.angleToInDegrees(bc);
  }

  /// Calculate 3D distance between two landmarks.
  static double distance3D(Landmark a, Landmark b) {
    return toVector3(a).distanceTo(toVector3(b));
  }

  /// Calculate 2D distance between two landmarks (ignoring Z).
  static double distance2D(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate midpoint between two landmarks.
  static Vector3 midpoint(Landmark a, Landmark b) {
    return Vector3(
      (a.x + b.x) / 2,
      (a.y + b.y) / 2,
      (a.z + b.z) / 2,
    );
  }

  /// Calculate the signed angle from vertical (Y-axis) in 2D.
  /// Useful for posture analysis (lean angle).
  /// Returns angle in degrees: 0 = vertical, positive = leaning right.
  static double angleFromVertical2D(Landmark bottom, Landmark top) {
    final dx = top.x - bottom.x;
    final dy = bottom.y - top.y; // Flip because screen Y increases downward
    return math.atan2(dx, dy) * 180 / math.pi;
  }

  /// Calculate the signed angle from horizontal (X-axis) in 2D.
  /// Useful for shoulder/hip tilt analysis.
  /// Returns angle in degrees: 0 = horizontal, positive = tilted up to right.
  static double angleFromHorizontal2D(Landmark left, Landmark right) {
    final dx = right.x - left.x;
    final dy = left.y - right.y; // Flip because screen Y increases downward
    return math.atan2(dy, dx) * 180 / math.pi;
  }

  /// Check if a landmark has sufficient confidence for calculations.
  static bool isReliable(Landmark landmark, {double threshold = 0.5}) {
    return landmark.confidence >= threshold;
  }

  /// Check if all landmarks in a list are reliable.
  static bool areAllReliable(
    List<Landmark> landmarks, {
    double threshold = 0.5,
  }) {
    return landmarks.every((l) => l.confidence >= threshold);
  }

  /// Get minimum confidence among landmarks.
  static double minConfidence(List<Landmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;
    return landmarks.map((l) => l.confidence).reduce(math.min);
  }
}
