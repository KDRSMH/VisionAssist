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
