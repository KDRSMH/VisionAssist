#!/bin/bash

# YOLOv5 Model Kurulum Scripti

echo "🚀 YOLOv5 Nano Kurulum Başlıyor..."
echo ""

# Renk kodları
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Model klasörünü kontrol et
if [ ! -d "assets/models" ]; then
    echo -e "${RED}❌ assets/models klasörü bulunamadı!${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Gereksinimler:${NC}"
echo "1. Eğitilmiş YOLOv5n.tflite modeli (416x416, Float32)"
echo "2. labels.txt dosyası (her satırda bir sınıf ismi)"
echo ""

# Model kontrolü
if [ ! -f "assets/models/yolov5n.tflite" ]; then
    echo -e "${RED}⚠️  Model dosyası bulunamadı: assets/models/yolov5n.tflite${NC}"
    echo ""
    echo -e "${YELLOW}Model nasıl hazırlanır:${NC}"
    echo "1. Google Colab'da YOLOv5 eğitin"
    echo "2. TFLite export edin:"
    echo "   python export.py --weights best.pt --include tflite --img 416"
    echo "3. Model dosyasını kopyalayın:"
    echo "   cp best-fp16.tflite assets/models/yolov5n.tflite"
    echo ""
    exit 1
fi

# Labels kontrolü
if [ ! -f "assets/labels.txt" ]; then
    echo -e "${RED}⚠️  Labels dosyası bulunamadı: assets/labels.txt${NC}"
    echo ""
    echo "Örnek labels.txt oluşturuluyor..."
    cat > assets/labels.txt << EOF
araba
motor
insan
kaldırım
basamak
kedi
köpek
bisiklet
ağaç
koltuk
masa
EOF
    echo -e "${GREEN}✅ Örnek labels.txt oluşturuldu${NC}"
    echo "   Kendi sınıf isimlerinizle güncelleyin!"
    echo ""
fi

# Model boyutunu kontrol et
MODEL_SIZE=$(stat -f%z "assets/models/yolov5n.tflite" 2>/dev/null || stat -c%s "assets/models/yolov5n.tflite" 2>/dev/null)
MODEL_SIZE_MB=$((MODEL_SIZE / 1024 / 1024))

echo -e "${GREEN}✅ Model bulundu: ${MODEL_SIZE_MB}MB${NC}"

# Labels sayısını kontrol et
LABEL_COUNT=$(grep -c . assets/labels.txt)
echo -e "${GREEN}✅ Labels bulundu: ${LABEL_COUNT} sınıf${NC}"

# Flutter build
echo ""
echo -e "${YELLOW}🔨 Flutter build başlıyor...${NC}"
flutter clean
flutter pub get

echo ""
echo -e "${GREEN}✅ Kurulum tamamlandı!${NC}"
echo ""
echo -e "${YELLOW}📱 Uygulamayı çalıştırmak için:${NC}"
echo "   flutter run"
echo ""
echo -e "${YELLOW}📊 Model Bilgileri:${NC}"
echo "   Input Size: 416x416"
echo "   Input Type: Float32 [0-1]"
echo "   Classes: ${LABEL_COUNT}"
echo "   Confidence Threshold: 0.4"
echo "   NMS Threshold: 0.45"
echo ""
