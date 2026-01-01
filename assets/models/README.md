# Model Klasörü

## Yeni Model Ekleme

1. **Model dosyasını** buraya kopyala:
   - Dosya adı: `model.tflite`
   
2. **Label dosyasını** (opsiyonel) buraya ekle:
   - Dosya adı: `labels.txt`
   - Format: Her satırda bir sınıf ismi

3. **Kod güncellemesi** gerekirse:
   - `lib/screens/object_detection_screen.dart` dosyasını aç
   - `_inputSize` parametresini modelinize göre ayarlayın (örn: 320, 416, 640)
   - `_confidenceThreshold` değerini test ederek optimize edin
   - Label mapping'i ekleyin (satır ~280)

## Mevcut Durum

✅ YOLOv8 ve COCO dataset temizlendi
✅ Kod generic hale getirildi
✅ Yeni model için hazır

## Örnek Kullanım

```bash
# Modelinizi buraya kopyalayın
cp /path/to/your/model.tflite assets/models/

# Labels varsa
cp /path/to/your/labels.txt assets/models/

# Flutter'ı yeniden build edin
flutter clean
flutter build apk
```
