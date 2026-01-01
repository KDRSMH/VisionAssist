"""
🎯 HAZIR VERİ SETİ İLE 5 DAKİKADA MODEL EĞİTİMİ
================================================

ADIM 1: Google Colab Açın
-------------------------
https://colab.research.google.com

ADIM 2: Bu Kodu Çalıştırın
--------------------------
"""

# GPU'yu etkinleştirin: Runtime > Change runtime type > GPU

# Kurulum
!pip install ultralytics roboflow -q

from roboflow import Roboflow
from ultralytics import YOLO
from google.colab import files

# ========================================
# VERİ SETİ 1: Obstacle Detection (Önerilen!)
# ========================================
# 2,500+ görüntü, 8 sınıf (person, car, bicycle, etc.)
rf = Roboflow(api_key="YOUR_API_KEY")  
# API Key almak için: roboflow.com > Account > API Key (ücretsiz)

# Hazır veri setini indir
project = rf.workspace("roboflow-universe").project("obstacle-detection-2hljw")
dataset = project.version(1).download("yolov8")

# ========================================
# MODEL EĞİTİMİ
# ========================================
model = YOLO('yolov8n.pt')  # Nano model (hızlı)

# Eğit
results = model.train(
    data=f'{dataset.location}/data.yaml',
    epochs=50,        # 50 epoch (yeterli)
    imgsz=640,
    batch=16,
    device=0,         # GPU
    name='outdoor_v1',
    patience=10,
)

# ========================================
# TFLite EXPORT (Flutter için)
# ========================================
best_model = YOLO('runs/detect/outdoor_v1/weights/best.pt')

# Float32 export
best_model.export(format='tflite', imgsz=640, int8=False, nms=False)

# INT8 export (daha hızlı)
best_model.export(
    format='tflite', 
    imgsz=640, 
    int8=True, 
    nms=False,
    data=f'{dataset.location}/data.yaml'
)

# ========================================
# MODELİ İNDİRİN
# ========================================
# Float32
files.download('runs/detect/outdoor_v1/weights/best_saved_model/best_float32.tflite')

# INT8
files.download('runs/detect/outdoor_v1/weights/best_saved_model/best_int8.tflite')

print("✅ Tamamlandı! Model indirildi.")
print("📱 Şimdi Flutter projesine yükleyin:")
print("   1. İndirilen .tflite dosyasını yolov8n.tflite olarak yeniden adlandırın")
print("   2. /home/kadir/eye-app/assets/models/ klasörüne kopyalayın")
print("   3. flutter clean && flutter run")

"""
========================================
ALTERNATİF VERİ SETLERİ
========================================

VERİ SETİ 2: Urban Street Objects
---------------------------------
- 5,000+ görüntü
- 12 sınıf (traffic lights, poles, barriers, etc.)
project = rf.workspace("visionai").project("urban-street-objects")
dataset = project.version(2).download("yolov8")

VERİ SETİ 3: Pedestrian Detection
----------------------------------
- 3,500+ görüntü
- 6 sınıf (person, wheelchair, stroller, etc.)
project = rf.workspace("pedestrian").project("sidewalk-navigation")
dataset = project.version(1).download("yolov8")

VERİ SETİ 4: Traffic Signs & Lights
------------------------------------
- 10,000+ görüntü
- 43 sınıf (trafik işaretleri)
project = rf.workspace("traffic").project("turkish-traffic-signs")
dataset = project.version(3).download("yolov8")

========================================
ROBOFLOW API KEY ALMA
========================================
1. roboflow.com → Sign Up (Google hesabı ile)
2. Sağ üst → Account Settings
3. Roboflow API → Copy API Key
4. Yukarıdaki kodda "YOUR_API_KEY" yerine yapıştırın

========================================
LABELS DOSYASI OLUŞTURMA
========================================
Eğitim bitince labels dosyası otomatik oluşur.
Bunu da indirin:
"""

# Labels dosyasını kopyala
import shutil
shutil.copy(f'{dataset.location}/data.yaml', 'labels_info.yaml')
files.download('labels_info.yaml')

# Labels.txt oluştur
with open('labels.txt', 'w') as f:
    # data.yaml'dan sınıf isimlerini oku
    import yaml
    with open(f'{dataset.location}/data.yaml', 'r') as y:
        data = yaml.safe_load(y)
        for name in data['names'].values():
            f.write(f"{name}\n")
            
files.download('labels.txt')

print("✅ labels.txt da indirildi!")
