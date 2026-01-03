# YOLOv5 Nano Model

**Dosya:** `yolov5n.tflite`
**Boyut:** ~14 MB
**Format:** TensorFlow Lite Float32
**Giriş:** [1, 416, 416, 3] - RGB görüntü
**Çıkış:** [1, 10647, 13] - Detections

## Sınıflar (8 adet)
0. insan (person)
1. bisiklet (bicycle)
2. araba (car)
3. motosiklet (motorcycle)
4. kedi (cat)
5. köpek (dog)
6. sandalye (chair)
7. masa (dining table)

## Kullanım
- Minimum güven: %45
- Single Focus Mode: Sadece en güvenli nesne algılanır
- Koordinat sistemi: Kamera görüntü boyutuna göre pixel koordinatları
