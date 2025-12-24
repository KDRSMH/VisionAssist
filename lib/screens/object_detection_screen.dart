import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import '../utils/bounding_box_painter.dart';
import '../utils/detection_helper.dart';
import '../models/detection_result.dart';

/// Real-Time Object Detection Screen for Visually Impaired Users
///
/// This screen implements a complete object detection pipeline with:
/// - Camera streaming
/// - YOLO TFLite inference
/// - Accessibility-first UI design
/// - Text-to-Speech feedback
class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  // ========== STEP 1: Initialization Variables ==========
  CameraController? _cameraController;
  Interpreter? _interpreter;
  FlutterTts? _flutterTts;

  bool _isModelLoaded = false;
  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _isStreamActive = false;

  // Detection state
  List<DetectionResult> _detections = [];
  String _currentStatusText = 'Başlatılıyor...';
  bool _isLightSufficient = true;

  // TTS Debouncing (Step 11)
  final Map<String, DateTime> _lastSpoken = {};
  static const Duration _speakDebounceTime = Duration(seconds: 2);

  // Camera and model constants
  static const int _inputSize = 416;
  static const double _confidenceThreshold = 0.5;
  static const double _iouThreshold = 0.45;
  static const int _lightThreshold = 50;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// STEP 1: Initialize CameraController, TFLite Model, and FlutterTTS
  Future<void> _initializeApp() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        setState(() {
          _currentStatusText = 'Kamera izni gerekli';
        });
        return;
      }

      // Initialize TTS first for feedback
      await _initializeTTS();

      // Initialize camera
      await _initializeCamera();

      // Load TFLite model
      await _loadTFLiteModel();

      // Start detection automatically
      if (_isCameraReady && _isModelLoaded) {
        _startDetection();
      }
    } catch (e) {
      setState(() {
        _currentStatusText = 'Başlatma hatası: $e';
      });
      _speak('Uygulama başlatılamadı');
    }
  }

  /// Initialize Text-to-Speech engine
  Future<void> _initializeTTS() async {
    _flutterTts = FlutterTts();

    await _flutterTts!.setLanguage('tr-TR');
    await _flutterTts!.setSpeechRate(0.5); // Slower for clarity
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);

    // iOS specific settings
    await _flutterTts!
        .setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ], IosTextToSpeechAudioMode.voicePrompt);
  }

  /// Initialize camera controller
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _currentStatusText = 'Kamera bulunamadı';
      });
      return;
    }

    // Use back camera for object detection
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Efficient for processing
    );

    await _cameraController!.initialize();

    setState(() {
      _isCameraReady = true;
      _currentStatusText = 'Kamera hazır';
    });
  }

  /// Load YOLO TFLite model
  Future<void> _loadTFLiteModel() async {
    try {
      // IMPORTANT: Place your YOLO model file in assets/models/yolov5s.tflite
      // Update pubspec.yaml to include:
      // flutter:
      //   assets:
      //     - assets/models/yolov5s.tflite
      //     - assets/models/labels.txt

      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov5s.tflite',
      );

      setState(() {
        _isModelLoaded = true;
        _currentStatusText = 'Model yüklendi';
      });

      _speak('Nesne algılama hazır');
    } catch (e) {
      setState(() {
        _currentStatusText = 'Model yüklenemedi: $e';
      });
      _speak('Model dosyası bulunamadı');
    }
  }

  /// STEP 3: Start image stream and detection loop
  void _startDetection() {
    if (!_isCameraReady || !_isModelLoaded || _isStreamActive) return;

    setState(() {
      _isStreamActive = true;
      _currentStatusText = 'Algılama aktif';
    });

    _speak('Algılama başlatıldı');

    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting && _isStreamActive) {
        _isDetecting = true;
        _processImage(image);
      }
    });
  }

  /// STEP 13: Stop detection
  void _stopDetection() {
    if (!_isStreamActive) return;

    setState(() {
      _isStreamActive = false;
      _currentStatusText = 'Algılama durduruldu';
      _detections.clear();
    });

    _cameraController?.stopImageStream();
    _speak('Algılama durduruldu');
  }

  /// STEP 4-12: Complete detection pipeline
  Future<void> _processImage(CameraImage image) async {
    try {
      // STEP 4: Light control - Check luminance
      final averageLuminance = _calculateAverageLuminance(image);

      if (averageLuminance < _lightThreshold) {
        setState(() {
          _isLightSufficient = false;
          _currentStatusText = 'Ortam çok karanlık';
        });
        _speakWithDebounce('environment_dark', 'Ortam çok karanlık');
        _isDetecting = false;
        return;
      } else if (!_isLightSufficient) {
        setState(() {
          _isLightSufficient = true;
        });
      }

      // STEP 5: Pre-processing (in Isolate for performance)
      // Convert CameraImage to processable format
      final inputTensor = await _preprocessImageInIsolate(image);

      // STEP 6 & 7: Run inference and parse output
      final output = _runInference(inputTensor);

      // STEP 8: Post-processing with NMS
      final detections = DetectionHelper.parseYoloOutput(
        output,
        _inputSize,
        image.width,
        image.height,
        _confidenceThreshold,
      );

      final nmsDetections = DetectionHelper.nonMaxSuppression(
        detections,
        _iouThreshold,
      );

      // STEP 9: Prioritization
      final prioritizedDetections = DetectionHelper.prioritizeDetections(
        nmsDetections,
      );

      // Update UI with detections
      setState(() {
        _detections = prioritizedDetections;
        if (_detections.isNotEmpty) {
          // STEP 10: Translation happens in DetectionHelper
          final topObject = _detections.first;
          _currentStatusText = topObject.turkishLabel;
        } else {
          _currentStatusText = 'Nesne algılanmadı';
        }
      });

      // STEP 11: TTS with debouncing
      if (prioritizedDetections.isNotEmpty) {
        _announceDetections(prioritizedDetections);
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// STEP 4: Calculate average luminance from Y plane (YUV420)
  int _calculateAverageLuminance(CameraImage image) {
    final yPlane = image.planes[0];
    final bytes = yPlane.bytes;

    // Sample every 10th pixel for performance
    int sum = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += 10) {
      sum += bytes[i];
      count++;
    }

    return count > 0 ? sum ~/ count : 0;
  }

  /// STEP 5: Pre-process image (resize and normalize)
  /// This should ideally run in an Isolate to prevent UI jank
  Future<List<List<List<List<double>>>>> _preprocessImageInIsolate(
    CameraImage image,
  ) async {
    // Note: Full Isolate implementation would require passing raw bytes
    // For this example, we'll do it on main thread with optimization

    return _preprocessImage(image);
  }

  /// Convert CameraImage to model input tensor
  List<List<List<List<double>>>> _preprocessImage(CameraImage image) {
    // Create RGB image from YUV420
    final img_lib.Image rgbImage = _convertYUV420ToImage(image);

    // Resize to model input size (416x416)
    final resized = img_lib.copyResize(
      rgbImage,
      width: _inputSize,
      height: _inputSize,
    );

    // Normalize to [0, 1] and create 4D tensor [1, 416, 416, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0, // Red channel
            pixel.g / 255.0, // Green channel
            pixel.b / 255.0, // Blue channel
          ];
        }),
      ),
    );

    return input;
  }

  /// Convert YUV420 to RGB Image
  img_lib.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img_lib.Image img = img_lib.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final int yValue = yPlane.bytes[yIndex];
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        // YUV to RGB conversion
        int r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255).toInt();
        int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        int b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255).toInt();

        img.setPixelRgb(x, y, r, g, b);
      }
    }

    return img;
  }

  /// STEP 6 & 7: Run TFLite inference and get output
  List<List<double>> _runInference(List<List<List<List<double>>>> input) {
    // Output shape for YOLOv5: [1, 25200, 85]
    // 25200 = predictions, 85 = [x, y, w, h, confidence, 80 class scores]
    var output = List.generate(
      1,
      (_) => List.generate(25200, (_) => List.filled(85, 0.0)),
    );

    _interpreter!.run(input, output);

    return output[0]; // Return [25200, 85]
  }

  /// STEP 11: Announce detections with debouncing
  void _announceDetections(List<DetectionResult> detections) {
    if (detections.isEmpty) return;

    // Announce top priority detection
    final topDetection = detections.first;
    final key = topDetection.turkishLabel;

    _speakWithDebounce(key, topDetection.turkishLabel);
  }

  /// TTS with debounce control
  void _speakWithDebounce(String key, String text) {
    final now = DateTime.now();
    final lastTime = _lastSpoken[key];

    if (lastTime == null || now.difference(lastTime) > _speakDebounceTime) {
      _speak(text);
      _lastSpoken[key] = now;
    }
  }

  /// Speak text using TTS
  Future<void> _speak(String text) async {
    await _flutterTts?.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  /// STEP 2: UI Layout with Stack
  Widget _buildBody() {
    if (!_isCameraReady) {
      return Center(
        child: Semantics(
          label: _currentStatusText,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                _currentStatusText,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // LAYER 1 (Bottom): Camera Preview
        // CRITICAL: Wrapped in ExcludeSemantics - blind users don't need camera view
        ExcludeSemantics(child: CameraPreview(_cameraController!)),

        // LAYER 2 (Middle): Bounding boxes
        if (_detections.isNotEmpty)
          CustomPaint(
            painter: BoundingBoxPainter(
              detections: _detections,
              previewSize: _cameraController!.value.previewSize!,
            ),
          ),

        // LAYER 3 (Overlay): High-contrast status panel at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 80, // Above FAB
          child: _buildStatusPanel(),
        ),

        // LAYER 4 (Top): Accessible Start/Stop button
        Positioned(right: 16, bottom: 16, child: _buildControlButton()),

        // Light warning indicator
        if (!_isLightSufficient)
          Positioned(top: 16, left: 0, right: 0, child: _buildLightWarning()),
      ],
    );
  }

  /// STEP 2: High-contrast status panel with MergeSemantics
  Widget _buildStatusPanel() {
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main status text
            Text(
              _currentStatusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // Detection count
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_detections.length} nesne algılandı',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// STEP 2: Large, accessible control button (56x56 minimum)
  Widget _buildControlButton() {
    return Semantics(
      button: true,
      label: _isStreamActive ? 'Algılamayı Durdur' : 'Algılamayı Başlat',
      onTap: () {
        if (_isStreamActive) {
          _stopDetection();
        } else {
          _startDetection();
        }
      },
      child: FloatingActionButton.extended(
        onPressed: () {
          if (_isStreamActive) {
            _stopDetection();
          } else {
            _startDetection();
          }
        },
        icon: Icon(_isStreamActive ? Icons.stop : Icons.play_arrow),
        label: Text(
          _isStreamActive ? 'Durdur' : 'Başlat',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _isStreamActive ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  /// Light warning indicator
  Widget _buildLightWarning() {
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ortam çok karanlık',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    _flutterTts?.stop();
    super.dispose();
  }
}
