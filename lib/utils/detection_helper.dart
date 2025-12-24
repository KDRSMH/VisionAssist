import 'dart:math';
import '../models/detection_result.dart';

/// Helper class for YOLO detection processing
///
/// Handles:
/// - STEP 7: Parsing YOLO output tensor
/// - STEP 8: Non-Maximum Suppression (NMS)
/// - STEP 9: Priority sorting
/// - STEP 10: English to Turkish translation
class DetectionHelper {
  // COCO dataset class names (80 classes)
  static const List<String> _cocoLabels = [
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',
  ];

  /// STEP 10: English to Turkish translation map
  static const Map<String, String> _turkishTranslations = {
    'person': 'İnsan',
    'bicycle': 'Bisiklet',
    'car': 'Araba',
    'motorcycle': 'Motosiklet',
    'airplane': 'Uçak',
    'bus': 'Otobüs',
    'train': 'Tren',
    'truck': 'Kamyon',
    'boat': 'Tekne',
    'traffic light': 'Trafik ışığı',
    'fire hydrant': 'Yangın musluğu',
    'stop sign': 'Dur işareti',
    'parking meter': 'Parkmetre',
    'bench': 'Bank',
    'bird': 'Kuş',
    'cat': 'Kedi',
    'dog': 'Köpek',
    'horse': 'At',
    'sheep': 'Koyun',
    'cow': 'İnek',
    'elephant': 'Fil',
    'bear': 'Ayı',
    'zebra': 'Zebra',
    'giraffe': 'Zürafa',
    'backpack': 'Sırt çantası',
    'umbrella': 'Şemsiye',
    'handbag': 'El çantası',
    'tie': 'Kravat',
    'suitcase': 'Valiz',
    'frisbee': 'Frizbi',
    'skis': 'Kayak',
    'snowboard': 'Kar tahtası',
    'sports ball': 'Spor topu',
    'kite': 'Uçurtma',
    'baseball bat': 'Beyzbol sopası',
    'baseball glove': 'Beyzbol eldiveni',
    'skateboard': 'Kaykay',
    'surfboard': 'Sörf tahtası',
    'tennis racket': 'Tenis raketi',
    'bottle': 'Şişe',
    'wine glass': 'Şarap bardağı',
    'cup': 'Bardak',
    'fork': 'Çatal',
    'knife': 'Bıçak',
    'spoon': 'Kaşık',
    'bowl': 'Kase',
    'banana': 'Muz',
    'apple': 'Elma',
    'sandwich': 'Sandviç',
    'orange': 'Portakal',
    'broccoli': 'Brokoli',
    'carrot': 'Havuç',
    'hot dog': 'Sosisli',
    'pizza': 'Pizza',
    'donut': 'Donut',
    'cake': 'Kek',
    'chair': 'Sandalye',
    'couch': 'Kanepe',
    'potted plant': 'Saksı bitkisi',
    'bed': 'Yatak',
    'dining table': 'Yemek masası',
    'toilet': 'Tuvalet',
    'tv': 'Televizyon',
    'laptop': 'Dizüstü bilgisayar',
    'mouse': 'Fare',
    'remote': 'Kumanda',
    'keyboard': 'Klavye',
    'cell phone': 'Cep telefonu',
    'microwave': 'Mikrodalga',
    'oven': 'Fırın',
    'toaster': 'Ekmek kızartma makinesi',
    'sink': 'Lavabo',
    'refrigerator': 'Buzdolabı',
    'book': 'Kitap',
    'clock': 'Saat',
    'vase': 'Vazo',
    'scissors': 'Makas',
    'teddy bear': 'Oyuncak ayı',
    'hair drier': 'Saç kurutma makinesi',
    'toothbrush': 'Diş fırçası',
  };

  /// STEP 9: High priority objects (danger/obstacles)
  static const Set<String> _highPriorityObjects = {
    'car',
    'bus',
    'truck',
    'motorcycle',
    'bicycle',
    'train',
  };

  /// Medium priority objects
  static const Set<String> _mediumPriorityObjects = {
    'person',
    'dog',
    'cat',
    'horse',
  };

  /// STEP 7: Parse YOLO output tensor to detection results
  ///
  /// YOLOv5 output format: [25200, 85]
  /// - 25200: Number of predictions (grid cells)
  /// - 85: [x_center, y_center, width, height, objectness, ...80 class scores]
  static List<DetectionResult> parseYoloOutput(
    List<List<double>> output,
    int inputSize,
    int imageWidth,
    int imageHeight,
    double confidenceThreshold,
  ) {
    final detections = <DetectionResult>[];

    for (int i = 0; i < output.length; i++) {
      final prediction = output[i];

      // Extract objectness score
      final objectness = prediction[4];
      if (objectness < confidenceThreshold) continue;

      // Find class with highest score
      int maxClassId = 0;
      double maxClassScore = 0.0;

      for (int j = 0; j < 80; j++) {
        final classScore = prediction[5 + j];
        if (classScore > maxClassScore) {
          maxClassScore = classScore;
          maxClassId = j;
        }
      }

      // Calculate final confidence
      final confidence = objectness * maxClassScore;
      if (confidence < confidenceThreshold) continue;

      // Extract bounding box (YOLO format: center x, center y, width, height)
      final centerX = prediction[0];
      final centerY = prediction[1];
      final width = prediction[2];
      final height = prediction[3];

      // Convert from normalized [0, 1] to pixel coordinates
      final x = (centerX - width / 2) * imageWidth;
      final y = (centerY - height / 2) * imageHeight;
      final boxWidth = width * imageWidth;
      final boxHeight = height * imageHeight;

      // Get label
      final label = maxClassId < _cocoLabels.length
          ? _cocoLabels[maxClassId]
          : 'unknown';

      final turkishLabel = _turkishTranslations[label] ?? label;
      final priority = _getPriority(label);

      detections.add(
        DetectionResult(
          x: x,
          y: y,
          width: boxWidth,
          height: boxHeight,
          confidence: confidence,
          label: label,
          turkishLabel: turkishLabel,
          classId: maxClassId,
          priority: priority,
        ),
      );
    }

    return detections;
  }

  /// STEP 8: Non-Maximum Suppression (NMS)
  ///
  /// Removes overlapping bounding boxes
  /// IoU threshold: 0.45 (boxes with IoU > 0.45 are considered duplicates)
  static List<DetectionResult> nonMaxSuppression(
    List<DetectionResult> detections,
    double iouThreshold,
  ) {
    if (detections.isEmpty) return [];

    // Sort by confidence (descending)
    final sorted = List<DetectionResult>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <DetectionResult>[];
    final suppressed = <int>{};

    for (int i = 0; i < sorted.length; i++) {
      if (suppressed.contains(i)) continue;

      selected.add(sorted[i]);

      // Suppress overlapping boxes
      for (int j = i + 1; j < sorted.length; j++) {
        if (suppressed.contains(j)) continue;

        final iou = _calculateIoU(sorted[i], sorted[j]);
        if (iou > iouThreshold) {
          suppressed.add(j);
        }
      }
    }

    return selected;
  }

  /// Calculate Intersection over Union (IoU)
  static double _calculateIoU(DetectionResult a, DetectionResult b) {
    // Calculate intersection area
    final x1 = max(a.x, b.x);
    final y1 = max(a.y, b.y);
    final x2 = min(a.x + a.width, b.x + b.width);
    final y2 = min(a.y + a.height, b.y + b.height);

    if (x2 < x1 || y2 < y1) return 0.0;

    final intersectionArea = (x2 - x1) * (y2 - y1);

    // Calculate union area
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final unionArea = areaA + areaB - intersectionArea;

    return intersectionArea / unionArea;
  }

  /// STEP 9: Prioritize detections
  ///
  /// Sorting criteria:
  /// 1. Priority level (High > Medium > Low)
  /// 2. Box area (larger boxes = closer objects)
  /// 3. Confidence score
  static List<DetectionResult> prioritizeDetections(
    List<DetectionResult> detections,
  ) {
    if (detections.isEmpty) return [];

    final sorted = List<DetectionResult>.from(detections)
      ..sort((a, b) {
        // First: Sort by priority
        if (a.priority != b.priority) {
          return a.priority.index.compareTo(b.priority.index);
        }

        // Second: Sort by box area (proximity)
        final areaComparison = b.area.compareTo(a.area);
        if (areaComparison != 0) {
          return areaComparison;
        }

        // Third: Sort by confidence
        return b.confidence.compareTo(a.confidence);
      });

    return sorted;
  }

  /// Determine priority based on object class
  static DetectionPriority _getPriority(String label) {
    if (_highPriorityObjects.contains(label)) {
      return DetectionPriority.high;
    } else if (_mediumPriorityObjects.contains(label)) {
      return DetectionPriority.medium;
    } else {
      return DetectionPriority.low;
    }
  }

  /// Get Turkish translation for a label
  static String getTurkishLabel(String englishLabel) {
    return _turkishTranslations[englishLabel] ?? englishLabel;
  }
}
