# VisionAssist

## Use Case (Kullanım Senaryosu)

### Senaryo Grubu
**SG1: Nesne ve Mesafe Algılama**

### Konu
**VisionAssist Mobil Uygulaması**

---

### Birincil Aktör
**Görme Engelli Kullanıcı**  
(Sistemi başlatan ve asıl faydayı sağlayan kişidir.)

---

### İlgililer ve Beklentileri

- **Kullanıcı:**  
  Çevresindeki engelleri veya nesneleri sesli olarak duymak, çarpışmaları önlemek, nesnelerin ne kadar uzakta ve hangi yönde olduğunu (sağ/sol) anlamak.

- **Geliştirici:**  
  Uygulamanın pil tüketimini optimize etmek, uygulamanın donmadan ve performanslı çalışmasını sağlamak.

- **Bakım / Destek Ekibi:**  
  Kamera açılmaması gibi hata durumlarında sistemin çökmemesini bekler.

---

### Ön Koşullar

- Uygulama cihaza yüklenmiş ve çalıştırılmıştır.
- Kullanıcı, uygulamanın kamera erişim iznini onaylamıştır.

---

### Ana Başarılı Senaryo (Temel Akış)

1. Kullanıcı VisionAssist uygulamasını başlatır.
2. Sistem, cihazın arka kamerasını başlatır ve canlı görüntüyü ekrana yansıtır.
3. Sistem, kameradan gelen görüntüleri sürekli olarak analiz etmeye başlar.
4. Kullanıcı kamerayı çevresine doğru tutar.
5. Sistem, görüntü karesinde bir veya birden fazla nesne (örn: insan, sandalye) tespit eder.
6. Sistem, tespit edilen nesnenin konumunu (sağ/sol/orta) ve tahmini mesafesini (yakın/uzak) hesaplar.
7. Sistem, tespit edilen nesnenin etrafına görsel bir kutu çizer ve bilgi panelini günceller.
8. Sistem, tespit edilen nesnenin ismini, yönünü ve mesafesini Türkçe olarak sesli okur.
9. Kullanıcı veya sistem uygulamayı kapatana kadar 4–8 arasındaki adımlar döngüsel olarak devam eder.

---

### Son Koşullar

- Kullanıcı, ortamdaki nesneler hakkında sesli geri bildirim almıştır.
- Ekranda tespit edilen nesneler görsel kutucuklarla işaretlenmiştir.
- Sistem bekleme moduna geçmiş veya kullanıcı kapatana kadar taramaya devam etmiştir.

---

### Uzantılar (Alternatif Akışlar)

**2a. Kamera izni reddedilir veya kamera başlatılamaz:**
- Sistem hata mesajı gösterir.
- Görüntü işleme fonksiyonları devre dışı bırakılır.
- Kullanıcıya boş veya gri bir ekran gösterilir.

**5a. Tanımlı bir nesne algılanamaz (Güven oranı < %50):**
- Sistem ekrandaki görsel kutuları temizler.
- Sesli geri bildirim yapılmaz.
- Akış 3. adımdan devam eder.

**8a. Aynı nesne kısa süre önce seslendirilmiştir (Cooldown durumu):**
- Sistem nesneyi görsel olarak göstermeye devam eder.
- Sesli bildirim atlanır.
- Akış 3. adımdan devam eder.

**Kullanıcı herhangi bir anda “Durdur” butonuna basar:**
- Sistem kamera akışını ve nesne taramayı duraklatır.
- Bilgi panelinde “Tarama Durduruldu” mesajı gösterilir.
- Kullanıcı “Başlat” butonuna basana kadar sistem bekleme modunda kalır.

---

### Özel İstekler (Kalite Kriterleri)

- **Performans:** Görüntü işleme ve hesaplamalar arayüzü dondurmamalıdır.
- **Geri Bildirim Hızı:** Sesli uyarılar gerçek zamanlıya yakın verilmelidir.
- **Kullanılabilirlik:** Arayüz elemanları net ve anlaşılır olmalıdır.
- **Dil Desteği:** Sesli geri bildirimler Türkçe (tr-TR) olmalıdır.

---

### Teknolojik Beklentiler

- Uygulama Android ve iOS platformlarında çalışmalıdır.
- Kamera çözünürlüğü orta seviyede tutulmalıdır.
- Nesne tanıma için hafif ve mobil uyumlu bir TFLite modeli kullanılmalıdır.

---

## Proje Amacı

- Görme engelli bireylerin çevresindeki nesneleri algılamasını sağlamak
- Çarpışma ve tehlike risklerini azaltmak
- Nesnelerin yaklaşık mesafesi ve konumu hakkında sesli bilgilendirme yapmak
- İnternet bağlantısına ihtiyaç duymadan çalışabilen bir mobil yardımcı sistem geliştirmektir

---

## Sistem Tanımı

- Mobil cihaz kamerası üzerinden gerçek zamanlı görüntü alınır
- Görüntüler ön işleme (frame preprocessing) aşamasından geçirilir
- YOLOv8 TFLite modeli ile nesne tespiti yapılır
- Güven skoru (confidence) eşik değerine göre filtreleme uygulanır
- Algılanan nesneler için mesafe/yakınlık tahmini yapılır
- Yeni ve anlamlı nesneler Türkçe Text-to-Speech ile seslendirilir

---

## Fonksiyonel Gereksinimler

- **FR-1:** Sistem, mobil cihaz kamerası üzerinden gerçek zamanlı görüntü almalıdır
- **FR-2:** Sistem, YOLOv8 modeli ile nesne tespiti yapmalıdır
- **FR-3:** Algılanan nesneler için güven skoru hesaplanmalıdır
- **FR-4:** Güven skoru belirlenen eşik değerin altında olan nesneler yok sayılmalıdır
- **FR-5:** Algılanan nesneler için mesafe/yakınlık filtresi uygulanmalıdır
- **FR-6:** Aynı nesne tekrar algılandığında gereksiz sesli bildirim yapılmamalıdır
- **FR-7:** Algılanan nesneler Türkçe TTS ile sesli olarak kullanıcıya bildirilmelidir
- **FR-8:** Sistem internet bağlantısı olmadan çalışmalıdır

---

## Fonksiyonel Olmayan Gereksinimler

- **NFR-1:** Sistem düşük gecikme süresi ile çalışmalıdır
- **NFR-2:** Mobil cihaz kaynakları (pil, işlemci) verimli kullanılmalıdır
- **NFR-3:** Görme engelli kullanıcılar için sade ve anlaşılır bir kullanım sunmalıdır
- **NFR-4:** Uzun süreli kullanımda kararlı çalışmalıdır
- **NFR-5:** Model boyutu ve çıkarım süresi mobil cihazlara uygun şekilde optimize edilmelidir

---

## Kısıtlar

- Sistem yalnızca mobil cihaz üzerinde çalışacaktır
- Derin öğrenme modeli TFLite formatında kullanılacaktır
- İnternet bağlantısı gerektirmemelidir

---

## Sistem Akışı (Özet)

- Uygulama başlatılır
- Kamera açılır ve frame alınır
- YOLO  modeli ile nesne tespiti yapılır
- Güven skoru ve mesafe filtresi uygulanır
- Yeni nesne algılandığında sesli bildirim gönderilir

---

## Kullanılan Teknolojiler

- Flutter
- YOLO
- TensorFlow Lite (TFLite)
- Mobil Kamera API
- Offline Text-to-Speech (TTS)

---

## Activity Diagram (Sistem Çalışma Akışı)

1. Kullanıcı uygulamayı başlatır
2. Mobil cihaz kamerası aktif hale getirilir
3. Kamera üzerinden sürekli olarak görüntü kareleri (frame) alınır
4. Alınan her frame üzerinde YOLO tabanlı nesne tespiti gerçekleştirilir
5. Algılanan nesneler için güven skoru (confidence) hesaplanır
6. Güven skoru belirlenen eşik değerin altında olan nesneler elenir
7. Eşik değeri geçen nesneler için mesafe/yakınlık filtreleme işlemi uygulanır
8. Sistem, algılanan nesnenin daha önce bildirilip bildirilmediğini kontrol eder
9. Nesne yeni ise Türkçe sesli bildirim oluşturulur
10. Sesli bildirim kullanıcıya iletilir
11. Sistem döngüsel olarak yeni frame alarak çalışmaya devam eder

---

## Pipeline Diagram (Sistem Mimarisi)

### 1. Camera Plugin
Mobil cihaz kamerası aracılığıyla gerçek zamanlı görüntü alınmasını sağlar. Kamera plugin’i, uygulamanın çevreyi sürekli olarak algılayabilmesi için frame tabanlı veri üretir

### 2. Frame Preprocessing
Kameradan alınan görüntü kareleri, nesne tespiti öncesinde ön işleme aşamasından geçirilir. Bu aşamada görüntü yeniden boyutlandırılır, normalize edilir ve YOLOv8 modelinin giriş formatına uygun hale getirilir

### 3. YOLO TFLite Model
Ön işlenmiş görüntüler, TensorFlow Lite formatına dönüştürülmüş YOLOv8 modeli ile işlenir. Bu aşamada nesnelerin sınıfları, konumları ve güven skorları hesaplanır. Model, mobil cihaz üzerinde çevrimdışı olarak çalışmaktadır.

### 4. Post Processing
Model çıktıları üzerinde Non-Maximum Suppression (NMS) ve güven skoru eşikleme işlemleri uygulanır. Bu sayede çakışan bounding box’lar elenir ve düşük doğruluklu tahminler sistemden çıkarılır

### 5. Distance Estimation
Filtrelenen nesneler için yaklaşık mesafe/yakınlık tahmini yapılır. Bu adım, kullanıcının çevresindeki nesnelerin konumuna dair daha anlamlı bir geri bildirim almasını sağlar

### 6. Text to Speech (TTS)
Mesafe filtresinden geçen ve yeni olarak algılanan nesneler, Türkçe Text-to-Speech modülü aracılığıyla sesli mesaja dönüştürülür

### 7. User
Oluşturulan sesli bildirimler, mobil cihaz hoparlörü aracılığıyla kullanıcıya iletilir. Kullanıcı, çevresindeki nesneler hakkında anlık ve sesli bilgi alır

