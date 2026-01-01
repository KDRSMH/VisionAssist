import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'package:camera/camera.dart';
import '../models/detection.dart';

/// YOLOv5 Nano Object Detection Service - COCO Subset (8 Classes)
///
/// **STRICT FILTERING & SIGMOID ACTIVATION:**
/// - High threshold: 0.60 (60%) to prevent false positives
/// - Manual sigmoid activation on raw logits
/// - Float32 normalization: pixel/255.0 → [0.0-1.0]
/// - Output shape: [1, N, 13] where 13 = [x, y, w, h, conf, cls0...cls7]
/// - NMS with IOU 0.45 to remove duplicates
/// - Giant box filter (>90% screen coverage)
class ObjectDetectionService {
  static const String _modelPath = 'assets/models/yolov5n.tflite';
  static const String _labelsPath = 'assets/labels.txt';

  // === OPTIMIZED CONFIGURATION ===
  static const int inputSize = 416;
  static const double finalScoreThreshold = 0.35; // 35% - Balanced (detects furniture too)
  static const double iouThreshold = 0.55; // NMS overlap threshold (stricter)
  static const double maxScreenCoverageRatio = 0.85; // 85% - Giant box filter
  static const int maxDetectionsPerFrame = 3; // Maximum detections to show

  // Expected 8 COCO classes (mapped to Turkish)
  static const List<String> expectedLabels = [
    'bisiklet', // bicycle
    'araba', // car
    'kedi', // cat
    'sandalye', // chair
    'masa', // dining table
    'köpek', // dog
    'motosiklet', // motorcycle
    'insan', // person
  ];

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<String> get labels => _labels;
  int get numClasses => _labels.length;

  /// Initialize model and validate labels
  Future<void> initialize() async {
    try {
      // Load labels from file
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // STRICT validation - ensure exact 8 classes
      if (_labels.length != 8) {
        throw Exception(
          'Label count mismatch! Expected 8 COCO classes, got ${_labels.length}',
        );
      }

      debugPrint('✅ Labels validated (8 COCO classes): ${_labels.join(", ")}');

      // Load TFLite model
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

      // Validate model shape
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      debugPrint('✅ YOLOv5n COCO Subset Model Loaded');
      debugPrint('   Input Shape: $inputShape');
      debugPrint('   Output Shape: $outputShape');
      debugPrint('   Expected Output: [1, N, 13] (13 = 5 bbox + 8 classes)');
      debugPrint(
        '   ✅ BALANCED: Threshold 35% | NMS IOU 0.55 | Max 3 detections',
      );
      debugPrint('   Giant box filter: 85%');

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Model initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Main detection pipeline
  Future<List<Detection>> detect(CameraImage cameraImage) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    // 1. Preprocess: YUV420 → RGB → 416x416 → Float32[0-1]
    final inputBuffer = _preprocessImage(cameraImage);

    // 2. Inference
    final output = _runInference(inputBuffer);

    // 3. Parse with optimized filtering (40% threshold) + SIGMOID activation
    final detections = _parseOutputWithSigmoid(
      output,
      cameraImage.width,
      cameraImage.height,
    );

    // 4. Non-Maximum Suppression (IOU 0.55) + Max 3 detections
    final nmsDetections = _nonMaxSuppression(detections);

    debugPrint('📊 Detection Summary:');
    debugPrint('   Raw anchors: ${output.length}');
    debugPrint(
      '   After sigmoid + filtering (>${(finalScoreThreshold * 100).toInt()}%): ${detections.length}',
    );
    debugPrint('   After NMS: ${nmsDetections.length}');

    return nmsDetections;
  }

  /// Preprocess camera image to 416x416 Float32 normalized [0.0-1.0]
  /// CRITICAL: Divide by 255.0 (NOT mean/std normalization)
  Float32List _preprocessImage(CameraImage cameraImage) {
    // Step 1: Convert YUV420 to RGB
    final rgbImage = _yuv420ToRgb(cameraImage);

    // Step 2: Resize to 416x416
    final resizedImage = img_lib.copyResize(
      rgbImage,
      width: inputSize,
      height: inputSize,
      interpolation: img_lib.Interpolation.linear,
    );

    // Step 3: Convert to Float32 and normalize [0.0-1.0] by dividing by 255.0
    final inputBuffer = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);

        // CRITICAL: Normalize to [0.0, 1.0] by dividing by 255.0 (NO mean/std)
        inputBuffer[pixelIndex++] = pixel.r / 255.0;
        inputBuffer[pixelIndex++] = pixel.g / 255.0;
        inputBuffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return inputBuffer;
  }

  /// Convert YUV420 camera format to RGB image
  img_lib.Image _yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final img = img_lib.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final yValue = yPlane.bytes[yIndex];
        final uValue = uPlane.bytes[uvIndex];
        final vValue = vPlane.bytes[uvIndex];

        // YUV to RGB conversion
        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        img.setPixelRgb(x, y, r, g, b);
      }
    }

    return img;
  }

  /// Run TFLite inference
  List<List<double>> _runInference(Float32List inputBuffer) {
    // Reshape input: [1, 416, 416, 3]
    final input = inputBuffer.reshape([1, inputSize, inputSize, 3]);

    // Prepare output buffer
    // Expected shape: [1, N, 13] where 13 = 5 (bbox+conf) + 8 (classes)
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final numAnchors = outputShape[1]; // N anchors
    final numOutputs = outputShape[2]; // Should be 13

    final output = List.generate(
      1,
      (_) => List.generate(
        numAnchors,
        (_) => List<double>.filled(numOutputs, 0.0),
      ),
    );

    // Run inference
    _interpreter!.run(input, output);

    return output[0]; // Return [N, 13]
  }

  /// Parse YOLOv5 output with MANUAL SIGMOID activation
  /// Output format: [N, 13] where each anchor is [cx, cy, w, h, box_conf_logit, class0_logit...class7_logit]
  /// CRITICAL: Apply sigmoid to box_conf and class_probs, then calculate Final Score
  List<Detection> _parseOutputWithSigmoid(
    List<List<double>> output,
    int imageWidth,
    int imageHeight,
  ) {
    final detections = <Detection>[];
    final totalScreenArea = imageWidth * imageHeight;

    double maxBoxConfSigmoid = 0.0;
    double maxFinalScore = 0.0;
    int passedThresholdCount = 0;
    int giantBoxesSkipped = 0;

    for (int i = 0; i < output.length; i++) {
      final anchor = output[i];

      // YOLOv5 format: [cx, cy, w, h, box_conf_logit, class0_logit...class7_logit]
      final centerX = anchor[0]; // Normalized center x [0-1]
      final centerY = anchor[1]; // Normalized center y [0-1]
      final w = anchor[2]; // Normalized width [0-1]
      final h = anchor[3]; // Normalized height [0-1]
      final rawBoxConfLogit = anchor[4]; // Raw box confidence LOGIT

      // CRITICAL: Apply sigmoid to box confidence (convert logit → probability)
      final boxConfidence = _sigmoid(rawBoxConfLogit);
      if (boxConfidence > maxBoxConfSigmoid) maxBoxConfSigmoid = boxConfidence;

      // Find best class with sigmoid activation
      int bestClassId = -1;
      double bestClassProbSigmoid = 0.0;

      for (int c = 0; c < numClasses; c++) {
        final rawClassLogit = anchor[5 + c];

        // CRITICAL: Apply sigmoid to class logit
        final classProbSigmoid = _sigmoid(rawClassLogit);

        if (classProbSigmoid > bestClassProbSigmoid) {
          bestClassProbSigmoid = classProbSigmoid;
          bestClassId = c;
        }
      }

      // CRITICAL: Calculate Final Score = Sigmoid(BoxConf) * Sigmoid(ClassProb)
      final finalScore = boxConfidence * bestClassProbSigmoid;
      if (finalScore > maxFinalScore) maxFinalScore = finalScore;

      // OPTIMIZED FILTER: Final Score must be >= 35% (balanced)
      if (finalScore < finalScoreThreshold) continue;
      passedThresholdCount++;

      // Convert from normalized center coordinates to pixel coordinates
      final x = (centerX - w / 2) * imageWidth;
      final y = (centerY - h / 2) * imageHeight;
      final width = w * imageWidth;
      final height = h * imageHeight;

      // Clamp to image bounds
      final clampedX = x.clamp(0.0, imageWidth.toDouble());
      final clampedY = y.clamp(0.0, imageHeight.toDouble());
      final clampedWidth =
          (x + width).clamp(0.0, imageWidth.toDouble()) - clampedX;
      final clampedHeight =
          (y + height).clamp(0.0, imageHeight.toDouble()) - clampedY;

      // Skip invalid boxes
      if (clampedWidth <= 0 || clampedHeight <= 0) continue;

      // SANITY CHECK: Ignore giant boxes (>90% screen coverage)
      final boxArea = clampedWidth * clampedHeight;
      final coverageRatio = boxArea / totalScreenArea;

      if (coverageRatio > maxScreenCoverageRatio) {
        giantBoxesSkipped++;
        debugPrint(
          '⚠️ Skipped giant box: ${_labels[bestClassId]} (${(coverageRatio * 100).toStringAsFixed(1)}% coverage)',
        );
        continue;
      }

      // Valid detection - add to list
      final label = _labels[bestClassId];
      detections.add(
        Detection(
          classId: bestClassId,
          label: label,
          confidence: finalScore,
          x: clampedX,
          y: clampedY,
          width: clampedWidth,
          height: clampedHeight,
        ),
      );
    }

    debugPrint('🔍 Parse Stats (SIGMOID + 35% filtering):');
    debugPrint(
      '   ⭐ MAX BOX CONF (sigmoid): ${(maxBoxConfSigmoid * 100).toStringAsFixed(1)}%',
    );
    debugPrint(
      '   ⭐ MAX FINAL SCORE: ${(maxFinalScore * 100).toStringAsFixed(1)}%',
    );
    debugPrint('   Passed threshold (>35%): $passedThresholdCount');
    debugPrint('   Giant boxes skipped: $giantBoxesSkipped');
    debugPrint('   Valid detections: ${detections.length}');

    return detections;
  }

  /// Apply sigmoid activation: 1 / (1 + exp(-x))
  /// Converts raw logits to probabilities [0, 1]
  double _sigmoid(double x) {
    return 1.0 / (1.0 + math.exp(-x));
  }

  /// Non-Maximum Suppression - remove overlapping boxes
  List<Detection> _nonMaxSuppression(List<Detection> detections) {
    if (detections.isEmpty) return [];

    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedBoxes = <Detection>[];

    for (int i = 0; i < detections.length; i++) {
      final currentBox = detections[i];
      bool shouldSelect = true;

      for (final selectedBox in selectedBoxes) {
        // Only suppress if same class
        if (currentBox.classId != selectedBox.classId) continue;

        final iou = _calculateIoU(currentBox, selectedBox);

        // If overlap > threshold, suppress this box
        if (iou > iouThreshold) {
          shouldSelect = false;
          debugPrint(
            '   NMS: Suppressed ${currentBox.label} (IOU: ${(iou * 100).toStringAsFixed(1)}%)',
          );
          break;
        }
      }

      if (shouldSelect) {
        selectedBoxes.add(currentBox);
        
        // LIMIT: Keep only top N detections (highest confidence)
        if (selectedBoxes.length >= maxDetectionsPerFrame) {
          debugPrint('⚠️ Detection limit reached: keeping top $maxDetectionsPerFrame');
          break;
        }
      }
    }

    debugPrint('📦 NMS: ${detections.length} → ${selectedBoxes.length} boxes');
    return selectedBoxes;
  }

  /// Calculate Intersection over Union (IoU)
  double _calculateIoU(Detection box1, Detection box2) {
    final x1 = math.max(box1.x, box2.x);
    final y1 = math.max(box1.y, box2.y);
    final x2 = math.min(box1.x2, box2.x2);
    final y2 = math.min(box1.y2, box2.y2);

    final intersectionWidth = math.max(0.0, x2 - x1);
    final intersectionHeight = math.max(0.0, y2 - y1);
    final intersectionArea = intersectionWidth * intersectionHeight;

    final box1Area = box1.area;
    final box2Area = box2.area;
    final unionArea = box1Area + box2Area - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
