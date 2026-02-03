import 'dart:math' as math;

/// Immutable 3D vector for motion tracking calculations.
/// Provider-agnostic representation of position, velocity, or direction.
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  /// Zero vector
  static const zero = Vector3(0, 0, 0);

  /// Unit vectors
  static const unitX = Vector3(1, 0, 0);
  static const unitY = Vector3(0, 1, 0);
  static const unitZ = Vector3(0, 0, 1);

  /// Create from a landmark's position
  factory Vector3.fromPosition(double x, double y, double z) {
    return Vector3(x, y, z);
  }

  /// Vector magnitude (length)
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  /// Squared magnitude (faster when comparing distances)
  double get magnitudeSquared => x * x + y * y + z * z;

  /// 2D magnitude (ignoring Z)
  double get magnitude2D => math.sqrt(x * x + y * y);

  /// Normalized vector (unit length)
  Vector3 get normalized {
    final mag = magnitude;
    if (mag == 0) return zero;
    return Vector3(x / mag, y / mag, z / mag);
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
  Vector3 operator -() {
    return Vector3(-x, -y, -z);
  }

  /// Dot product
  double dot(Vector3 other) {
    return x * other.x + y * other.y + z * other.z;
  }

  /// Cross product
  Vector3 cross(Vector3 other) {
    return Vector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  /// Distance to another point
  double distanceTo(Vector3 other) {
    return (this - other).magnitude;
  }

  /// 2D distance (ignoring Z)
  double distanceTo2D(Vector3 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Linear interpolation to another vector
  Vector3 lerp(Vector3 other, double t) {
    return Vector3(
      x + (other.x - x) * t,
      y + (other.y - y) * t,
      z + (other.z - z) * t,
    );
  }

  /// Angle between this and another vector (radians)
  double angleTo(Vector3 other) {
    final d = dot(other);
    final m = magnitude * other.magnitude;
    if (m == 0) return 0;
    return math.acos((d / m).clamp(-1.0, 1.0));
  }

  /// Project this vector onto another vector
  Vector3 projectOnto(Vector3 other) {
    final otherMagSq = other.magnitudeSquared;
    if (otherMagSq == 0) return zero;
    final scalar = dot(other) / otherMagSq;
    return other * scalar;
  }

  /// Reflect this vector off a surface with the given normal
  Vector3 reflect(Vector3 normal) {
    return this - normal * (2 * dot(normal));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vector3 && x == other.x && y == other.y && z == other.z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vector3($x, $y, $z)';

  /// Convert to a simple map for serialization
  Map<String, double> toMap() => {'x': x, 'y': y, 'z': z};

  /// Create from a map
  factory Vector3.fromMap(Map<String, dynamic> map) {
    return Vector3(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['z'] as num).toDouble(),
    );
  }
}
