# Gereksinim Analizi

## 1. Giriş
Bu doküman, görme engelli bireyler için geliştirilen
YOLOv8 tabanlı mobil nesne tanıma ve sesli bildirim uygulamasının
fonksiyonel ve fonksiyonel olmayan gereksinimlerini tanımlar.

## 2. Sistem Tanımı
Sistem, mobil cihaz kamerasından alınan görüntüleri
offline olarak işleyen, YOLOv8 derin öğrenme modeli ile
nesne tespiti yapan ve algılanan nesneleri Türkçe
sesli bildirim ile kullanıcıya aktaran bir mobil uygulamadır.

## 3. Fonksiyonel Gereksinimler
FR-1: Sistem kamera üzerinden gerçek zamanlı görüntü almalıdır.  
FR-2: Sistem YOLOv8 modeli ile nesne tespiti yapmalıdır.  
FR-3: Algılanan nesneler için güven skoru hesaplanmalıdır.  
FR-4: Belirlenen eşik değerinin altındaki nesneler yok sayılmalıdır.  
FR-5: Aynı nesne tekrar algılandığında gereksiz sesli bildirim yapılmamalıdır.  
FR-6: Algılanan nesneler Türkçe TTS ile seslendirilmelidir.  
FR-7: Sistem internet bağlantısı olmadan çalışmalıdır.  

## 4. Fonksiyonel Olmayan Gereksinimler
NFR-1: Sistem düşük gecikme süresi ile çalışmalıdır.  
NFR-2: Mobil donanım kaynaklarını verimli kullanmalıdır.  
NFR-3: Kullanıcı arayüzü görme engellilere uygun olmalıdır.  
NFR-4: Uygulama uzun süreli kullanımda kararlı çalışmalıdır.  

## 5. Kısıtlar
- Sistem mobil cihaz donanımı ile sınırlıdır.
- Model boyutu ve inference süresi optimize edilmelidir.
- İnternet bağlantısı gerektirmemelidir.