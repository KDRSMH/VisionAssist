/// Detection result model for YOLOv5 object detection
class Detection {
  final int classId;
  final String label;
  final double confidence;
  final double x; // Top-left x coordinate
  final double y; // Top-left y coordinate
  final double width; // Bounding box width
  final double height; // Bounding box height

  Detection({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // Getter for bottom-right coordinates
  double get x2 => x + width;
  double get y2 => y + height;

  // Getter for center coordinates
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  // Getter for area
  double get area => width * height;

  @override
  String toString() {
    return 'Detection(label: $label, conf: ${(confidence * 100).toStringAsFixed(1)}%, '
        'box: [${x.toInt()}, ${y.toInt()}, ${width.toInt()}, ${height.toInt()}])';
  }

  Map<String, dynamic> toJson() => {
    'classId': classId,
    'label': label,
    'confidence': confidence,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    classId: json['classId'] as int,
    label: json['label'] as String,
    confidence: json['confidence'] as double,
    x: json['x'] as double,
    y: json['y'] as double,
    width: json['width'] as double,
    height: json['height'] as double,
  );
}
