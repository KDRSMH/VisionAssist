# YOLOv8 Deployment Guide

## STEP 3: Integration & Deployment

### File Placement

After generating the YOLOv8 model using the Python command from STEP 1, place it here:

```
/home/kadir/eye-app/assets/models/yolov8n.tflite
```

### Verification Commands

```bash
# 1. Verify model file exists and is valid
ls -lh ~/eye-app/assets/models/yolov8n.tflite
file ~/eye-app/assets/models/yolov8n.tflite

# Expected output:
# ~6MB file size
# File type: data (TFLite models show as generic data, not ELF)

# 2. Update Flutter dependencies
cd ~/eye-app
flutter pub get

# 3. Clean build cache (important!)
flutter clean

# 4. Run on device
flutter run --device-id=R5CY51ZV0KF
```

---

## What Was Updated

### 1. **Model Parameters** (object_detection_screen.dart)
```dart
static const int _inputSize = 640;           // 300 → 640 (YOLOv8 standard)
static const double _confidenceThreshold = 0.50;  // Balanced for accuracy
static const double _iouThreshold = 0.45;         // Standard NMS
static const double _minBboxArea = 2500.0;       // 50x50 pixels at 640x640
```

### 2. **Model Loading**
```dart
_interpreter = await Interpreter.fromAsset(
  'assets/models/yolov8n.tflite',  // Changed from detect.tflite
  options: options,
);
```

### 3. **Preprocessing** (_preprocessYOLOv8)
- Input: 640x640 RGB
- **Normalization: [0, 1]** (dividing by 255.0)
- Returns: `List<List<List<List<double>>>>`

### 4. **Inference** (_runInferenceYOLOv8)
- Output tensor: **[1, 84, 8400]**
- 84 attributes = 4 bbox + 80 classes
- 8400 predictions from multi-scale grid

### 5. **Output Parsing** (_parseYOLOv8Output)
**CRITICAL TRANSPOSE LOGIC:**
```dart
// YOLOv8 format: [Attributes x Detections]
for (int i = 0; i < 8400; i++) {
  // Extract class scores from rows 4-83
  for (int c = 0; c < 80; c++) {
    final score = rawOutput[4 + c][i];  // Note: [row][column]
  }
  
  // Extract bbox from rows 0-3
  cx = rawOutput[0][i];
  cy = rawOutput[1][i];
  w = rawOutput[2][i];
  h = rawOutput[3][i];
}
```

**Bbox Conversion:**
- Input: (cx, cy, w, h) normalized [0, 1]
- Output: (top, left, bottom, right) for screen mapping

### 6. **pubspec.yaml**
```yaml
assets:
  - assets/models/yolov8n.tflite
  - assets/models/labels.txt
```

---

## Testing Checklist

After deploying:

1. **Model Loading**
   - Check logs for: `✓ YOLOv8 input: [1, 640, 640, 3] float32`
   - Check logs for: `✓ YOLOv8 output: [1, 84, 8400] float32`

2. **Detection Test**
   - Point camera at a **fork**
   - Expected: "Çatal" announcement at ~60-90% confidence
   - NOT: "Bıçak" (knife), "Muz" (banana), or other wrong labels

3. **Accuracy Verification**
   - Test with: person, bottle, laptop, cell phone
   - Should get correct Turkish labels
   - Confidence should be 50%+

4. **Performance**
   - Inference time: ~300-500ms per frame (acceptable on mobile)
   - No crashes or freezes
   - Smooth camera preview

---

## Troubleshooting

### Issue: "The model is not a valid Flatbuffer buffer"
**Solution:** The `.tflite` file is corrupted. Re-generate using:
```python
from ultralytics import YOLO
model = YOLO('yolov8n.pt')
model.export(format='tflite', imgsz=640, int8=False)
```

### Issue: No detections appearing
**Solutions:**
1. Lower confidence threshold to 0.30 temporarily
2. Check lighting (ortam çok karanlık error?)
3. Verify model file size (~6MB, not 13MB or 0 bytes)

### Issue: Wrong labels (still hallucinating)
**Solutions:**
1. Increase confidence to 0.60
2. Increase min bbox area to 3000
3. Verify you're using the CORRECT YOLOv8 model (not the corrupt Yolo-v8-Detection.tflite)

### Issue: App crashes on startup
**Solutions:**
1. `flutter clean && flutter pub get`
2. Check asset path in pubspec.yaml
3. Verify model file exists at exact path

---

## Expected Performance

| Metric | Value |
|--------|-------|
| Input Size | 640x640 |
| Inference Time | 300-500ms |
| Model Size | ~6MB |
| Classes | 80 COCO |
| Accuracy | >85% on common objects |
| False Positives | <5% at 50% confidence |

---

## Success Criteria

✅ Model loads without errors  
✅ Fork detected as "Çatal" (not banana/knife)  
✅ Person detected as "İnsan"  
✅ Bottle detected as "Şişe"  
✅ Confidence scores 50-95%  
✅ No "unknown" labels for common objects  
✅ Smooth camera preview  
✅ Turkish TTS announcements working  

**If all criteria pass, the YOLOv8 migration is successful!**
