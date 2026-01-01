# YOLOv5n Model Placeholder

Bu dosya bir placeholder'dır. Gerçek YOLOv5n.tflite modelinizi buraya kopyalayın.

## Model Eğitimi ve Export

1. **Google Colab'da YOLOv5 eğitin**
2. **TFLite'a export edin:**
   ```python
   python export.py --weights runs/train/exp/weights/best.pt --include tflite --img 416
   ```
3. **Model dosyasını buraya kopyalayın:**
   ```bash
   cp best-fp16.tflite assets/models/yolov5n.tflite
   ```

## Gerekli Format

- **Input**: [1, 416, 416, 3] Float32
- **Output**: [1, N_anchors, N_classes + 5]
- **Normalizasyon**: [0.0 - 1.0]

Model hazır olduğunda bu dosyayı silin ve gerçek .tflite dosyasını koyun.
