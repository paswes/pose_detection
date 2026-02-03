import 'package:pose_detection/domain/models/detected_pose.dart';
import 'package:pose_detection/domain/models/landmark.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/vector3.dart';
import 'package:pose_detection/domain/motion/models/velocity.dart';

/// Service for tracking velocities of landmarks and joint angles.
///
/// Calculates instantaneous and smoothed velocities for movement analysis.
/// Exercise-agnostic - measures movement speed without knowledge of
/// specific exercises or movements.
class VelocityTracker {
  // Store previous poses/angles for velocity calculation
  DetectedPose? _previousPose;
  final Map<String, JointAngle> _previousAngles = {};

  // Smoothed velocities (optional low-pass filtering)
  final Map<int, Velocity> _smoothedLandmarkVelocities = {};
  final Map<String, AngularVelocity> _smoothedAngularVelocities = {};

  /// Smoothing factor for velocity (0 = no smoothing, 1 = full smoothing)
  final double smoothingFactor;

  /// Minimum confidence required for velocity calculation
  final double minConfidence;

  VelocityTracker({
    this.smoothingFactor = 0.3,
    this.minConfidence = 0.3,
  });

  /// Update the tracker with a new pose and calculate velocities.
  ///
  /// Returns a map of landmark IDs to their calculated velocities.
  Map<int, Velocity> updatePose(DetectedPose pose) {
    final velocities = <int, Velocity>{};

    if (_previousPose != null) {
      final dtMicros = pose.timestampMicros - _previousPose!.timestampMicros;
      if (dtMicros > 0) {
        final dtSeconds = dtMicros / 1000000.0;

        for (final landmark in pose.landmarks) {
          final velocity = _calculateLandmarkVelocity(
            current: landmark,
            previous: _previousPose!.landmarks
                .where((l) => l.id == landmark.id)
                .firstOrNull,
            dtSeconds: dtSeconds,
            timestampMicros: pose.timestampMicros,
          );

          if (velocity != null) {
            // Apply smoothing if we have previous velocity
            final smoothed = _smoothVelocity(velocity);
            velocities[landmark.id] = smoothed;
            _smoothedLandmarkVelocities[landmark.id] = smoothed;
          }
        }
      }
    }

    _previousPose = pose;
    return velocities;
  }

  /// Update with new joint angles and calculate angular velocities.
  Map<String, AngularVelocity> updateAngles(
    Map<String, JointAngle> angles,
    int timestampMicros,
  ) {
    final angularVelocities = <String, AngularVelocity>{};

    for (final entry in angles.entries) {
      final jointId = entry.key;
      final angle = entry.value;
      final previousAngle = _previousAngles[jointId];

      if (previousAngle != null) {
        final dtMicros = timestampMicros - previousAngle.timestampMicros;
        if (dtMicros > 0) {
          final dtSeconds = dtMicros / 1000000.0;
          final deltaRadians = angle.radians - previousAngle.radians;

          final avgConfidence = (angle.confidence + previousAngle.confidence) / 2;

          final angularVel = AngularVelocity(
            jointId: jointId,
            radiansPerSecond: deltaRadians / dtSeconds,
            timestampMicros: timestampMicros,
            deltaTimeSeconds: dtSeconds,
            confidence: avgConfidence,
          );

          // Apply smoothing
          final smoothed = _smoothAngularVelocity(angularVel);
          angularVelocities[jointId] = smoothed;
          _smoothedAngularVelocities[jointId] = smoothed;
        }
      }

      _previousAngles[jointId] = angle;
    }

    return angularVelocities;
  }

  /// Get the current smoothed velocity for a landmark
  Velocity? getLandmarkVelocity(int landmarkId) {
    return _smoothedLandmarkVelocities[landmarkId];
  }

  /// Get all current landmark velocities
  Map<int, Velocity> get allLandmarkVelocities =>
      Map.unmodifiable(_smoothedLandmarkVelocities);

  /// Get the current smoothed angular velocity for a joint
  AngularVelocity? getAngularVelocity(String jointId) {
    return _smoothedAngularVelocities[jointId];
  }

  /// Get all current angular velocities
  Map<String, AngularVelocity> get allAngularVelocities =>
      Map.unmodifiable(_smoothedAngularVelocities);

  /// Get the fastest moving landmark
  Velocity? get fastestLandmark {
    Velocity? fastest;
    double maxSpeed = 0;

    for (final velocity in _smoothedLandmarkVelocities.values) {
      if (velocity.speed > maxSpeed) {
        maxSpeed = velocity.speed;
        fastest = velocity;
      }
    }

    return fastest;
  }

  /// Get average body speed (average of all landmark speeds)
  double get averageBodySpeed {
    if (_smoothedLandmarkVelocities.isEmpty) return 0;

    double totalSpeed = 0;
    for (final velocity in _smoothedLandmarkVelocities.values) {
      totalSpeed += velocity.speed;
    }

    return totalSpeed / _smoothedLandmarkVelocities.length;
  }

  /// Check if the body is approximately stationary
  bool isStationary({double threshold = 20.0}) {
    return averageBodySpeed < threshold;
  }

  /// Get the primary movement direction (based on center of mass velocity)
  Vector3? get primaryMovementDirection {
    if (_smoothedLandmarkVelocities.isEmpty) return null;

    // Calculate average velocity across key body landmarks
    // (shoulders and hips for center of mass approximation)
    const keyLandmarks = [11, 12, 23, 24]; // shoulders and hips
    var totalVelocity = Vector3.zero;
    int count = 0;

    for (final id in keyLandmarks) {
      final velocity = _smoothedLandmarkVelocities[id];
      if (velocity != null) {
        totalVelocity = totalVelocity + velocity.velocity;
        count++;
      }
    }

    if (count == 0) return null;
    return (totalVelocity / count.toDouble()).normalized;
  }

  /// Reset all tracking state
  void reset() {
    _previousPose = null;
    _previousAngles.clear();
    _smoothedLandmarkVelocities.clear();
    _smoothedAngularVelocities.clear();
  }

  /// Calculate velocity for a single landmark
  Velocity? _calculateLandmarkVelocity({
    required Landmark current,
    required Landmark? previous,
    required double dtSeconds,
    required int timestampMicros,
  }) {
    if (previous == null) return null;

    // Check confidence
    final avgConfidence = (current.confidence + previous.confidence) / 2;
    if (avgConfidence < minConfidence) return null;

    // Calculate velocity vector
    final dx = current.x - previous.x;
    final dy = current.y - previous.y;
    final dz = current.z - previous.z;

    return Velocity(
      pointId: current.id,
      velocity: Vector3(dx / dtSeconds, dy / dtSeconds, dz / dtSeconds),
      timestampMicros: timestampMicros,
      deltaTimeSeconds: dtSeconds,
      confidence: avgConfidence,
    );
  }

  /// Apply exponential smoothing to velocity
  Velocity _smoothVelocity(Velocity newVelocity) {
    final previous = _smoothedLandmarkVelocities[newVelocity.pointId];
    if (previous == null || smoothingFactor <= 0) {
      return newVelocity;
    }

    // Exponential moving average
    final smoothedVel = Vector3(
      previous.velocity.x * smoothingFactor +
          newVelocity.velocity.x * (1 - smoothingFactor),
      previous.velocity.y * smoothingFactor +
          newVelocity.velocity.y * (1 - smoothingFactor),
      previous.velocity.z * smoothingFactor +
          newVelocity.velocity.z * (1 - smoothingFactor),
    );

    return Velocity(
      pointId: newVelocity.pointId,
      velocity: smoothedVel,
      timestampMicros: newVelocity.timestampMicros,
      deltaTimeSeconds: newVelocity.deltaTimeSeconds,
      confidence: newVelocity.confidence,
    );
  }

  /// Apply exponential smoothing to angular velocity
  AngularVelocity _smoothAngularVelocity(AngularVelocity newVelocity) {
    final previous = _smoothedAngularVelocities[newVelocity.jointId];
    if (previous == null || smoothingFactor <= 0) {
      return newVelocity;
    }

    // Exponential moving average
    final smoothedRadPerSec = previous.radiansPerSecond * smoothingFactor +
        newVelocity.radiansPerSecond * (1 - smoothingFactor);

    return AngularVelocity(
      jointId: newVelocity.jointId,
      radiansPerSecond: smoothedRadPerSec,
      timestampMicros: newVelocity.timestampMicros,
      deltaTimeSeconds: newVelocity.deltaTimeSeconds,
      confidence: newVelocity.confidence,
    );
  }
}

/// Interface for velocity tracking
abstract class IVelocityTracker {
  Map<int, Velocity> updatePose(DetectedPose pose);
  Map<String, AngularVelocity> updateAngles(
    Map<String, JointAngle> angles,
    int timestampMicros,
  );
  Velocity? getLandmarkVelocity(int landmarkId);
  AngularVelocity? getAngularVelocity(String jointId);
  void reset();
}
