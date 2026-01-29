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

/// Label assigned to a detected object by the ML model
/// Agnostic - contains raw classification output without interpretation
class ObjectLabel extends Equatable {
  /// The label text as returned by ML Kit (e.g., "Person", "Chair", "Dog")
  final String text;

  /// Confidence score for this label (0.0 to 1.0)
  final double confidence;

  /// Optional index/category ID from the model
  final int? index;

  const ObjectLabel({
    required this.text,
    required this.confidence,
    this.index,
  });

  @override
  List<Object?> get props => [text, confidence, index];

  @override
  String toString() => 'Label($text: ${confidence.toStringAsFixed(2)})';
}

/// A single detected object from object detection
/// Agnostic - no knowledge of what the object represents semantically
class DetectedObjectData extends Equatable {
  /// Bounding box in normalized coordinates
  final NormalizedBoundingBox bounds;

  /// All labels assigned to this object by the classifier
  final List<ObjectLabel> labels;

  /// Optional tracking ID for object persistence across frames
  final int? trackingId;

  const DetectedObjectData({
    required this.bounds,
    required this.labels,
    this.trackingId,
  });

  /// Get the primary (highest confidence) label
  ObjectLabel? get primaryLabel {
    if (labels.isEmpty) return null;
    return labels.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  /// Check if this object has a specific label (case-insensitive)
  bool hasLabel(String labelText) {
    final searchText = labelText.toLowerCase();
    return labels.any((l) => l.text.toLowerCase() == searchText);
  }

  /// Get confidence for a specific label (returns 0.0 if not found)
  double confidenceForLabel(String labelText) {
    final searchText = labelText.toLowerCase();
    for (final label in labels) {
      if (label.text.toLowerCase() == searchText) {
        return label.confidence;
      }
    }
    return 0.0;
  }

  @override
  List<Object?> get props => [bounds, labels, trackingId];

  @override
  String toString() =>
      'DetectedObject(${primaryLabel?.text ?? "unknown"}, ${bounds.area.toStringAsFixed(3)})';
}

/// Result of object detection for a single frame
/// Agnostic - contains all detected objects without filtering or interpretation
class ObjectDetectionResult extends Equatable {
  /// All objects detected in the frame
  final List<DetectedObjectData> objects;

  /// Processing latency in milliseconds
  final double detectionLatencyMs;

  /// Image dimensions used for normalization
  final double imageWidth;
  final double imageHeight;

  const ObjectDetectionResult({
    required this.objects,
    required this.detectionLatencyMs,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Number of objects detected
  int get objectCount => objects.length;

  /// Whether any objects were detected
  bool get hasObjects => objects.isNotEmpty;

  /// Filter objects by label (for use in Domain layer interpretation)
  List<DetectedObjectData> objectsWithLabel(String labelText) {
    return objects.where((obj) => obj.hasLabel(labelText)).toList();
  }

  /// Get the largest object by bounding box area
  DetectedObjectData? get largestObject {
    if (objects.isEmpty) return null;
    return objects.reduce((a, b) => a.bounds.area > b.bounds.area ? a : b);
  }

  @override
  List<Object?> get props => [objects, detectionLatencyMs, imageWidth, imageHeight];

  @override
  String toString() =>
      'ObjectDetectionResult(${objects.length} objects, ${detectionLatencyMs.toStringAsFixed(1)}ms)';
}
