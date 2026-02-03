import 'dart:math' as math;

/// Immutable 3D vector for geometric calculations.
/// Used for landmark positions, velocities, and angle computations.
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  /// Zero vector
  static const zero = Vector3(0, 0, 0);

  /// Create from two points (end - start)
  factory Vector3.fromPoints(Vector3 start, Vector3 end) {
    return Vector3(end.x - start.x, end.y - start.y, end.z - start.z);
  }

  /// Vector magnitude (length)
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  /// Squared magnitude (faster, avoids sqrt)
  double get magnitudeSquared => x * x + y * y + z * z;

  /// 2D magnitude (ignoring Z)
  double get magnitude2D => math.sqrt(x * x + y * y);

  /// Unit vector (normalized to length 1)
  Vector3 get normalized {
    final mag = magnitude;
    if (mag == 0) return zero;
    return Vector3(x / mag, y / mag, z / mag);
  }

  /// Dot product with another vector
  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  /// Cross product with another vector
  Vector3 cross(Vector3 other) {
    return Vector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  /// Distance to another point
  double distanceTo(Vector3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// 2D distance (ignoring Z)
  double distanceTo2D(Vector3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Angle between this vector and another (in radians)
  double angleTo(Vector3 other) {
    final dotProduct = dot(other);
    final magnitudes = magnitude * other.magnitude;
    if (magnitudes == 0) return 0;
    // Clamp to avoid NaN from floating point errors
    final cosAngle = (dotProduct / magnitudes).clamp(-1.0, 1.0);
    return math.acos(cosAngle);
  }

  /// Angle between this vector and another (in degrees)
  double angleToInDegrees(Vector3 other) {
    return angleTo(other) * 180 / math.pi;
  }

  /// Vector addition
  Vector3 operator +(Vector3 other) {
    return Vector3(x + other.x, y + other.y, z + other.z);
  }

  /// Vector subtraction
  Vector3 operator -(Vector3 other) {
    return Vector3(x - other.x, y - other.y, z - other.z);
  }

  /// Scalar multiplication
  Vector3 operator *(double scalar) {
    return Vector3(x * scalar, y * scalar, z * scalar);
  }

  /// Scalar division
  Vector3 operator /(double scalar) {
    return Vector3(x / scalar, y / scalar, z / scalar);
  }

  /// Negation
  Vector3 operator -() => Vector3(-x, -y, -z);

  /// Linear interpolation between two vectors
  static Vector3 lerp(Vector3 a, Vector3 b, double t) {
    return Vector3(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
      a.z + (b.z - a.z) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vector3($x, $y, $z)';
}
