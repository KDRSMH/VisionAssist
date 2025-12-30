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

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  FlutterTts? _flutterTts;

  bool _isModelLoaded = false;
  bool _isCameraReady = false;

  bool _isDetecting = false;
  bool _isStreamActive = false;

  bool _initStarted = false;

  List<DetectionResult> _detections = [];
  String _currentStatusText = 'Başlatılıyor...';
  bool _isLightSufficient = true;

  // TTS Debouncing
  final Map<String, DateTime> _lastSpoken = {};
  static const Duration _speakDebounceTime = Duration(seconds: 2);

  // Performance / model
  static const int _inputSize = 320;
  static const double _confidenceThreshold = 0.25;
  static const double _iouThreshold = 0.45;
  static const int _lightThreshold = 35;

  // Throttle
  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minInferenceGapMs = 250;

  bool _printedInfoOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ❗️ÖNEMLİ: burada _safeStopAll çağırma.
    // Yoksa tekrar başlatmayı kilitlersin.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopDetection(); // sadece stream kapat
    }
  }

  Future<void> _initializeApp() async {
    if (_initStarted) return;
    _initStarted = true;

    try {
      final camPerm = await Permission.camera.request();
      if (!camPerm.isGranted) {
        if (!mounted) return;
        setState(() => _currentStatusText = 'Kamera izni gerekli');
        return;
      }

      await _initializeTTS();
      await _initializeCamera();
      await _loadTFLiteModel();

      if (!mounted) return;
      setState(() => _currentStatusText = 'Hazır. Başlat’a basın');
    } catch (e) {
      if (mounted) setState(() => _currentStatusText = 'Başlatma hatası: $e');
      _speakSafe('Uygulama başlatılamadı');
    }
  }

  Future<void> _initializeTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage('tr-TR');
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
  }

  Future<void> _initializeCamera() async {
    final cams = await availableCameras();
    if (cams.isEmpty) {
      if (!mounted) return;
      setState(() => _currentStatusText = 'Kamera bulunamadı');
      return;
    }

    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );

    final controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _cameraController = controller;
    await controller.initialize();

    if (!mounted) return;
    setState(() {
      _isCameraReady = true;
      _currentStatusText = 'Kamera hazır';
    });
  }

  Future<void> _loadTFLiteModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov5s.tflite',
        options: options,
      );

      if (!mounted) return;
      setState(() {
        _isModelLoaded = true;
        _currentStatusText = 'Model yüklendi';
      });

      _speakSafe('Hazır');
    } catch (e) {
      if (mounted) setState(() => _currentStatusText = 'Model yüklenemedi: $e');
      _speakSafe('Model dosyası bulunamadı');
    }
  }

  void _startDetection() {
    debugPrint('FAB: start pressed');

    if (!_isCameraReady || !_isModelLoaded) {
      debugPrint('Start blocked: camera=$_isCameraReady model=$_isModelLoaded');
      setState(() => _currentStatusText = 'Hazır değil (kamera/model)');
      return;
    }

    final controller = _cameraController;
    if (controller == null) {
      setState(() => _currentStatusText = 'Kamera yok');
      return;
    }

    if (!controller.value.isInitialized) {
      debugPrint('Start blocked: camera not initialized');
      setState(() => _currentStatusText = 'Kamera initialize değil');
      return;
    }

    if (_isStreamActive) {
      debugPrint('Start blocked: stream already active');
      return;
    }

    setState(() {
      _isStreamActive = true;
      _currentStatusText = 'Algılama aktif';
      _detections.clear();
    });

    _speakSafe('Algılama başlatıldı');
    _lastInference = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      controller.startImageStream((CameraImage image) async {
        if (!mounted) return;
        if (!_isStreamActive) return;
        if (_isDetecting) return;

        final now = DateTime.now();
        if (now.difference(_lastInference).inMilliseconds < _minInferenceGapMs) {
          return;
        }
        _lastInference = now;

        _isDetecting = true;
        await _processImage(image);
        _isDetecting = false;
      });

      debugPrint('Stream started OK');
    } catch (e) {
      debugPrint('startImageStream failed: $e');
      setState(() {
        _isStreamActive = false;
        _currentStatusText = 'Stream açılamadı: $e';
      });
    }
  }

  Future<void> _stopDetection() async {
    if (!_isStreamActive) return;

    debugPrint('FAB: stop pressed');
    setState(() {
      _isStreamActive = false;
      _currentStatusText = 'Algılama durduruldu';
      _detections.clear();
    });

    try {
      final controller = _cameraController;
      if (controller != null && controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('stopImageStream err: $e');
    }

    _speakWithDebounce('stopped', 'Algılama durduruldu');
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final avg = _calculateAverageLuminance(image);

      if (avg < _lightThreshold) {
        if (_isLightSufficient) {
          setState(() {
            _isLightSufficient = false;
            _currentStatusText = 'Ortam çok karanlık';
            _detections.clear();
          });
        }
        _speakWithDebounce('environment_dark', 'Ortam çok karanlık');
        return;
      } else if (!_isLightSufficient) {
        setState(() => _isLightSufficient = true);
      }

      final interpreter = _interpreter;
      if (interpreter == null) return;

      final input = _preprocessToFloat32(image);
      final output = _runInferenceDynamic(interpreter, input);

      final detections = DetectionHelper.parseYoloOutputDynamic(
        output,
        inputSize: _inputSize,
        originalWidth: image.width,
        originalHeight: image.height,
        confThreshold: _confidenceThreshold,
      );

      final nms = DetectionHelper.nonMaxSuppression(detections, _iouThreshold);
      final prioritized = DetectionHelper.prioritizeDetections(nms);

      if (!mounted) return;
      setState(() {
        _detections = prioritized;
        _currentStatusText = prioritized.isNotEmpty
            ? prioritized.first.turkishLabel
            : 'Nesne algılanmadı';
      });

      if (prioritized.isNotEmpty) _announceDetections(prioritized);
    } catch (e) {
      debugPrint('Detection error: $e');
    }
  }

  int _calculateAverageLuminance(CameraImage image) {
    final bytes = image.planes[0].bytes;
    int sum = 0, count = 0;
    for (int i = 0; i < bytes.length; i += 20) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum ~/ count : 0;
  }

  List<List<List<List<double>>>> _preprocessToFloat32(CameraImage image) {
    final rgb = _convertYUV420ToImageFast(image);

    final resized = img_lib.copyResize(
      rgb,
      width: _inputSize,
      height: _inputSize,
      interpolation: img_lib.Interpolation.average,
    );

    return List.generate(1, (_) {
      return List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        });
      });
    });
  }

  img_lib.Image _convertYUV420ToImageFast(CameraImage image) {
    final w = image.width;
    final h = image.height;

    final out = img_lib.Image(width: w, height: h);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < h; y++) {
      final yRow = yRowStride * y;
      final uvRow = uvRowStride * (y >> 1);

      for (int x = 0; x < w; x++) {
        final yIndex = yRow + x;
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;

        final Y = yPlane.bytes[yIndex];
        final U = uPlane.bytes[uvIndex];
        final V = vPlane.bytes[uvIndex];

        int r = (Y + (1.370705 * (V - 128))).round();
        int g = (Y - (0.337633 * (U - 128)) - (0.698001 * (V - 128))).round();
        int b = (Y + (1.732446 * (U - 128))).round();

        if (r < 0) r = 0;
        if (g < 0) g = 0;
        if (b < 0) b = 0;
        if (r > 255) r = 255;
        if (g > 255) g = 255;
        if (b > 255) b = 255;

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  List<List<double>> _runInferenceDynamic(
    Interpreter interpreter,
    List<List<List<List<double>>>> input,
  ) {
    final inTensor = interpreter.getInputTensor(0);
    final outTensor = interpreter.getOutputTensor(0);

    if (!_printedInfoOnce) {
      _printedInfoOnce = true;
      debugPrint('input shape=${inTensor.shape} type=${inTensor.type}');
      debugPrint('output shape=${outTensor.shape} type=${outTensor.type}');
    }

    final outShape = outTensor.shape; // [1,n,m]
    if (outShape.length != 3 || outShape[0] != 1) {
      throw StateError('Unexpected output shape: $outShape');
    }

    final n = outShape[1];
    final m = outShape[2];

    final output = List.generate(
      1,
      (_) => List.generate(n, (_) => List.filled(m, 0.0)),
    );

    interpreter.run(input, output);
    return output[0];
  }

  void _announceDetections(List<DetectionResult> detections) {
    final top = detections.first;
    _speakWithDebounce(top.turkishLabel, top.turkishLabel);
  }

  void _speakWithDebounce(String key, String text) {
    final now = DateTime.now();
    final last = _lastSpoken[key];
    if (last == null || now.difference(last) > _speakDebounceTime) {
      _speakSafe(text);
      _lastSpoken[key] = now;
    }
  }

  Future<void> _speakSafe(String text) async {
    try {
      await _flutterTts?.speak(text);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!_isCameraReady) {
      return Center(
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
      );
    }

    final controller = _cameraController;
    if (controller == null) {
      return const Center(
        child: Text('Kamera kapatıldı', style: TextStyle(color: Colors.white)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: CameraPreview(controller)),

        // Kutular
        if (_detections.isNotEmpty && controller.value.previewSize != null)
          CustomPaint(
            painter: BoundingBoxPainter(
              detections: _detections,
              previewSize: controller.value.previewSize!,
            ),
          ),

        // Status
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: _buildStatusPanel(),
          ),
        ),

        // ✅ Button EN ÜSTTE
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildControlButton(),
          ),
        ),

        if (!_isLightSufficient)
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildLightWarning(),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentStatusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildControlButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        debugPrint('FAB clicked. active=$_isStreamActive');
        if (_isStreamActive) {
          await _stopDetection();
        } else {
          _startDetection();
        }
      },
      icon: Icon(_isStreamActive ? Icons.stop : Icons.play_arrow),
      label: Text(_isStreamActive ? 'Durdur' : 'Başlat'),
      backgroundColor: _isStreamActive ? Colors.red : Colors.green,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildLightWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Text(
            'Ortam çok karanlık',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _cameraController?.dispose();
    _interpreter?.close();
    _flutterTts?.stop();
    super.dispose();
  }
}
