class Landmark {
  final int id;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const Landmark({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'z': z,
    'c': likelihood,
  };

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      likelihood: (json['c'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'Landmark($id: $x, $y, $z @ ${likelihood.toStringAsFixed(2)})';
}
