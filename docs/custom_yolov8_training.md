# 🎓 Görme Engelli Asistanı İçin Özel YOLOv8 Modeli Eğitimi

## 📋 1. Veri Hazırlığı

### Önerilen Sınıflar (Classes)
```yaml
# data.yaml
names:
  0: insan          # Yayalar
  1: araba          # Arabalar
  2: bisiklet       # Bisikletler
  3: motosiklet     # Motorsikletler
  4: cop_kutusu     # Çöp kutuları
  5: kaldirim       # Kaldırım kenarı
  6: basamak        # Merdiven/basamaklar
  7: rampa          # Engelli rampaları
  8: kapi           # Kapılar/girişler
  9: trafik_isigi   # Trafik ışıkları
  10: yol_isareti   # Yol işaretleri
  11: direk         # Elektrik/telefon direkleri
  12: bank          # Banklar
  13: durak         # Otobüs durakları
  14: agac          # Ağaçlar (baş seviyesi)
  15: engel         # Tanımlanmamış engeller
```

### Roboflow'da Proje Oluşturma
1. [roboflow.com](https://roboflow.com) → Ücretsiz hesap
2. "Create New Project" → "Gorme Engelli Asistani"
3. "Object Detection" seçin
4. Yukarıdaki sınıfları ekleyin
5. Fotoğrafları yükleyin ve etiketleyin

**İpucu:** Her sınıf için en az 50-100 örnek olmalı!

---

## 🚀 2. Google Colab'de Eğitim

### Colab Notebook Kodu:

```python
# ==========================================
# ADIM 1: YOLOv8 Kurulumu
# ==========================================
!pip install ultralytics roboflow

from ultralytics import YOLO
from roboflow import Roboflow
import os

# ==========================================
# ADIM 2: Veri Setini İndirin (Roboflow'dan)
# ==========================================
rf = Roboflow(api_key="ROBOFLOW_API_KEYINIZ")
project = rf.workspace("YOUR_WORKSPACE").project("gorme-engelli-asistani")
dataset = project.version(1).download("yolov8")

# ==========================================
# ADIM 3: data.yaml Dosyasını Kontrol Edin
# ==========================================
!cat {dataset.location}/data.yaml

# ==========================================
# ADIM 4: Model Eğitimi (Transfer Learning)
# ==========================================
# YOLOv8n (nano) modelini kullan - daha hızlı
model = YOLO('yolov8n.pt')  

# Eğitim parametreleri
results = model.train(
    data=f'{dataset.location}/data.yaml',
    epochs=100,              # 100 epoch (artırabilirsiniz)
    imgsz=640,               # 640x640 görüntü boyutu
    batch=16,                # Batch size (GPU'nuza göre ayarlayın)
    name='gorme_engelli_v1', # Model adı
    patience=15,             # Early stopping
    save=True,
    device=0,                # GPU kullan (Colab'de)
    workers=8,
    project='runs/detect',
    
    # Augmentation (veri artırma)
    hsv_h=0.015,            # Renk tonu
    hsv_s=0.7,              # Doygunluk
    hsv_v=0.4,              # Parlaklık
    degrees=10,             # Rotasyon
    translate=0.1,          # Kaydırma
    scale=0.5,              # Ölçekleme
    flipud=0.0,             # Dikey çevirme (KAPALI)
    fliplr=0.5,             # Yatay çevirme
    mosaic=1.0,             # Mozaik augmentation
)

# ==========================================
# ADIM 5: Model Değerlendirme
# ==========================================
# Eğitim sonuçlarını göster
results.plots()

# Validation
val_results = model.val()
print(f"mAP50: {val_results.box.map50}")
print(f"mAP50-95: {val_results.box.map}")

# ==========================================
# ADIM 6: TFLite Export (Flutter için)
# ==========================================
# En iyi modeli yükle
best_model = YOLO('runs/detect/gorme_engelli_v1/weights/best.pt')

# Float32 TFLite export
best_model.export(
    format='tflite',
    imgsz=640,
    int8=False,  # Float32
    nms=False,   # NMS kapalı
)

# INT8 TFLite export (daha hızlı)
best_model.export(
    format='tflite',
    imgsz=640,
    int8=True,   # INT8 quantization
    nms=False,
    data=f'{dataset.location}/data.yaml',  # Calibration için
)

print("✅ Modeller kaydedildi:")
print("   - Float32: runs/detect/gorme_engelli_v1/weights/best_saved_model/best_float32.tflite")
print("   - INT8: runs/detect/gorme_engelli_v1/weights/best_saved_model/best_int8.tflite")

# ==========================================
# ADIM 7: Test Görüntüsü ile Deneme
# ==========================================
# Test görüntüsü yükleyin
!wget https://example.com/test_image.jpg -O test.jpg

# Tahmin yap
results = best_model.predict(
    source='test.jpg',
    conf=0.25,  # Confidence threshold
    save=True,
    show_labels=True,
    show_conf=True,
)

# Sonuçları göster
from IPython.display import Image, display
display(Image('runs/detect/predict/test.jpg'))
```

---

## 📥 3. Modeli Flutter'a Aktarma

### a) TFLite Modelini İndirin
```python
# Colab'den indir
from google.colab import files

# Float32 model
files.download('runs/detect/gorme_engelli_v1/weights/best_saved_model/best_float32.tflite')

# INT8 model
files.download('runs/detect/gorme_engelli_v1/weights/best_saved_model/best_int8.tflite')
```

### b) Labels Dosyasını Oluşturun
```bash
# Linux/Mac terminalinde:
cat > custom_labels.txt << 'EOF'
insan
araba
bisiklet
motosiklet
cop_kutusu
kaldirim
basamak
rampa
kapi
trafik_isigi
yol_isareti
direk
bank
durak
agac
engel
EOF
```

### c) Flutter Projesine Ekleyin
```bash
# Terminal'de:
cd /home/kadir/eye-app/assets/models/

# Eski modelleri yedekle
mv yolov8n.tflite yolov8n_coco_backup.tflite
mv labels.txt labels_coco_backup.txt

# Yeni modeli kopyala
cp ~/Downloads/best_float32.tflite yolov8n.tflite
cp custom_labels.txt labels.txt

# Temizle ve çalıştır
cd ../..
flutter clean
flutter run --device-id=R5CY51ZV0KF
```

---

## 📊 4. Model Performansını İyileştirme

### Eğitim Sırasında:
- **mAP < 0.5**: Daha fazla veri ekleyin
- **Overfit**: Daha fazla augmentation ekleyin
- **Underfit**: Daha fazla epoch, daha büyük model (yolov8s)

### Eğitimden Sonra:
```python
# Hiperparametre optimizasyonu
model.tune(
    data='data.yaml',
    epochs=30,
    iterations=300,
    device=0,
)
```

### Veri Artırma (Data Augmentation):
```python
# Daha agresif augmentation
results = model.train(
    # ... diğer parametreler ...
    augment=True,
    mixup=0.1,      # Mixup augmentation
    copy_paste=0.1, # Copy-paste augmentation
)
```

---

## 🎯 5. Hızlı Başlangıç (Hazır Dataset Kullanarak)

Kendi verinizi toplamadan önce test etmek için:

```python
# Option 1: COCO'dan sadece outdoor sınıfları filtrele
from ultralytics import YOLO

model = YOLO('yolov8n.pt')

# COCO'da olan outdoor sınıflar:
# 0: person, 2: car, 3: motorcycle, 5: bus, 7: truck
# 9: traffic light, 11: stop sign, 13: bench

# Bu sınıfları kullan
outdoor_classes = [0, 2, 3, 5, 7, 9, 11, 13]

# Filtreleyerek export et
# (Bu özellik yok ama labels dosyasını düzenleyebilirsiniz)
```

```python
# Option 2: Cityscapes dataset kullan (şehir görüntüleri)
# https://www.cityscapes-dataset.com/

# Option 3: BDD100K dataset (sürüş verileri)
# https://bdd-data.berkeley.edu/
```

---

## ⚡ 6. Hızlı Test İçin Örnek

Kendi veriniz yoksa bu küçük örnekle başlayın:

```python
# 20 fotoğraf + etiket ile test
# Her sınıftan 2-3 örnek
# 20 epoch eğitim
# Sonuç: ~0.3-0.4 mAP (düşük ama çalışır)

# Gerçek kullanım için:
# - Sınıf başına 100+ örnek
# - 100+ epoch
# - Hedef: >0.6 mAP
```

---

## 🔗 Faydalı Kaynaklar

- **Roboflow**: https://roboflow.com (Ücretsiz etiketleme)
- **YOLOv8 Docs**: https://docs.ultralytics.com
- **Colab**: https://colab.research.google.com
- **Labelme**: https://github.com/wkentaro/labelme (Offline etiketleme)
- **CVAT**: https://www.cvat.ai (Gelişmiş etiketleme)

---

## 💡 İpuçları

1. **Veri Kalitesi > Veri Miktarı**: 100 iyi etiketli fotoğraf, 500 kötü etiketliden iyidir
2. **Dengeli Dataset**: Her sınıftan eşit sayıda örnek
3. **Çeşitlilik**: Farklı açılar, ışık, hava durumu
4. **Türkiye'ye Özel**: Türk arabaları, sokakları, işaretleri
5. **Test Et**: Eğitimden sonra gerçek ortamda test edin

---

## 🚀 Sonraki Adımlar

1. Roboflow hesabı açın
2. 50-100 fotoğraf çekin (Türkiye sokakları)
3. Etiketleyin (30 dakika)
4. Colab'de eğitin (2-3 saat)
5. Flutter'a aktarın
6. Test edin!

**Başarılar!** 🎉
