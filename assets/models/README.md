# YOLOv5 Model Placeholder

## Required File: yolov5s.tflite

You need to place your YOLOv5 TFLite model in this directory.

### How to Obtain the Model:

#### Option 1: Pre-trained Model (Recommended)
Download a pre-converted YOLOv5s TFLite model:

1. Visit: https://github.com/ultralytics/yolov5/releases
2. Download `yolov5s-fp16.tflite` or `yolov5s-int8.tflite`
3. Rename to `yolov5s.tflite`
4. Place in this directory (`assets/models/`)

#### Option 2: Convert Your Own Model

```bash
# Install YOLOv5 and conversion tools
pip install ultralytics
pip install tensorflow

# Export YOLOv5 to TFLite
python -m ultralytics.yolo export model=yolov5s.pt format=tflite
```

#### Option 3: Use TensorFlow Hub

Visit: https://tfhub.dev/ and search for "object detection tflite"

### Model Requirements:

- **Input**: 416x416x3 (RGB image)
- **Output**: [1, 25200, 85] 
  - 25200 predictions
  - 85 values per prediction: [x, y, w, h, confidence, 80 class scores]
- **Format**: TFLite (quantized or float)
- **Size**: ~30MB (for YOLOv5s)

### File Structure Should Be:

```
assets/
└── models/
    ├── yolov5s.tflite  ← Place your model here
    └── labels.txt      ← Optional (COCO labels included in code)
```

### Verify Installation:

After placing the model, run:

```bash
flutter clean
flutter pub get
flutter run
```

The app should show "Model yüklendi" (Model loaded) on startup.

### Troubleshooting:

**Error: "Unable to load asset"**
- Ensure `yolov5s.tflite` is exactly in `assets/models/`
- Run `flutter clean && flutter pub get`
- Check `pubspec.yaml` includes assets section

**Error: "Invalid model format"**
- Verify the model is TFLite format (not .pt or .onnx)
- Try a different quantization (fp16 vs int8)

**Model too large**
- Use quantized version (int8) for smaller size
- YOLOv5n (nano) is smaller but less accurate
- Consider on-device model compilation

---

**Note**: This app will not run without a valid TFLite model file.
