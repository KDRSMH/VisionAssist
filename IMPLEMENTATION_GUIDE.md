# Real-Time Object Detection App for Visually Impaired Users

A Flutter application that provides real-time object detection with text-to-speech feedback designed specifically for visually impaired users.

## Features

### Core Functionality
- **Real-time Object Detection**: Uses YOLOv5 TFLite model for fast, accurate detection
- **Turkish TTS Support**: All detected objects announced in Turkish
- **Accessibility-First Design**: Optimized for screen readers and visually impaired users
- **Smart Prioritization**: Danger objects (vehicles, stairs) announced first
- **Light Detection**: Warns when environment is too dark
- **Debounced Announcements**: Prevents overwhelming repeated announcements

### Accessibility Features
- ✅ **ExcludeSemantics** on camera preview (reduces screen reader noise)
- ✅ **MergeSemantics** on status panel (aggregates information)
- ✅ **Large, high-contrast UI** elements
- ✅ **Descriptive semantic labels** on all interactive elements
- ✅ **56x56px minimum touch targets**
- ✅ **Color-coded visual feedback** (Red=Danger, Yellow=Caution, Green=Normal)

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Download YOLOv5 Model

You need to add a YOLOv5 TFLite model to the project:

1. Create the assets directory:
```bash
mkdir -p assets/models
```

2. Download YOLOv5s TFLite model:
   - Option A: Use pre-converted model from [TensorFlow Hub](https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/1)
   - Option B: Convert your own using [this guide](https://github.com/ultralytics/yolov5/issues/251)

3. Place the model file:
```
assets/models/yolov5s.tflite
```

4. Create labels file (optional):
```bash
cat > assets/models/labels.txt << 'EOF'
person
bicycle
car
motorcycle
airplane
bus
train
truck
boat
traffic light
fire hydrant
stop sign
parking meter
bench
bird
cat
dog
horse
sheep
cow
elephant
bear
zebra
giraffe
backpack
umbrella
handbag
tie
suitcase
frisbee
skis
snowboard
sports ball
kite
baseball bat
baseball glove
skateboard
surfboard
tennis racket
bottle
wine glass
cup
fork
knife
spoon
bowl
banana
apple
sandwich
orange
broccoli
carrot
hot dog
pizza
donut
cake
chair
couch
potted plant
bed
dining table
toilet
tv
laptop
mouse
remote
keyboard
cell phone
microwave
oven
toaster
sink
refrigerator
book
clock
vase
scissors
teddy bear
hair drier
toothbrush
EOF
```

### 3. Platform-Specific Configuration

#### Android (AndroidManifest.xml)

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-feature android:name="android.hardware.camera"/>
    <uses-feature android:name="android.hardware.camera.autofocus"/>
    
    <application ...>
        ...
    </application>
</manifest>
```

Minimum SDK version in `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Required for camera2 API
    }
}
```

#### iOS (Info.plist)

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Çevrenizi algılamak ve nesneleri tanımlamak için kamera erişimi gereklidir</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Algılanan nesneleri sesli olarak bildirmek için konuşma izni gereklidir</string>
```

Minimum deployment target in `ios/Podfile`:
```ruby
platform :ios, '12.0'
```

## Architecture

### File Structure

```
lib/
├── main.dart                           # App entry point
├── screens/
│   └── object_detection_screen.dart    # Main detection screen
├── models/
│   └── detection_result.dart           # Detection data model
└── utils/
    ├── bounding_box_painter.dart       # Custom painter for boxes
    └── detection_helper.dart           # YOLO parsing & NMS logic
```

### Implementation Flow (Per Flowchart)

**STEP 1: Initialization**
- Initialize `CameraController` with back camera
- Load YOLOv5 TFLite model using `tflite_flutter`
- Setup `FlutterTts` with Turkish language

**STEP 2: UI Layout (Stack-based)**
- Layer 1: `ExcludeSemantics(CameraPreview)` - Hidden from screen readers
- Layer 2: `CustomPaint(BoundingBoxPainter)` - Visual bounding boxes
- Layer 3: `MergeSemantics(StatusPanel)` - High-contrast text display
- Layer 4: `FloatingActionButton` - Start/Stop control (56x56px)

**STEP 3: Start Image Stream**
- Call `controller.startImageStream()`
- Process frames asynchronously

**STEP 4: Light Control**
- Calculate average luminance from Y-plane (YUV420)
- Threshold: < 50 = too dark
- Update UI and speak warning

**STEP 5: Pre-processing**
- Convert YUV420 → RGB
- Resize to 416x416
- Normalize to [0, 1]
- *(Recommended: Use Isolate for heavy processing)*

**STEP 6 & 7: Inference & Parsing**
- Run `interpreter.run(input, output)`
- Parse output: [25200, 85] tensor
- Extract bounding boxes and class scores

**STEP 8: Post-Processing (NMS)**
- Apply Non-Maximum Suppression
- IoU threshold: 0.45
- Remove duplicate detections

**STEP 9: Prioritization**
- Sort by:
  1. Priority (High → Medium → Low)
  2. Box area (proximity)
  3. Confidence score

**STEP 10: Translation**
- Map English labels → Turkish
- Example: 'person' → 'İnsan'

**STEP 11: TTS Control (Debouncing)**
- Track last spoken time per object
- Only speak if > 2 seconds elapsed
- Prevents overwhelming announcements

**STEP 12: Update UI**
- Redraw bounding boxes
- Update status panel
- Trigger TTS if needed

**STEP 13: Stop Detection**
- Call `controller.stopImageStream()`
- Clear detections
- Update UI state

## Usage

### Running the App

```bash
# Development mode
flutter run

# Release mode (optimized)
flutter run --release

# Specific device
flutter run -d <device_id>
```

### For Blind Users

1. **Starting Detection**:
   - App announces "Nesne algılama hazır" on launch
   - Detection starts automatically
   - Listen for object announcements

2. **Controlling Detection**:
   - Large Start/Stop button at bottom-right
   - Screen reader label: "Algılamayı Durdur" / "Algılamayı Başlat"
   - Double-tap to toggle

3. **Understanding Announcements**:
   - High priority (immediate): Vehicles, obstacles
   - Medium priority: People, animals
   - Low priority: Other objects
   - Objects only announced every 2 seconds (debounced)

4. **Light Warning**:
   - If too dark: "Ortam çok karanlık" announcement
   - Move to better-lit area

## Customization

### Adjust Detection Threshold

In [object_detection_screen.dart](lib/screens/object_detection_screen.dart):

```dart
static const double _confidenceThreshold = 0.5; // 0.0 to 1.0
```

### Change Debounce Time

```dart
static const Duration _speakDebounceTime = Duration(seconds: 2);
```

### Add Custom Priority Objects

In [detection_helper.dart](lib/utils/detection_helper.dart):

```dart
static const Set<String> _highPriorityObjects = {
  'car', 'bus', 'truck', 'motorcycle', 'bicycle', 'train',
  'stairs', // Add your custom objects
};
```

### Modify Colors

In [bounding_box_painter.dart](lib/utils/bounding_box_painter.dart):

```dart
Color _getColorForDetection(DetectionResult detection) {
  switch (detection.priority) {
    case DetectionPriority.high:
      return Colors.red;      // Customize here
    case DetectionPriority.medium:
      return Colors.yellow;
    case DetectionPriority.low:
      return Colors.green;
  }
}
```

## Performance Optimization

### Current Optimizations
- ✅ YUV420 format for efficient camera streaming
- ✅ Sample-based luminance calculation (every 10th pixel)
- ✅ NMS to reduce duplicate detections
- ✅ Debounced TTS to prevent spam

### Recommended Improvements
- [ ] Implement Isolate-based image preprocessing
- [ ] Use GPU delegate for TFLite inference
- [ ] Frame skipping (process every 2nd or 3rd frame)
- [ ] ROI-based processing (focus on center region)

### Example: Enable GPU Delegate

```dart
final interpreterOptions = InterpreterOptions()
  ..addDelegate(GpuDelegateV2());

_interpreter = await Interpreter.fromAsset(
  'assets/models/yolov5s.tflite',
  options: interpreterOptions,
);
```

## Troubleshooting

### Camera Not Working
- Check permissions in AndroidManifest.xml / Info.plist
- Verify `permission_handler` grants camera access
- Test on physical device (not emulator)

### Model Not Loading
- Ensure `yolov5s.tflite` is in `assets/models/`
- Verify `pubspec.yaml` includes assets section
- Run `flutter clean && flutter pub get`

### TTS Not Speaking
- Check device volume
- Verify Turkish language support (iOS/Android settings)
- Test with `await _flutterTts?.speak('Test');`

### Poor Performance
- Use `--release` mode, not debug
- Enable GPU delegate
- Reduce input size (e.g., 320x320 instead of 416x416)
- Skip frames in image stream

## Contributing

Contributions are welcome! Areas for improvement:

- [ ] Add more Turkish translations
- [ ] Implement Isolate-based preprocessing
- [ ] Add haptic feedback for detections
- [ ] Support for offline operation
- [ ] Battery optimization
- [ ] Custom model training for specific objects

## License

MIT License - See LICENSE file for details

## Acknowledgments

- YOLOv5 by Ultralytics
- TFLite Flutter Plugin
- Flutter Camera Plugin
- Flutter TTS Plugin

---

**Built with ❤️ for accessibility**
