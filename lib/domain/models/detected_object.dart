import 'package:equatable/equatable.dart';

/// Agnostic bounding box in normalized coordinates (0.0 to 1.0)
/// Part of the Core-to-Domain data contract
class NormalizedBoundingBox extends Equatable {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const NormalizedBoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  /// Check if a point (normalized coordinates) is inside this bounding box
  bool containsPoint(double x, double y) {
    return x >= left && x <= right && y >= top && y <= bottom;
  }

  /// Check if another bounding box overlaps with this one
  bool overlaps(NormalizedBoundingBox other) {
    return !(other.left > right ||
        other.right < left ||
        other.top > bottom ||
        other.bottom < top);
  }

  /// Calculate Intersection over Union (IoU) with another bounding box
  double iou(NormalizedBoundingBox other) {
    if (!overlaps(other)) return 0.0;

    final intersectLeft = left > other.left ? left : other.left;
    final intersectTop = top > other.top ? top : other.top;
    final intersectRight = right < other.right ? right : other.right;
    final intersectBottom = bottom < other.bottom ? bottom : other.bottom;

    final intersectionArea =
        (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final unionArea = area + other.area - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  @override
  List<Object?> get props => [left, top, right, bottom];

  @override
  String toString() =>
      'BBox(${left.toStringAsFixed(3)}, ${top.toStringAsFixed(3)}, '
      '${right.toStringAsFixed(3)}, ${bottom.toStringAsFixed(3)})';
}
