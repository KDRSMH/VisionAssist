import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/bounding_box_painter.dart';
import '../models/detection_result.dart';
import '../services/object_detection_service.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  ObjectDetectionService? _detectionService;
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

  // YOLOv5n Model Configuration - Optimized for new 9-class model
  static const int _lightThreshold = 35;
  static const double _minBboxArea = 300.0;
  static const double _minConfidenceForAnnouncement = 0.38; // 38% - balanced threshold for voice announcements

  // Throttle - Inference gap - Optimized for better responsiveness
  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minInferenceGapMs = 500; // 500ms - faster detection updates

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
      ResolutionPreset.medium, // low -> medium daha iyi görüntü için
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
      _detectionService = ObjectDetectionService();
      await _detectionService!.initialize();

      if (!mounted) return;
      setState(() {
        _isModelLoaded = true;
        _currentStatusText = 'YOLOv5n Hazır! (416x416, 8 sınıf)';
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
        if (now.difference(_lastInference).inMilliseconds <
            _minInferenceGapMs) {
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

      final service = _detectionService;
      if (service == null || !service.isInitialized) return;

      // Measure inference time
      final stopwatch = Stopwatch()..start();
      final detectionResults = await service.detect(image);
      stopwatch.stop();
      debugPrint('⏱️ YOLOv5n Inference: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('   Total detections found: ${detectionResults.length}');

      // Convert Detection to DetectionResult
      final detections = <DetectionResult>[];
      for (var detection in detectionResults) {
        // Filter small boxes
        if (detection.area < _minBboxArea) {
          debugPrint(
            'Skipped (too small): ${detection.label} area=${detection.area.toInt()}',
          );
          continue;
        }

        detections.add(
          DetectionResult(
            label: detection.label,
            turkishLabel: detection.label, // Already Turkish from model
            confidence: detection.confidence,
            classId: detection.classId,
            priority: _getPriority(detection.label),
            x: detection.x,
            y: detection.y,
            width: detection.width,
            height: detection.height,
          ),
        );

        debugPrint(
          '✓ ${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}% area=${detection.area.toInt()}',
        );
      }

      // Sort by confidence (highest first) with STRICT 60% filtering
      detections.sort((a, b) => b.confidence.compareTo(a.confidence));

      if (!mounted) return;
      setState(() {
        _detections = detections;
        if (detections.isNotEmpty) {
          final top = detections.first;
          _currentStatusText =
              '${top.turkishLabel} (${(top.confidence * 100).toStringAsFixed(0)}%)';
          debugPrint(
            '🎯 Top detection: ${top.turkishLabel} ${(top.confidence * 100).toStringAsFixed(1)}%',
          );
        } else {
          _currentStatusText = 'Nesne algılanmadı';
          debugPrint('❌ No detections after filtering');
        }
      });

      // Announce top detection only (with confidence filter)
      if (detections.isNotEmpty) {
        final topDetection = detections.first;
        if (topDetection.confidence >= _minConfidenceForAnnouncement) {
          _announceDetections([topDetection]);
        }
      }
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

  void _announceDetections(List<DetectionResult> detections) {
    final top = detections.first;
    _speakWithDebounce(top.turkishLabel, top.turkishLabel);
  }

  DetectionPriority _getPriority(String label) {
    // Priority mapping for 8 classes (Door, Motorbike, bike, car, chair, dustbin, human, table)
    const highPriority = {
      'car',         // car - navigation critical
      'Motorbike',   // motorbike - navigation critical
      'bike',        // bike - navigation critical
    };
    const mediumPriority = {
      'human',       // human - safety important
      'Door',        // Door - navigation relevant
    };

    if (highPriority.contains(label)) return DetectionPriority.high;
    if (mediumPriority.contains(label)) return DetectionPriority.medium;
    // Low priority: chair, dustbin, table
    return DetectionPriority.low;
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
        // 3:4 aspect ratio için kamerayı center'la (dikey)
        Center(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: IgnorePointer(child: CameraPreview(controller)),
          ),
        ),

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
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Önce stream'i durdur
    try {
      final controller = _cameraController;
      if (controller != null && controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('dispose stopImageStream error: $e');
    }

    // Sonra controller'ı dispose et
    _cameraController?.dispose();
    _detectionService?.dispose();
    _flutterTts?.stop();

    super.dispose();
  }
}
