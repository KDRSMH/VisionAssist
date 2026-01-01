"""
YOLOv5 Nano Training Script for Google Colab
Özel dataset ile YOLOv5n eğitimi ve TFLite export

Kullanım:
1. Google Colab'da bu scripti çalıştır
2. Dataset'ini Roboflow'dan indir veya kendi dataset'ini yükle
3. Eğitim sonrası TFLite modelini indir
"""

# YOLOv5 kurulumu
get_ipython().system('git clone https://github.com/ultralytics/yolov5')
get_ipython().run_line_magic('cd', 'yolov5')
get_ipython().system('pip install -qr requirements.txt')

# PyTorch ve TensorFlow kurulumu
get_ipython().system('pip install -q torch torchvision')
get_ipython().system('pip install -q tensorflow')

print("✅ Kurulum tamamlandı!")

# ============================================
# DATASET HAZIRLIĞI
# ============================================

# Roboflow'dan dataset indir (örnek)
from roboflow import Roboflow

# API key'inizi buraya girin
rf = Roboflow(api_key="YOUR_API_KEY")

# Projenizi seçin
project = rf.workspace("YOUR_WORKSPACE").project("YOUR_PROJECT")
dataset = project.version(1).download("yolov5")

print(f"✅ Dataset indirildi: {dataset.location}")

# ============================================
# EĞİTİM KONFÜGÜRASYONU
# ============================================

# data.yaml dosyasını kontrol et
import yaml

with open(f'{dataset.location}/data.yaml', 'r') as f:
    data_config = yaml.safe_load(f)
    print("\n📊 Dataset Bilgileri:")
    print(f"   Sınıf sayısı: {data_config['nc']}")
    print(f"   Sınıflar: {data_config['names']}")

# ============================================
# MODEL EĞİTİMİ
# ============================================

# YOLOv5n modelini eğit
get_ipython().system(f'python train.py \\
    --img 416 \\
    --batch 16 \\
    --epochs 100 \\
    --data {dataset.location}/data.yaml \\
    --weights yolov5n.pt \\
    --cache \\
    --project runs/train \\
    --name outdoor_detection')

print("\n✅ Eğitim tamamlandı!")

# ============================================
# MODEL EXPORT (TFLite)
# ============================================

# En iyi modeli TFLite'a export et
get_ipython().system('python export.py \\
    --weights runs/train/outdoor_detection/weights/best.pt \\
    --include tflite \\
    --img 416 \\
    --device cpu')

print("\n✅ TFLite export tamamlandı!")
print("\n📦 Model dosyası: runs/train/outdoor_detection/weights/best-fp16.tflite")

# ============================================
# MODEL İNDİRME
# ============================================

from google.colab import files

# TFLite modelini indir
tflite_path = 'runs/train/outdoor_detection/weights/best-fp16.tflite'
files.download(tflite_path)

# Labels.txt oluştur ve indir
labels = data_config['names']
with open('labels.txt', 'w') as f:
    for label in labels:
        f.write(f"{label}\n")

files.download('labels.txt')

print("\n✅ Dosyalar indirildi!")
print("\n📋 Sonraki Adımlar:")
print("1. best-fp16.tflite dosyasını yolov5n.tflite olarak yeniden adlandır")
print("2. Her iki dosyayı da Flutter projesine kopyala:")
print("   - yolov5n.tflite → assets/models/")
print("   - labels.txt → assets/")
print("3. flutter run ile uygulamayı çalıştır")

# ============================================
# MODEL TEST (Opsiyonel)
# ============================================

# Test görüntüsü ile modeli dene
get_ipython().system('python detect.py \\
    --weights runs/train/outdoor_detection/weights/best.pt \\
    --img 416 \\
    --conf 0.25 \\
    --source {dataset.location}/test/images')

print("\n✅ Test tamamlandı!")
print("   Sonuçlar: runs/detect/exp/")

# Sonuçları göster
from IPython.display import Image, display
import glob

test_images = glob.glob('runs/detect/exp/*.jpg')[:5]
for img_path in test_images:
    print(f"\n📸 {img_path}")
    display(Image(filename=img_path, width=600))
