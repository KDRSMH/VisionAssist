# Quick Start Guide - Görme Engelli Asistanı

## 🚀 Getting Started in 3 Steps

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Add YOLOv5 Model
1. Download YOLOv5s TFLite model
2. Place it in: `assets/models/yolov5s.tflite`
3. See [assets/models/README.md](assets/models/README.md) for download instructions

### Step 3: Run the App
```bash
flutter run
```

---

## 📱 Supported Platforms

- ✅ Android (API 21+)
- ✅ iOS (12.0+)
- ❌ Web (Camera streaming not supported)
- ❌ Desktop (Limited camera support)

---

## 🎯 Quick Test (Without Model)

To verify the app structure works before adding the model:

1. Comment out model loading in `lib/screens/object_detection_screen.dart`:
```dart
// await _loadTFLiteModel();
setState(() {
  _isModelLoaded = true; // Fake it for testing UI
  _currentStatusText = 'Test modu';
});
```

2. Run the app - you should see:
   - Camera preview
   - Start/Stop button
   - Status panel

---

## 🔧 Configuration Checklist

### Android (`android/app/src/main/AndroidManifest.xml`)
- [x] Camera permissions added
- [x] App label updated to Turkish

### iOS (`ios/Runner/Info.plist`)
- [x] Camera usage description added
- [x] Speech/microphone permissions added

### Assets (`pubspec.yaml`)
- [x] Model path configured
- [x] Labels file included

---

## 📚 Full Documentation

See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for:
- Complete architecture details
- Customization options
- Performance optimization
- Troubleshooting guide

---

## ⚡ Testing Without Physical Device

**Emulator Limitations:**
- Android Emulator: Camera works but slow
- iOS Simulator: Camera **NOT** available

**Recommendation**: Use physical device for best results

---

## 🐛 Common Issues

### "Model not found" error
→ Ensure `yolov5s.tflite` is in `assets/models/`
→ Run `flutter clean && flutter pub get`

### Camera not working
→ Check permissions granted
→ Use physical device (not simulator)

### No TTS sound
→ Check device volume
→ Install Turkish language pack on device
→ Test with: `await _flutterTts?.speak('Test');`

---

## 📖 Code Structure

```
lib/
├── main.dart                        # Entry point
├── screens/
│   └── object_detection_screen.dart # Main screen (500+ lines)
├── models/
│   └── detection_result.dart        # Data model
└── utils/
    ├── bounding_box_painter.dart    # CustomPainter
    └── detection_helper.dart        # YOLO utilities
```

**Total Lines of Code**: ~1000+ lines

---

## 🎨 Key Features Implemented

✅ **STEP 1**: Camera + TFLite + TTS initialization  
✅ **STEP 2**: Multi-layer Stack UI with accessibility  
✅ **STEP 3**: Image stream processing  
✅ **STEP 4**: Light level detection  
✅ **STEP 5**: Image preprocessing (YUV→RGB, resize, normalize)  
✅ **STEP 6-7**: YOLO inference and parsing  
✅ **STEP 8**: Non-Maximum Suppression (NMS)  
✅ **STEP 9**: Priority-based sorting  
✅ **STEP 10**: English → Turkish translation  
✅ **STEP 11**: TTS debouncing (2-second cooldown)  
✅ **STEP 12**: UI updates with bounding boxes  
✅ **STEP 13**: Start/Stop controls  

---

## 🚀 Next Steps

1. Download model → Place in `assets/models/`
2. Run on physical device
3. Grant camera permissions
4. Test in well-lit environment
5. Customize priorities in `detection_helper.dart`

---

**Need Help?** Check [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed documentation.
