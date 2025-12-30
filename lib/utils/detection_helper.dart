import 'dart:math';
import '../models/detection_result.dart';

/// Helper class for YOLO detection processing
///
/// Handles:
/// - Parsing YOLO output tensor (dynamic shape)
/// - Non-Maximum Suppression (NMS)
/// - Priority sorting
/// - English to Turkish translation
class DetectionHelper {
  // COCO dataset class names (80 classes)
  static const List<String> _cocoLabels = [
    'person','bicycle','car','motorcycle','airplane','bus','train','truck','boat',
    'traffic light','fire hydrant','stop sign','parking meter','bench','bird','cat',
    'dog','horse','sheep','cow','elephant','bear','zebra','giraffe','backpack',
    'umbrella','handbag','tie','suitcase','frisbee','skis','snowboard','sports ball',
    'kite','baseball bat','baseball glove','skateboard','surfboard','tennis racket',
    'bottle','wine glass','cup','fork','knife','spoon','bowl','banana','apple',
    'sandwich','orange','broccoli','carrot','hot dog','pizza','donut','cake','chair',
    'couch','potted plant','bed','dining table','toilet','tv','laptop','mouse','remote',
    'keyboard','cell phone','microwave','oven','toaster','sink','refrigerator','book',
    'clock','vase','scissors','teddy bear','hair drier','toothbrush',
  ];

  /// English to Turkish translation map
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

  /// High priority objects (danger/obstacles)
  static const Set<String> _highPriorityObjects = {
    'car','bus','truck','motorcycle','bicycle','train',
  };

  /// Medium priority objects
  static const Set<String> _mediumPriorityObjects = {
    'person','dog','cat','horse',
  };

  /// ✅ Dynamic YOLO output parser
  ///
  /// output: [n, m]
  /// - YOLOv5-like: [cx,cy,w,h,obj, class...]
  /// - YOLOv8-like: [cx,cy,w,h, class...] (obj yok)
  static List<DetectionResult> parseYoloOutputDynamic(
    List<List<double>> output, {
    required int inputSize,
    required int originalWidth,
    required int originalHeight,
    required double confThreshold,
  }) {
    final detections = <DetectionResult>[];
    if (output.isEmpty) return detections;

    final int m = output[0].length;
    if (m < 6) return detections;

    // Daha doğru heuristik:
    // Eğer m-5 >= 1 ise obj var gibi davranıyoruz ama class sayısı aşırı büyükse
    // yine de çalışsın diye genel tuttuk.
    final bool hasObjectness = (m >= 6);
    final int classStart = hasObjectness ? 5 : 4;
    final int numClasses = m - classStart;
    if (numClasses <= 0) return detections;

    for (int i = 0; i < output.length; i++) {
      final p = output[i];
      if (p.length != m) continue;

      final double cx0 = p[0];
      final double cy0 = p[1];
      final double w0 = p[2];
      final double h0 = p[3];

      final double obj = hasObjectness ? p[4] : 1.0;
      if (obj.isNaN) continue;

      // best class
      int bestId = 0;
      double bestScore = p[classStart];
      for (int c = 1; c < numClasses; c++) {
        final s = p[classStart + c];
        if (s > bestScore) {
          bestScore = s;
          bestId = c;
        }
      }

      final double conf = obj * bestScore;
      if (conf < confThreshold) continue;

      // coords: normalized mı inputSize pixel mi?
      final bool looksLikePixels =
          (cx0 > 1.5 || cy0 > 1.5 || w0 > 1.5 || h0 > 1.5);

      double xMin, yMin, boxW, boxH;

      if (looksLikePixels) {
        final sx = originalWidth / inputSize;
        final sy = originalHeight / inputSize;
        xMin = (cx0 - w0 / 2) * sx;
        yMin = (cy0 - h0 / 2) * sy;
        boxW = w0 * sx;
        boxH = h0 * sy;
      } else {
        xMin = (cx0 - w0 / 2) * originalWidth;
        yMin = (cy0 - h0 / 2) * originalHeight;
        boxW = w0 * originalWidth;
        boxH = h0 * originalHeight;
      }

      // clamp (num->double güvenli)
      xMin = (xMin.clamp(0.0, originalWidth.toDouble()) as num).toDouble();
      yMin = (yMin.clamp(0.0, originalHeight.toDouble()) as num).toDouble();
      boxW = (boxW.clamp(0.0, originalWidth.toDouble()) as num).toDouble();
      boxH = (boxH.clamp(0.0, originalHeight.toDouble()) as num).toDouble();

      // label: COCO dışına taşarsa class_XX
      final String label = (bestId < _cocoLabels.length)
          ? _cocoLabels[bestId]
          : 'class_$bestId';

      final String turkishLabel = _turkishTranslations[label] ?? label;

      detections.add(
        DetectionResult(
          x: xMin,
          y: yMin,
          width: boxW,
          height: boxH,
          confidence: conf,
          label: label,
          turkishLabel: turkishLabel,
          classId: bestId,
          priority: _getPriority(label),
        ),
      );
    }

    return detections;
  }

  /// Non-Maximum Suppression (NMS)
  static List<DetectionResult> nonMaxSuppression(
    List<DetectionResult> detections,
    double iouThreshold,
  ) {
    if (detections.isEmpty) return [];

    final sorted = List<DetectionResult>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <DetectionResult>[];
    final suppressed = <int>{};

    for (int i = 0; i < sorted.length; i++) {
      if (suppressed.contains(i)) continue;
      selected.add(sorted[i]);

      for (int j = i + 1; j < sorted.length; j++) {
        if (suppressed.contains(j)) continue;
        final iou = _calculateIoU(sorted[i], sorted[j]);
        if (iou > iouThreshold) suppressed.add(j);
      }
    }

    return selected;
  }

  static double _calculateIoU(DetectionResult a, DetectionResult b) {
    final x1 = max(a.x, b.x);
    final y1 = max(a.y, b.y);
    final x2 = min(a.x + a.width, b.x + b.width);
    final y2 = min(a.y + a.height, b.y + b.height);

    if (x2 <= x1 || y2 <= y1) return 0.0;

    final inter = (x2 - x1) * (y2 - y1);
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final union = areaA + areaB - inter;

    return union <= 0 ? 0.0 : (inter / union);
  }

  /// Priority sorting
  static List<DetectionResult> prioritizeDetections(
    List<DetectionResult> detections,
  ) {
    if (detections.isEmpty) return [];

    final sorted = List<DetectionResult>.from(detections)
      ..sort((a, b) {
        if (a.priority != b.priority) {
          return a.priority.index.compareTo(b.priority.index);
        }
        final areaCmp = b.area.compareTo(a.area);
        if (areaCmp != 0) return areaCmp;
        return b.confidence.compareTo(a.confidence);
      });

    return sorted;
  }

  static DetectionPriority _getPriority(String label) {
    if (_highPriorityObjects.contains(label)) return DetectionPriority.high;
    if (_mediumPriorityObjects.contains(label)) return DetectionPriority.medium;
    return DetectionPriority.low;
  }

  static String getTurkishLabel(String englishLabel) {
    return _turkishTranslations[englishLabel] ?? englishLabel;
  }
}
