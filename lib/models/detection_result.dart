/// Detection result model representing a detected object
///
/// Contains:
/// - Bounding box coordinates (x, y, width, height)
/// - Confidence score
/// - Class label (English and Turkish)
/// - Priority level for TTS announcements
class DetectionResult {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final String label;
  final String turkishLabel;
  final int classId;
  final DetectionPriority priority;

  DetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.label,
    required this.turkishLabel,
    required this.classId,
    required this.priority,
  });

  /// Calculate area of bounding box (used for sorting by proximity)
  double get area => width * height;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectionResult &&
        other.label == label &&
        other.confidence == confidence &&
        (other.x - x).abs() < 10 &&
        (other.y - y).abs() < 10;
  }

  @override
  int get hashCode => Object.hash(label, confidence, x ~/ 10, y ~/ 10);

  @override
  String toString() {
    return 'DetectionResult(label: $turkishLabel, confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'position: ($x, $y), size: ($width x $height), priority: $priority)';
  }
}

/// Priority levels for object detection
/// Used for sorting and TTS announcements
enum DetectionPriority {
  high, // Danger objects: vehicles, stairs
  medium, // Caution: animals, bicycles
  low, // Regular objects
}
