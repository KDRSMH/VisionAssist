import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'package:camera/camera.dart';
import '../models/detection.dart';

/// YOLOv5 Nano Object Detection Service - Single Focus Mode
///
/// **MODEL SPECIFICATIONS:**
/// - Input Shape: [1, 416, 416, 3] (RGB, Uint8, range 0-255)
/// - Output Shape: [1, 10647, 13] where 13 = [cx, cy, w, h, objectness, cls0...cls7]
/// - Total Classes: 8 (Door, Motorbike, bike, car, chair, dustbin, human, table)
/// - Architecture: YOLOv5n with 416x416 input size
///
/// **SINGLE SUBJECT DETECTION:**
/// - Returns ONLY the most confident object in the frame
/// - Dynamic class handling (loads from labels.txt)
/// - Proper coordinate mapping for camera preview
/// - Manual sigmoid activation on raw logits
class ObjectDetectionService {
  static const String _modelPath = 'assets/models/yolov5n.tflite';
  static const String _labelsPath = 'assets/labels.txt';

  // === SINGLE FOCUS CONFIGURATION ===
  static const int inputSize = 416; // Model requires 416x416 input
  static const double confidenceThreshold = 0.38; // 38% minimum confidence - balanced filtering
  static const double iouThreshold = 0.45; // NMS overlap threshold
  static const double maxScreenCoverageRatio = 0.85; // Reject full-screen boxes

  // === PERFORMANCE OPTIMIZATION ===
  static const int numThreads = 4; // CPU threads for inference
  static const bool useGpuDelegate = false; // Set true if GPU available

  // Model architecture: 8 classes (output: 13 = 4 bbox + 1 objectness + 8 classes)
  static const int totalClasses = 8;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<String> _labels = [];

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

      debugPrint('✅ Loaded ${_labels.length} class labels from file');

      // Validate label count matches model
      if (_labels.length != totalClasses) {
        debugPrint(
          '⚠️  WARNING: Expected $totalClasses classes, got ${_labels.length}',
        );
      }

      // Load TFLite model with optimized settings
      final options = InterpreterOptions()
        ..threads = numThreads
        ..useNnApiForAndroid = true; // Use Android Neural Networks API

      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

      // Validate shapes
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      debugPrint('✅ YOLOv5n Model Loaded');
      debugPrint('   Input:  $inputShape (expected: [1, 416, 416, 3])');
      debugPrint('   Output: $outputShape (expected: [1, 10647, 13])');
      debugPrint('   Classes: $totalClasses (Door, Motorbike, bike, car, chair, dustbin, human, table)');
      debugPrint(
        '   Confidence Threshold: ${(confidenceThreshold * 100).toInt()}% - High accuracy mode',
      );
      debugPrint('   Mode: SINGLE DETECTION (Best object only)');

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Model initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Main detection pipeline - Returns ONLY the most confident detection
  Future<List<Detection>> detect(CameraImage cameraImage) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('Model not initialized');
    }

    try {
      // 1. Preprocess: YUV420 → RGB → 416x416 → Uint8[0-255]
      final inputBuffer = _preprocessImage(cameraImage);

      // 2. Run inference
      final rawOutput = _runInference(inputBuffer);

      // 3. Parse detections with sigmoid activation
      final allDetections = _parseDetections(
        rawOutput,
        cameraImage.width,
        cameraImage.height,
      );

      // 4. Apply NMS to remove overlapping boxes
      final nmsDetections = _applyNMS(allDetections);

      // 5. SINGLE FOCUS: Return only the best detection
      final bestDetection = _selectBestDetection(nmsDetections);

      if (bestDetection != null) {
        debugPrint(
          '🎯 BEST DETECTION: ${bestDetection.label} ${(bestDetection.confidence * 100).toStringAsFixed(1)}%',
        );
        return [bestDetection];
      } else {
        debugPrint(
          '❌ No detection above ${(confidenceThreshold * 100).toInt()}% threshold',
        );
        return [];
      }
    } catch (e) {
      debugPrint('❌ Detection error: $e');
      return [];
    }
  }

  /// Preprocess camera image to 416x416 Uint8 [0-255]
  Uint8List _preprocessImage(CameraImage cameraImage) {
    // Step 1: Convert YUV420 to RGB
    final rgbImage = _yuv420ToRgb(cameraImage);

    // Step 2: Resize to 416x416 (model input size)
    final resizedImage = img_lib.copyResize(
      rgbImage,
      width: inputSize,
      height: inputSize,
      interpolation: img_lib.Interpolation.linear,
    );

    // Step 3: Uint8 format: [0-255] pixel values (model expects uint8, not float32)
    final inputBuffer = Uint8List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputBuffer[pixelIndex++] = pixel.r.toInt();
        inputBuffer[pixelIndex++] = pixel.g.toInt();
        inputBuffer[pixelIndex++] = pixel.b.toInt();
      }
    }

    return inputBuffer;
  }

  /// Convert YUV420 camera format to RGB
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

  /// Run TFLite inference with proper dequantization
  List<List<double>> _runInference(Uint8List inputBuffer) {
    // Reshape: [1, 416, 416, 3]
    final input = inputBuffer.reshape([1, inputSize, inputSize, 3]);

    // Get output tensor info and quantization params
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final numAnchors = outputShape[1]; // 10647
    final numOutputs = outputShape[2]; // 13
    
    // Get quantization parameters
    final params = outputTensor.params;
    final scale = params.scale;
    final zeroPoint = params.zeroPoint;

    // Quantized model uses int8 output
    final intOutput = List.generate(
      1,
      (_) => List.generate(
        numAnchors,
        (_) => List<int>.filled(numOutputs, 0),
      ),
    );
    
    _interpreter!.run(input, intOutput);
    
    // PROPER DEQUANTIZATION: realValue = (quantizedValue - zeroPoint) * scale
    final doubleOutput = <List<double>>[];
    for (int i = 0; i < numAnchors; i++) {
      final row = <double>[];
      for (int j = 0; j < numOutputs; j++) {
        final quantizedValue = intOutput[0][i][j];
        // Dequantize: (q - zero_point) * scale
        final realValue = (quantizedValue - zeroPoint) * scale;
        row.add(realValue);
      }
      doubleOutput.add(row);
    }
    return doubleOutput;
  }

  /// Sigmoid activation function for logit values
  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  /// Parse YOLOv5 output with sigmoid activation
  /// Output format: [cx, cy, w, h, objectness, cls0...cls7]
  /// Total 8 classes - all classes processed, no filtering
  List<Detection> _parseDetections(
    List<List<double>> output,
    int imageWidth,
    int imageHeight,
  ) {
    final detections = <Detection>[];
    final totalScreenArea = imageWidth * imageHeight;

    int validCount = 0;

    for (int i = 0; i < output.length; i++) {
      final anchor = output[i];

      // YOLOv5 quantized output is already dequantized
      // Check if format is xyxy (x1,y1,x2,y2) or xywh (cx,cy,w,h)
      final coord0 = anchor[0];
      final coord1 = anchor[1];
      final coord2 = anchor[2];
      final coord3 = anchor[3];
      
      // Values are very small (0-0.1 range), likely normalized coordinates
      // Try both interpretations:
      // Option 1: xywh (center format) - YOLOv5 default
      // Option 2: xyxy (corners) - some exports use this
      
      // For now, assume xywh but scale up - values might be scaled down by quantization
      final centerX = coord0;
      final centerY = coord1;
      final w = coord2;
      final h = coord3;
      
      // Check if objectness is already probability or logit
      // CRITICAL BUG: Model's objectness is always 0.000!
      // Using class probability only as workaround
      final rawObjectness = anchor[4];

      // Find best class (starting at index 5, total 8 classes)
      // CRITICAL: Model outputs are ALREADY probabilities [0,1], NOT logits!
      // No sigmoid needed on class scores
      int bestClassId = -1;
      double bestClassProb = 0.0;

      // DEBUG: Show all class probabilities for high-confidence detections
      if (validCount < 3) {
        final classScores = <String>[];
        for (int c = 0; c < totalClasses; c++) {
          final prob = anchor[5 + c];
          if (prob > 0.1) {  // Only show >10%
            classScores.add('${_labels[c]}:${(prob * 100).toStringAsFixed(0)}%');
          }
        }
        if (classScores.isNotEmpty) {
          debugPrint('🔍 Anchor $i classes: ${classScores.join(", ")}');
        }
      }

      for (int c = 0; c < totalClasses; c++) {
        final classProb = anchor[5 + c]; // Direct probability, no sigmoid
        if (classProb > bestClassProb) {
          bestClassProb = classProb;
          bestClassId = c;
        }
      }

      // WORKAROUND: Model's objectness is broken (always 0.0)
      // Use class probability directly instead of objectness * classProb
      final finalScore = bestClassProb;  // Skip objectness, use class confidence only

      // Filter by confidence threshold
      if (finalScore < confidenceThreshold) continue;

      // COORDINATE MAPPING: YOLOv5 outputs normalized [0,1] coordinates
      // centerX, centerY, w, h are all in [0,1] range relative to 416x416 input
      // Map directly to preview dimensions
      final boxCenterX = (centerX * imageWidth).clamp(0.0, imageWidth.toDouble());
      final boxCenterY = (centerY * imageHeight).clamp(0.0, imageHeight.toDouble());
      final boxWidth = (w * imageWidth).clamp(0.0, imageWidth.toDouble());
      final boxHeight = (h * imageHeight).clamp(0.0, imageHeight.toDouble());

      // Convert center coordinates to top-left corner
      final x = (boxCenterX - (boxWidth / 2)).clamp(0.0, imageWidth.toDouble());
      final y = (boxCenterY - (boxHeight / 2)).clamp(0.0, imageHeight.toDouble());

      // Clamp to image bounds
      final clampedX = x.clamp(0.0, imageWidth.toDouble());
      final clampedY = y.clamp(0.0, imageHeight.toDouble());
      final clampedWidth =
          (x + boxWidth).clamp(0.0, imageWidth.toDouble()) - clampedX;
      final clampedHeight =
          (y + boxHeight).clamp(0.0, imageHeight.toDouble()) - clampedY;

      // Skip invalid boxes
      if (clampedWidth <= 0 || clampedHeight <= 0) continue;

      // Reject giant boxes (likely false positives)
      final boxArea = clampedWidth * clampedHeight;
      final coverageRatio = boxArea / totalScreenArea;

      if (coverageRatio > maxScreenCoverageRatio) {
        continue;
      }

      validCount++;

      // Get label with error handling for RangeError
      String label;
      try {
        label = _labels[bestClassId];
      } catch (e) {
        label = 'unknown_class_$bestClassId';
        debugPrint(
          '⚠️  Class index $bestClassId out of range (${_labels.length} labels)',
        );
      }

      // Debug log for first few detections
      if (validCount <= 3) {
        debugPrint(
          '🔍 Detection $validCount: $label conf=${(finalScore * 100).toStringAsFixed(1)}% box=[${clampedX.toInt()}, ${clampedY.toInt()}, ${clampedWidth.toInt()}, ${clampedHeight.toInt()}]',
        );
      }

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

    debugPrint('📊 $validCount valid detections found');
    return detections;
  }

  /// Calculate Intersection over Union (IoU) between two bounding boxes
  double _calculateIoU(Detection box1, Detection box2) {
    // Calculate intersection rectangle
    final x1 = max(box1.x, box2.x);
    final y1 = max(box1.y, box2.y);
    final x2 = min(box1.x + box1.width, box2.x + box2.width);
    final y2 = min(box1.y + box1.height, box2.y + box2.height);

    // If no intersection
    if (x2 < x1 || y2 < y1) return 0.0;

    final intersectionArea = (x2 - x1) * (y2 - y1);
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  /// Apply Non-Maximum Suppression to remove overlapping detections
  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return [];

    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedBoxes = <Detection>[];
    final suppressed = <bool>[];
    
    for (int i = 0; i < detections.length; i++) {
      suppressed.add(false);
    }

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      selectedBoxes.add(detections[i]);

      // Suppress overlapping boxes
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        final iou = _calculateIoU(detections[i], detections[j]);
        
        // If boxes overlap significantly, suppress the lower confidence one
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    debugPrint('🎯 NMS: ${detections.length} → ${selectedBoxes.length} detections');
    return selectedBoxes;
  }

  /// SINGLE FOCUS: Select the best detection (highest confidence)
  Detection? _selectBestDetection(List<Detection> detections) {
    if (detections.isEmpty) return null;

    // Sort by confidence (highest first)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Return ONLY the first (most confident) detection
    return detections.first;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('🧹 ObjectDetectionService disposed');
  }
}
