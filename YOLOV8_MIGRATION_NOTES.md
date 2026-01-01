# YOLOv8 Migration Notes

## Current Status

**The "Yolo-v8-Detection.tflite" file in assets/models is CORRUPTED!**

The file is actually an Android ELF binary (.so library), not a valid TensorFlow Lite FlatBuffer model. This is why you see the error:
```
E/tflite: The model is not a valid Flatbuffer buffer
```

## What's Working NOW

**SSD MobileNet v1** (`detect.tflite` - 4.0MB) is a proven, working model that:
- ✅ Loads correctly
- ✅ Runs fast on mobile (300x300 input)
- ✅ Detects 80 COCO classes accurately
- ✅ Has been tested and validated

## Optimized Parameters for Accuracy

For the **best balance between accuracy and detection**, use these settings in `object_detection_screen.dart`:

```dart
// RECOMMENDED SETTINGS
static const int _inputSize = 300;
static const double _confidenceThreshold = 0.60;  // 60% - Good accuracy, fewer false positives
static const double _iouThreshold = 0.40;         // Remove overlapping duplicates
static const double _minBboxArea = 1500.0;        // Filter very small objects (39x39 pixels)
```

### Why These Values?

1. **Confidence 60%**: Higher than 50% reduces false positives (fork→knife, bottle→clock), but still allows real detections
2. **IOU 40%**: Balanced NMS - removes duplicates without being too aggressive
3. **Area 1500px**: At 300x300 input, this is ~39x39 pixels - filters noise while keeping real objects

## If You REALLY Want YOLOv8

### Option 1: Download Pre-trained YOLOv8n from Ultralytics

```bash
# Install ultralytics
pip install ultralytics

# Export YOLOv8n to TFLite
from ultralytics import YOLO
model = YOLO('yolov8n.pt')
model.export(format='tflite')
```

This creates `yolov8n_saved_model/yolov8n_float32.tflite`

### Option 2: Use Online Converter

1. Go to https://netron.app
2. Drag the "Yolo-v8-Detection.tflite" file
3. If it shows "not a valid model", download fresh from:
   - https://github.com/ultralytics/ultralytics (official)
   - Use their export function

### YOLOv8 Code Changes Required

If you get a valid YOLOv8 model, the code already has the functions:
- `_preprocessYOLOv8()` - normalizes to [0,1]
- `_runInferenceYOLOv8()` - handles [1, 84, 8400] output
- `_parseYOLOv8Output()` - parses transposed format

Just update:
1. Input size: 300 → 640
2. Model path: `detect.tflite` → `yolov8n.tflite`
3. Call `_preprocessYOLOv8` and `_runInferenceYOLOv8` instead of SSD versions

## Recommendation

**STICK WITH SSD MobileNet** with the optimized 60% threshold. It's:
- Proven and working
- Fast (300x300 vs 640x640)
- Accurate enough for your use case
- No migration headaches

Test with a fork first - if it correctly says "Ç" (Fork) at 60%+, you're good!
