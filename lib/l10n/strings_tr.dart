part of 'strings.dart';

/// Турецкий.
class _Tr extends S {
  const _Tr();

  @override
  String get tagline => 'Şirketinizin telefonu';
  @override
  String get server => 'Sunucu';
  @override
  String get number => 'Dahili numara';
  @override
  String get password => 'Şifre';
  @override
  String get signIn => 'Giriş yap';
  @override
  String get signInQr => 'QR kodla giriş yap';
  @override
  String get qrHint =>
      'Telefonun kamerasını yöneticinizden aldığınız QR koda tutun: SADO, giriş bilgileri doldurulmuş olarak açılır.';
  @override
  String get soon => 'Çok yakında';
  @override
  String get fieldRequired => 'Bu alanı doldurun';

  @override
  String get tabDial => 'Tuşlar';
  @override
  String get tabHistory => 'Son aramalar';
  @override
  String get tabContacts => 'Kişiler';
  @override
  String get tabMore => 'Diğer';

  @override
  String online(String number) => '$number · çevrimiçi';
  @override
  String get call => 'Ara';
  @override
  String get calling => 'Aranıyor…';

  @override
  String get history => 'Son aramalar';
  @override
  String get filterAll => 'Tümü';
  @override
  String get filterMissed => 'Cevapsız';
  @override
  String get missed => 'cevapsız';
  @override
  String minutes(int n) => '$n dk';
  @override
  String get yesterday => 'dün';

  @override
  String get contacts => 'Kişiler';
  @override
  String get searchHint => 'Ad veya numara';
  @override
  String get employees => 'Çalışanlar';
  @override
  String get departments => 'Departmanlar';
  @override
  String get statusFree => 'müsait';
  @override
  String get statusBusy => 'görüşmede';
  @override
  String get statusOffline => 'çevrimdışı';
  @override
  String get group => 'grup';
  @override
  String get nothingFound => 'Kimse bulunamadı';

  @override
  String get incomingCall => 'Gelen arama';
  @override
  String get unknownCaller => 'Bilinmeyen numara';
  @override
  String get decline => 'Reddet';
  @override
  String get accept => 'Kabul et';
  @override
  String get answerVerb => 'Cevapla';
  @override
  String get replyText => 'Mesajla yanıtla';
  @override
  String get silent => 'Sessize al';
  @override
  String get secureHd => 'Güvenli arama · HD';
  @override
  String get mic => 'Sessiz';
  @override
  String get keypad => 'Tuşlar';
  @override
  String get speaker => 'Hoparlör';
  @override
  String get soundOutput => 'Ses çıkışı';
  @override
  String get outputEarpiece => 'Telefon';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Kulaklık';
  @override
  String get hold => 'Beklet';
  @override
  String get onHold => 'Beklemede';
  @override
  String get secondCall => 'İkinci arama';
  @override
  String get swapCalls => 'Değiştir';
  @override
  String get talkFirst => 'Önce konuş';
  @override
  String get connectCalls => 'Bağla';
  @override
  String get failConnect => 'Aramalar bağlanamadı';
  @override
  String get inCall => 'Görüşme sürüyor';
  @override
  String get transfer => 'Aktar';
  @override
  String get addCall => 'Ekle';
  @override
  String get hangUp => 'Bitir';

  @override
  String get settings => 'Ayarlar';
  @override
  String get style => 'Stil';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Otomatik';
  @override
  String get themeLight => 'Açık';
  @override
  String get themeDark => 'Koyu';
  @override
  String get themeAlwaysDark => 'Bu stil her zaman koyu';
  @override
  String get language => 'Dil';
  @override
  String get langSystem => 'Otomatik';
  @override
  String get account => 'Hesap';
  @override
  String get signOut => 'Çıkış yap';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Gelen arama göster';
  @override
  String get demoNote => 'Bu, santral olmadan çalışan bir demo: aramalar gerçek değil, kişiler ve geçmiş örnektir.';
  @override
  String get tryDemo => 'Sunucusuz dene';
  @override
  String get insecureServer =>
      'ws:// adresi şifrelenmez: ağdaki başkaları kimin kimi aradığını görebilir ve şifreyi tahmin etmeye çalışabilir. Sunucunuz destekliyorsa wss:// kullanın.';
  @override
  String get setupFilled => 'Bilgiler bir bağlantıdan alındı. Sunucu adresini kontrol edin ve “Giriş yap”a dokunun.';
  @override
  String get setupSignedIn => 'Zaten giriş yaptınız. Bağlantıyı kullanmak için önce çıkış yapın.';
  @override
  String get pasteSetup => 'Kurulum bağlantısını yapıştır';
  @override
  String get noSetupInClipboard => 'Panoda kurulum bağlantısı yok';
  @override
  String get scanHint => 'Kamerayı yöneticinizden aldığınız QR koda tutun';
  @override
  String get scanNotSetup => 'Bu QR kodda SADO kurulum bağlantısı yok';
  @override
  String get scanNoCamera =>
      'Kamera erişimi yok. Telefon ayarlarından izin verin veya kodu telefonun kamerasıyla okutun.';
  @override
  String get signingIn => 'Bağlanıyor…';
  @override
  String get errAuth => 'Dahili numara veya şifre yanlış';
  @override
  String get errNetwork => 'Sunucu yanıt vermiyor. Adresi ve bağlantınızı kontrol edin';
  @override
  String get errOther => 'Giriş yapılamadı';
  @override
  String linkConnecting(String number) => '$number · bağlanıyor…';
  @override
  String linkOffline(String number) => '$number · bağlantı yok';
  @override
  String linkAuth(String number) => '$number · giriş hatası';
  @override
  String seconds(int n) => '$n sn';
  @override
  String get historyEmpty => 'Aramalarınız burada görünecek';
  @override
  String get contactsLater =>
      'Uygulama iş arkadaşlarınızı sunucudan yükleyebildiğinde burada görünecekler. Şimdilik tuşlardan arayın.';
  @override
  String get failBusy => 'Meşgul';
  @override
  String get failRejected => 'Arama reddedildi';
  @override
  String get failNoAnswer => 'Cevap yok';
  @override
  String get failUnavailable => 'Ulaşılamıyor';
  @override
  String get failMic => 'Mikrofon erişimi yok. Telefon ayarlarından izin verin';
  @override
  String get failOffline => 'Santralle bağlantı yok';
  @override
  String get failOther => 'Arama başarısız';

  @override
  String get swipeUpToAnswer => "Cevaplamak için yukarı kaydırın";
  @override
  String get swipeDownToDecline => "Reddetmek için aşağı kaydırın";
  @override
  String get slideToAnswer => "Cevaplamak için kaydırın";
  @override
  String get answerBy => "Aramaları cevaplama";
  @override
  String get answerButtons => "Düğmeler";
  @override
  String get answerSwipe => "Yukarı veya aşağı kaydır";
  @override
  String get answerSlider => "Sağa kaydır";
  @override
  String get iconSet => "Simgeler";
  @override
  String get iconsOutlined => "Çizgili";
  @override
  String get iconsFilled => "Dolgulu";
  @override
  String get iconsRounded => "Yuvarlak";

  @override
  String get background => "Arka planda aramalar";
  @override
  String get backgroundOn => "Al";
  @override
  String get backgroundOff => "Alma";
  @override
  String get backgroundNote =>
      "Uygulama küçültüldüğünde de bağlı kalır: bildirim panelinde sessiz bir bildirim durur ve pil biraz daha hızlı tükenir.";
  @override
  String get batteryAsk => "Pil kısıtlamasını kaldır";
  @override
  String get batteryOk => "Pil kısıtlaması kaldırıldı";
  @override
  String get autostartAsk => "Arka plan etkinliğine izin ver";
  @override
  String get autostartNote =>
      "Xiaomi, Samsung, Huawei, Oppo ve Vivo telefonlar uygulamaları kendiliğinden kapatır ve gelen aramalar ulaşmaz olur. Açılan listede SADO'ya otomatik başlatma veya kısıtlamasız çalışma izni verin.";
  @override
  String get notifAsk => "Bildirimlere izin ver";
  @override
  String get notifNote => "Bildirimler kapalıyken, uygulama arka plandayken gelen arama çalmaz ve görünmez.";
  @override
  String get missedCallTitle => "Cevapsız arama";
  @override
  String missedCallsTitle(int count) => "Cevapsız aramalar: $count";
  @override
  String get fullScreenAsk => "Arama ekranının kilit ekranı üzerinde açılmasına izin ver";
  @override
  String get fullScreenNote => "Bu izin olmadan, kilitli telefonda gelen arama yalnızca bildirim olarak görünür.";
  @override
  String get tabHome => "Ana sayfa";
  @override
  String get tabKeypad => "Tuşlar";
  @override
  String get today => "Bugün";
  @override
  String get yesterdayTitle => "Dün";
  @override
  String get earlier => "Daha önce";
  @override
  String get answerAuto => "Stile göre";
  @override
  String get appIcon => "Ana ekran simgesi";

  @override
  String get about => "Hakkında";
  @override
  String versionLabel(String version) => "Sürüm $version";
  @override
  String get checkUpdates => "Güncellemeleri denetle";
  @override
  String get updateNote => "Denetim GitHub'a bağlanır ve yalnızca siz dokunduğunuzda yapılır.";
  @override
  String get upToDate => "En son sürümü kullanıyorsunuz";
  @override
  String updateAvailable(String version) => "Sürüm $version kullanılabilir";
  @override
  String get openDownload => "İndirme sayfasını aç";
  @override
  String get updateFailed => "Denetlenemedi. Daha sonra tekrar deneyin.";

  @override
  String get answerPill => "Yana kaydır";
  @override
  String get newContact => "Yeni kişi";
  @override
  String get editContact => "Kişiyi düzenle";
  @override
  String get contactName => "Ad";
  @override
  String get save => "Kaydet";
  @override
  String get delete => "Sil";
  @override
  String get cancel => "İptal";
  @override
  String get noContacts => "Henüz kişi yok";
  @override
  String get showPhoneContacts => "Telefon kişilerini göster";
  @override
  String get fromPhone => "Telefondan";
  @override
  String get phoneContactsTitle => "Telefon kişileri";
  @override
  String get saveToContacts => "Kişilere kaydet";
  @override
  String get transferTitle => "Aramayı aktar";
  @override
  String get transferHint => "Aktarılacak numara";
  @override
  String get dnd => "Rahatsız etmeyin";
  @override
  String get dndOn => "Açık";
  @override
  String get dndOff => "Kapalı";
  @override
  String get dndNote =>
      "Gelen aramalar çalmaz, arayan kişi meşgul sesi duyar. Cevapsız aramalar Son aramalar'da kalır.";
  @override
  String get ringtone => "Zil sesi";
  @override
  String get ringtoneDefault => "Telefonun varsayılanı";
  @override
  String get ringVibration => "Çalarken titret";
  @override
  String get redialHint => "Aramak için ara tuşuna tekrar dokunun";
  @override
  String dndStatus(String number) => "$number · rahatsız etmeyin";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Zümrüt',
    SadoStyleId.night => 'Gece',
    SadoStyleId.air => 'Hava',
    SadoStyleId.sunset => 'Gün batımı',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
