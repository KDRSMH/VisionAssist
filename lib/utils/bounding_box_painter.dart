import 'package:flutter/material.dart';
import '../models/detection_result.dart';

/// Custom painter for drawing bounding boxes over detected objects
///
/// Color coding:
/// - RED: High priority/danger objects (vehicles, stairs)
/// - GREEN: Regular objects
/// - YELLOW: Medium priority objects
class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size previewSize;

  BoundingBoxPainter({required this.detections, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    // Calculate scaling factors to map preview coordinates to screen coordinates
    final double scaleX = size.width / previewSize.height;
    final double scaleY = size.height / previewSize.width;

    for (final detection in detections) {
      // Scale bounding box to screen size
      final rect = Rect.fromLTWH(
        detection.x * scaleX,
        detection.y * scaleY,
        detection.width * scaleX,
        detection.height * scaleY,
      );

      // Color based on priority
      final boxColor = _getColorForDetection(detection);

      // Draw bounding box
      final paint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      canvas.drawRect(rect, paint);

      // Draw filled background for label
      final labelBgPaint = Paint()
        ..color = boxColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      const labelPadding = 8.0;
      final textSpan = TextSpan(
        text:
            '${detection.turkishLabel} ${(detection.confidence * 100).toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - labelPadding * 2,
        textPainter.width + labelPadding * 2,
        textPainter.height + labelPadding * 2,
      );

      canvas.drawRect(labelRect, labelBgPaint);

      // Draw label text
      textPainter.paint(
        canvas,
        Offset(
          rect.left + labelPadding,
          rect.top - textPainter.height - labelPadding,
        ),
      );

      // Draw corner highlights for better visibility
      _drawCornerHighlights(canvas, rect, boxColor);
    }
  }

  /// Get color based on object priority
  Color _getColorForDetection(DetectionResult detection) {
    switch (detection.priority) {
      case DetectionPriority.high:
        return Colors.red; // Danger: vehicles, stairs
      case DetectionPriority.medium:
        return Colors.yellow; // Caution: animals, bicycles
      case DetectionPriority.low:
        return Colors.green; // Regular objects
    }
  }

  /// Draw corner highlights for better box visibility
  void _drawCornerHighlights(Canvas canvas, Rect rect, Color color) {
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left, rect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right - cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right - cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}
