🚀 Proje: VisionAssist - 5 Aşamalı Geliştirme Planı



AŞAMA 1: İskelet ve Dış Görünüş (UI & Proje Kurulumu)

Hedef: Uygulamanın "kutusunu" hazırlamak. Henüz içinde bir zeka veya kamera çalışmayacak, sadece tasarımın nasıl görüneceğini kodlayacağız.

Ne Yapacağız?

    Yeni bir Flutter projesi oluşturacağız (flutter create vision_assist).

    pubspec.yaml dosyasına gerekli kütüphaneleri ekleyeceğiz (şimdiden hazır olsunlar):

        camera (Gözler)

        tflite_flutter (Beyin)

        flutter_tts (Ses)

        Görüntü işleme için image paketi de gerekebilir.

    Arayüz Tasarımı (En Önemli Kısım):

        Ana ekranda bir Stack widget'ı kullanacağız. Stack, katmanlar üst üste koymamızı sağlar.

        En Alt Katman: Şimdilik gri bir Container olacak (İleride buraya kamera gelecek).

        Orta Katman: Tespit edilen nesnelerin etrafına çizilecek kutular için şeffaf bir alan (Şimdilik boş bir Stack veya CustomPaint).

        En Üst Katman (Bilgi Paneli): Ekranın altına, son konuştuğumuz o şık, yuvarlatılmış köşeli bilgi çubuğunu ve Durdur/Başlat butonunu ekleyeceğiz. İçine statik (sabit) bir metin yazacağız: "Örnek: İnsan sağınızda, yaklaşık 2 metre."





Aşama 1 Sonunda Ne Göreceksin? Uygulamayı çalıştırdığında gri bir arka plan üzerinde, alt tarafta senin tasarladığın şık bilgi çubuğu ve butonlar görünecek. Hiçbir şey hareket etmeyecek ama sahne hazır olacak.
AŞAMA 2: Gözleri Açmak (Kamera Entegrasyonu)

Hedef: O gri arka planı kaldırıp yerine gerçek dünyayı, yani canlı kamera görüntüsünü koymak.

Ne Yapacağız?

    main.dart dosyasını StatefulWidget'a çevireceğiz (çünkü kamera durumu sürekli değişecek).

    Uygulama açıldığında (initState) kamera izni isteyeceğiz.

    Cihazdaki kameraları listeleyip arka kamerayı seçeceğiz.

    Kamerayı başlatacağız (cameraController.initialize()). Kritik Detay: Çözünürlüğü çok yüksek tutmamalıyız (örn. ResolutionPreset.medium yeterli), yoksa yapay zeka zorlanır.

    Aşama 1'deki gri Container yerine CameraPreview(controller) widget'ını koyacağız.





Aşama 2 Sonunda Ne Göreceksin? Uygulama açıldığında kameran çalışacak ve ekranda canlı görüntüyü göreceksin. Alt taraftaki bilgi çubuğu hala sabit duruyor olacak. Telefonu hareket ettirdiğinde görüntü akıcı olmalı.
AŞAMA 3: Beyin Nakli ve İlk Sinyaller (Model Yükleme ve Veri Akışı)

Hedef: YOLOv8 modelini (.tflite dosyası) uygulamaya tanıtmak ve kameradan gelen görüntüleri ona göndermeye başlamak. En zor teknik aşama burasıdır.

Ne Yapacağız?

    İndirdiğin yolov8n.tflite dosyasını projenin assets/models/ klasörüne koyup pubspec.yaml'da tanıtacağız.

    tflite_flutter paketini kullanarak modeli yükleyen bir fonksiyon yazacağız.

    Kameranın startImageStream özelliğini açacağız. Bu, kameranın gördüğü her kareyi (frame) bize saniyede yaklaşık 30 kez bir fonksiyon içinde verecek.

    En Zor Kısım (Köprü Kurmak): Kameradan gelen ham veri (YUV formatı) ile modelin istediği veri (RGB 416x416 boyutu) aynı değildir. Gelen görüntüyü dönüştürecek bir ara katman kodu yazacağız.

    Dönüştürülen görüntüyü modele vereceğiz (interpreter.run(...)).






Aşama 3 Sonunda Ne Göreceksin? Ekranda görsel bir değişiklik olmayacak. Ancak uygulamanın "Log" (Konsol) ekranına baktığında, saniyede 30 kere akan, anlamsız görünen devasa sayı dizileri (Tensor çıktıları) göreceksin. Bu, beynin çalıştığını gösterir.
AŞAMA 4: Çevirmen - Matematiği Anlama Dönüştürme (Konumsal Farkındalık)

Hedef: Modelden gelen o anlamsız sayıları alıp; "İnsan", "Sağda", "2 Metre" gibi anlamlı bilgilere çevirmek ve ekrana çizdirmek.

Ne Yapacağız?

    Tensor Çözümleme (Parsing): Modelin çıktısı olan [1, 84, 8400] boyutundaki devasa diziyi döngüye sokup, güven oranı (confidence) %50'nin üzerinde olan kutuları ayıklayacağız.

    Gürültü Temizleme (NMS): Aynı nesne için çizilen üst üste 10 kutuyu teke indireceğiz.

    Konum Hesaplama (Senin İstediğin Özellik):

        Tespit edilen kutunun orta noktasını (X koordinatı) bulacağız. Ekranın genişliğine bölüp "Sağ/Sol/Orta" kararını vereceğiz.

        Kutunun yüksekliğini, ekran yüksekliğine oranlayıp "Çok yakın/Yakın/Uzak" tahmini yapacağız.

    Arayüzü Güncelleme: Hesapladığımız bu bilgileri (örn. "Sandalye - Ortada - Uzak") alıp, Aşama 1'de yaptığımız bilgi panelindeki metni anlık olarak güncelleyeceğiz (setState ile). Ayrıca nesnenin etrafına kutu çizdireceğiz.







Aşama 4 Sonunda Ne Göreceksin? Artık uygulama görüyor! Kamerayı bir insana tuttuğunda etrafında kutu çıkacak ve alttaki panelde "İnsan önünüzde, yaklaşık 1 metre" gibi dinamik bir yazı yazacak.
AŞAMA 5: Ses Verme ve Performans Ayarı (Final)

Hedef: Uygulamayı konuşturmak ve donmaları engellemek.

Ne Yapacağız?

    flutter_tts kütüphanesini başlatıp dili Türkçe (tr-TR) yapacağız.

    Konuşma Mantığı (Cooldown): Aşama 4'te elde ettiğimiz metni doğrudan sese verirsek uygulama susmadan konuşur ve kafa şişirir. Şöyle bir mantık kuracağız:

        "Eğer son 3 saniyedir aynı şeyi söylemediysem VE tespit edilen nesne önemli bir nesneyse (insan, araba gibi) KONUŞ."

    Performans (Isolate): Aşama 3 ve 4'teki işlemler (görüntü çevirme, matematiksel hesaplar) ana ekranı yorabilir ve kamera görüntüsü takılabilir. Bu işlemleri "Isolate" dediğimiz arka plan işçisine devredeceğiz.






Aşama 5 Sonunda Ne Göreceksin (Proje Bitti): Uygulama akıcı bir şekilde çalışacak. Kamerayı çevirdiğinde gördüğü nesneleri, yönlerini ve tahmini mesafelerini Türkçe olarak, seni bunaltmayacak bir sıklıkta söyleyecek.