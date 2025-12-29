import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/detection_result.dart';
import '../utils/bounding_box_painter.dart';


/// Modern Demo Screen with Voice Feedback
/// Features: TTS, animations, glassmorphism design, haptic feedback
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> with TickerProviderStateMixin {
  // TTS Engine
  late FlutterTts _tts;
  bool _ttsReady = false;

  // State
  bool _isStreamActive = false;
  bool _isLightSufficient = true;
  bool _isSpeaking = false;
  String _currentStatusText = 'Hazır';
  List<DetectionResult> _detections = [];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  // Debounce timer for TTS
  Timer? _ttsDebounceTimer;
  String _lastSpokenText = '';

  // Demo detection sets for simulation
  final List<List<DetectionResult>> _demoScenarios = [
    // Scenario 1: Street scene
    [
      DetectionResult(
        x: 50,
        y: 80,
        width: 120,
        height: 280,
        confidence: 0.96,
        label: 'person',
        turkishLabel: 'İnsan',
        classId: 0,
        priority: DetectionPriority.medium,
      ),
      DetectionResult(
        x: 220,
        y: 120,
        width: 160,
        height: 100,
        confidence: 0.92,
        label: 'car',
        turkishLabel: 'Araba',
        classId: 2,
        priority: DetectionPriority.high,
      ),
    ],
    // Scenario 2: Indoor scene
    [
      DetectionResult(
        x: 80,
        y: 200,
        width: 100,
        height: 120,
        confidence: 0.89,
        label: 'chair',
        turkishLabel: 'Sandalye',
        classId: 56,
        priority: DetectionPriority.low,
      ),
      DetectionResult(
        x: 200,
        y: 150,
        width: 140,
        height: 100,
        confidence: 0.85,
        label: 'tv',
        turkishLabel: 'Televizyon',
        classId: 62,
        priority: DetectionPriority.low,
      ),
      DetectionResult(
        x: 100,
        y: 350,
        width: 80,
        height: 60,
        confidence: 0.78,
        label: 'cat',
        turkishLabel: 'Kedi',
        classId: 15,
        priority: DetectionPriority.medium,
      ),
    ],
    // Scenario 3: Traffic scene
    [
      DetectionResult(
        x: 30,
        y: 100,
        width: 140,
        height: 90,
        confidence: 0.94,
        label: 'bus',
        turkishLabel: 'Otobüs',
        classId: 5,
        priority: DetectionPriority.high,
      ),
      DetectionResult(
        x: 200,
        y: 180,
        width: 60,
        height: 80,
        confidence: 0.87,
        label: 'traffic light',
        turkishLabel: 'Trafik Lambası',
        classId: 9,
        priority: DetectionPriority.high,
      ),
      DetectionResult(
        x: 280,
        y: 250,
        width: 80,
        height: 180,
        confidence: 0.91,
        label: 'person',
        turkishLabel: 'İnsan',
        classId: 0,
        priority: DetectionPriority.medium,
      ),
    ],
  ];

  int _currentScenarioIndex = 0;
  Timer? _scenarioTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();

    try {
      // Configure TTS for Turkish
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Set completion handler
      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      });

      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = true);
        }
      });

      setState(() => _ttsReady = true);

      // Welcome message
      await Future.delayed(const Duration(milliseconds: 500));
      _speak('Görme engelli asistanı hazır. Başlatmak için ekrana dokunun.');
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady || text.isEmpty || text == _lastSpokenText) return;

    // Cancel previous debounce
    _ttsDebounceTimer?.cancel();

    // Debounce: wait 300ms before speaking
    _ttsDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _lastSpokenText = text;
      await _tts.stop();
      await _tts.speak(text);
    });
  }

  void _startDetection() {
    setState(() {
      _isStreamActive = true;
      _currentStatusText = 'Taranıyor...';
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Start animations
    _pulseController.repeat(reverse: true);
    _scanController.repeat();

    // Voice feedback
    _speak('Algılama başladı');

    // Start scenario rotation
    _updateDetections();
    _scenarioTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _rotateScenario();
    });
  }

  void _stopDetection() {
    setState(() {
      _isStreamActive = false;
      _detections = [];
      _currentStatusText = 'Durduruldu';
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Stop animations
    _pulseController.stop();
    _scanController.stop();
    _scenarioTimer?.cancel();

    // Voice feedback
    _speak('Algılama durduruldu');
    _lastSpokenText = '';
  }

  void _toggleDetection() {
    if (_isStreamActive) {
      _stopDetection();
    } else {
      _startDetection();
    }
  }

  void _updateDetections() {
    if (!_isStreamActive) return;

    final scenario = _demoScenarios[_currentScenarioIndex];
    setState(() {
      _detections = scenario;
      _currentStatusText = _buildStatusMessage(scenario);
    });

    // Voice feedback for detections
    _announceDetections(scenario);
  }

  void _rotateScenario() {
    if (!_isStreamActive) return;

    _currentScenarioIndex = (_currentScenarioIndex + 1) % _demoScenarios.length;

    // Haptic feedback for new detections
    HapticFeedback.selectionClick();

    _updateDetections();
  }

  String _buildStatusMessage(List<DetectionResult> detections) {
    if (detections.isEmpty) return 'Nesne yok';

    // Find highest priority detection
    final highPriority = detections.where(
      (d) => d.priority == DetectionPriority.high,
    );
    if (highPriority.isNotEmpty) {
      return '⚠️ ${highPriority.first.turkishLabel}';
    }

    return detections.first.turkishLabel;
  }

  void _announceDetections(List<DetectionResult> detections) {
    if (detections.isEmpty || !_isLightSufficient) return;

    // Prioritize high-priority objects
    final highPriority = detections
        .where((d) => d.priority == DetectionPriority.high)
        .toList();
    final mediumPriority = detections
        .where((d) => d.priority == DetectionPriority.medium)
        .toList();

    String announcement = '';

    if (highPriority.isNotEmpty) {
      // Danger announcement
      final labels = highPriority.map((d) => d.turkishLabel).join(', ');
      announcement = 'Dikkat! $labels yakında';
      HapticFeedback.heavyImpact();
    } else if (mediumPriority.isNotEmpty) {
      announcement = mediumPriority.first.turkishLabel;
    } else if (detections.isNotEmpty) {
      announcement =
          '${detections.length} nesne: ${detections.first.turkishLabel}';
    }

    if (announcement.isNotEmpty) {
      _speak(announcement);
    }
  }

  void _toggleLight() {
    setState(() {
      _isLightSufficient = !_isLightSufficient;
    });

    HapticFeedback.mediumImpact();

    if (!_isLightSufficient) {
      _speak('Uyarı: Ortam çok karanlık');
    } else {
      _speak('Işık yeterli');
    }
  }

  @override
  void dispose() {
    _ttsDebounceTimer?.cancel();
    _scenarioTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            _buildBackground(),

            // Camera simulation with scan effect
            _buildCameraView(),

            // Bounding boxes
            if (_detections.isNotEmpty && _isLightSufficient)
              CustomPaint(
                painter: BoundingBoxPainter(
                  detections: _detections,
                  previewSize: MediaQuery.of(context).size,
                ),
              ),

            // Scan line animation
            if (_isStreamActive && _isLightSufficient) _buildScanLine(),

            // Top bar with glassmorphism
            _buildTopBar(),

            // Status card
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: _buildStatusCard(),
            ),

            // Control buttons
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildControlBar(),
            ),

            // Light warning overlay
            if (!_isLightSufficient) _buildLightWarning(),

            // Speaking indicator
            if (_isSpeaking) _buildSpeakingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0E21),
            const Color(0xFF1A1F38),
            Colors.black.withOpacity(0.95),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 80, 16, 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800.withOpacity(0.8),
            ],
          ),
          border: Border.all(
            color: _isStreamActive
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isStreamActive
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Grid pattern
              CustomPaint(size: Size.infinite, painter: GridPainter()),
              // Camera icon
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isStreamActive ? Icons.videocam : Icons.videocam_off,
                      size: 64,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isStreamActive ? 'Canlı Görüntü' : 'Kamera Kapalı',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top:
              80 +
              (_scanAnimation.value *
                  (MediaQuery.of(context).size.height - 280)),
          left: 16,
          right: 16,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.greenAccent.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // App title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Görme Asistanı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // TTS indicator
            _buildGlassButton(
              icon: _ttsReady ? Icons.volume_up : Icons.volume_off,
              color: _ttsReady ? Colors.greenAccent : Colors.grey,
              onTap: () => _speak('Ses aktif'),
            ),

            const SizedBox(width: 8),

            // Light toggle
            _buildGlassButton(
              icon: _isLightSufficient ? Icons.wb_sunny : Icons.nights_stay,
              color: _isLightSufficient ? Colors.amber : Colors.blueGrey,
              onTap: _toggleLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildStatusCard() {
    return MergeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _detections.any((d) => d.priority == DetectionPriority.high)
                ? Colors.redAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon and text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _currentStatusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // Detection count
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_detections.length} nesne algılandı',
                  style: TextStyle(
                    color: Colors.greenAccent.shade200,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Detection list
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _detections
                    .map((d) => _buildDetectionChip(d))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (!_isStreamActive) {
      return Icon(Icons.pause_circle, color: Colors.grey.shade400, size: 32);
    }

    if (_detections.any((d) => d.priority == DetectionPriority.high)) {
      return const Icon(Icons.warning_amber, color: Colors.redAccent, size: 32);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: const Icon(Icons.radar, color: Colors.greenAccent, size: 32),
        );
      },
    );
  }

  Widget _buildDetectionChip(DetectionResult detection) {
    Color chipColor;
    switch (detection.priority) {
      case DetectionPriority.high:
        chipColor = Colors.redAccent;
        break;
      case DetectionPriority.medium:
        chipColor = Colors.amber;
        break;
      case DetectionPriority.low:
        chipColor = Colors.greenAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            detection.turkishLabel,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(detection.confidence * 100).toInt()}%',
            style: TextStyle(color: chipColor.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Row(
      children: [
        // Info button
        Expanded(
          child: _buildControlButton(
            icon: Icons.info_outline,
            label: 'Bilgi',
            color: Colors.blueAccent,
            onTap: () => _showInfoDialog(),
          ),
        ),

        const SizedBox(width: 12),

        // Main action button
        Expanded(
          flex: 2,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isStreamActive
                    ? 1.0
                    : _pulseAnimation.value * 0.05 + 0.95,
                child: _buildMainActionButton(),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        // Voice button
        Expanded(
          child: _buildControlButton(
            icon: _isSpeaking ? Icons.record_voice_over : Icons.mic,
            label: 'Ses',
            color: _isSpeaking ? Colors.greenAccent : Colors.purpleAccent,
            onTap: () => _speak('Ses testi'),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    return Semantics(
      button: true,
      label: _isStreamActive ? 'Algılamayı Durdur' : 'Algılamayı Başlat',
      child: GestureDetector(
        onTap: _toggleDetection,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isStreamActive
                  ? [Colors.redAccent, Colors.red.shade700]
                  : [Colors.greenAccent, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (_isStreamActive ? Colors.redAccent : Colors.greenAccent)
                    .withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isStreamActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                _isStreamActive ? 'DURDUR' : 'BAŞLAT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLightWarning() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flashlight_off, color: Colors.orange, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Ortam Çok Karanlık',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Daha iyi algılama için ışığı artırın',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _toggleLight,
                icon: const Icon(Icons.wb_sunny),
                label: const Text('Işığı Aç'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakingIndicator() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSoundWave(),
              const SizedBox(width: 8),
              const Text(
                'Konuşuyor...',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundWave() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + index * 100),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: 8.0 + Random().nextDouble() * 12,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.visibility, color: Colors.greenAccent),
            SizedBox(width: 12),
            Text('Hakkında', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.camera_alt, 'Gerçek zamanlı nesne algılama'),
            _buildInfoRow(Icons.volume_up, 'Türkçe sesli geri bildirim'),
            _buildInfoRow(Icons.warning, 'Tehlike önceliklendirmesi'),
            _buildInfoRow(Icons.accessibility, 'Erişilebilirlik odaklı'),
            const Divider(color: Colors.white24),
            const Text(
              'Demo Modu',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bu demo modunda simüle edilmiş algılamalar gösterilmektedir.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tamam',
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid pattern painter for camera simulation
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 30.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
