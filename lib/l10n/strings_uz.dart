part of 'strings.dart';

/// Узбекский.
class _Uz extends S {
  const _Uz();

  @override
  String get tagline => 'Kompaniyangiz telefoni';
  @override
  String get server => 'Server';
  @override
  String get number => 'Raqam';
  @override
  String get password => 'Parol';
  @override
  String get signIn => 'Kirish';
  @override
  String get signInQr => 'QR-kod orqali kirish';
  @override
  String get qrHint =>
      "Telefon kamerasini administrator bergan QR-kodga qarating — SADO kirish shakli toʻldirilgan holda ochiladi.";
  @override
  String get soon => 'Tez orada';
  @override
  String get fieldRequired => 'Maydonni toʻldiring';

  @override
  String get tabDial => 'Terish';
  @override
  String get tabHistory => 'Tarix';
  @override
  String get tabContacts => 'Kontaktlar';
  @override
  String get tabMore => 'Yana';

  @override
  String online(String number) => '$number · aloqada';
  @override
  String get call => 'Qoʻngʻiroq';
  @override
  String get calling => 'Chaqirilmoqda…';

  @override
  String get history => 'Tarix';
  @override
  String get filterAll => 'Hammasi';
  @override
  String get filterMissed => 'Javobsiz';
  @override
  String get missed => 'javobsiz';
  @override
  String minutes(int n) => '$n daq';
  @override
  String get yesterday => 'kecha';

  @override
  String get contacts => 'Kontaktlar';
  @override
  String get searchHint => 'Ism yoki raqam';
  @override
  String get employees => 'Xodimlar';
  @override
  String get departments => 'Boʻlimlar';
  @override
  String get statusFree => 'boʻsh';
  @override
  String get statusBusy => 'gaplashmoqda';
  @override
  String get statusOffline => 'tarmoqda emas';
  @override
  String get group => 'guruh';
  @override
  String get nothingFound => 'Hech kim topilmadi';

  @override
  String get incomingCall => 'Kiruvchi qoʻngʻiroq';
  @override
  String get unknownCaller => 'Nomaʼlum raqam';
  @override
  String get decline => 'Rad etish';
  @override
  String get accept => 'Qabul qilish';
  @override
  String get answerVerb => 'Javob berish';
  @override
  String get replyText => 'Xabar bilan javob';
  @override
  String get silent => 'Ovozsiz';
  @override
  String get secureHd => 'Himoyalangan qoʻngʻiroq · HD';
  @override
  String get mic => 'Mikrofon';
  @override
  String get keypad => 'Klaviatura';
  @override
  String get speaker => 'Dinamik';
  @override
  String get soundOutput => 'Ovoz chiqishi';
  @override
  String get outputEarpiece => 'Telefon';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Quloqchin';
  @override
  String get hold => 'Kutish';
  @override
  String get onHold => 'Kutish rejimida';
  @override
  String get secondCall => 'Ikkinchi qoʻngʻiroq';
  @override
  String get swapCalls => 'Almashtirish';
  @override
  String get talkFirst => 'Avval gaplashish';
  @override
  String get connectCalls => 'Ulash';
  @override
  String get mergeCalls => 'Birlashtirish';
  @override
  String get conference => 'Konferensiya';
  @override
  String get record => 'Yozib olish';
  @override
  String get recordingOn => 'Yozilmoqda';
  @override
  String get failConnect => 'Ulab boʻlmadi';
  @override
  String get inCall => 'Suhbat davom etmoqda';
  @override
  String get transfer => 'Oʻtkazish';
  @override
  String get addCall => 'Qoʻshish';
  @override
  String get hangUp => 'Tugatish';

  @override
  String get settings => 'Sozlamalar';
  @override
  String get style => 'Uslub';
  @override
  String get theme => 'Mavzu';
  @override
  String get themeSystem => 'Avto';
  @override
  String get themeLight => 'Yorugʻ';
  @override
  String get themeDark => 'Qorongʻi';
  @override
  String get themeAlwaysDark => 'Bu uslub doim qorongʻi';
  @override
  String get language => 'Til';
  @override
  String get langSystem => 'Avto';
  @override
  String get account => 'Hisob';
  @override
  String get signOut => 'Chiqish';
  @override
  String get demo => 'Namoyish';
  @override
  String get demoIncoming => 'Kiruvchi qoʻngʻiroqni koʻrsatish';
  @override
  String get demoNote => 'Bu ATSsiz namoyish: qoʻngʻiroqlar haqiqiy emas, kontaktlar va tarix — namuna.';
  @override
  String get tryDemo => 'Serversiz koʻrish';
  @override
  String get insecureServer =>
      "ws:// manzili shifrlanmaydi: tarmoqda kim kimga qoʻngʻiroq qilayotgani koʻrinadi, parolni esa tanlab topish mumkin. Server qoʻllasa, wss:// dan foydalaning.";
  @override
  String get setupFilled =>
      'Maʼlumotlar havola orqali olindi. Server manzilini tekshiring va «Kirish» tugmasini bosing.';
  @override
  String get setupSignedIn => 'Siz allaqachon kirgansiz. Havolani qoʻllash uchun avval hisobdan chiqing.';
  @override
  String get pasteSetup => 'Sozlash havolasini qoʻyish';
  @override
  String get noSetupInClipboard => 'Buferda sozlash havolasi yoʻq';
  @override
  String get scanHint => 'Kamerani administrator bergan QR-kodga qarating';
  @override
  String get scanNotSetup => 'Bu QR-kodda SADO sozlash havolasi yoʻq';
  @override
  String get scanNoCamera =>
      'Kameraga ruxsat yoʻq. Telefon sozlamalarida ruxsat bering yoki kodga telefon kamerasini qarating.';
  @override
  String get signingIn => 'Ulanmoqda…';
  @override
  String get errAuth => 'Raqam yoki parol notoʻgʻri';
  @override
  String get errNetwork => 'Server javob bermayapti. Manzil va internetni tekshiring';
  @override
  String get errOther => 'Kirib boʻlmadi';
  @override
  String linkConnecting(String number) => '$number · ulanmoqda…';
  @override
  String linkOffline(String number) => '$number · aloqa yoʻq';
  @override
  String linkAuth(String number) => '$number · kirish xatosi';
  @override
  String seconds(int n) => '$n soniya';
  @override
  String get historyEmpty => 'Qoʻngʻiroqlaringiz shu yerda koʻrinadi';
  @override
  String get contactsLater =>
      'Xodimlar roʻyxati ilova uni serverdan olishni oʻrganganda paydo boʻladi. Hozircha terish ekranidan qoʻngʻiroq qiling.';
  @override
  String get failBusy => 'Band';
  @override
  String get failRejected => 'Qoʻngʻiroq rad etildi';
  @override
  String get failNoAnswer => 'Javob bermayapti';
  @override
  String get failUnavailable => 'Abonent mavjud emas';
  @override
  String get failMic => 'Mikrofonga ruxsat yoʻq. Telefon sozlamalarida ruxsat bering';
  @override
  String get failOffline => 'ATS bilan aloqa yoʻq';
  @override
  String get failOther => 'Qoʻngʻiroq amalga oshmadi';

  @override
  String get swipeUpToAnswer => "Yuqoriga — javob berish";
  @override
  String get swipeDownToDecline => "Pastga — rad etish";
  @override
  String get slideToAnswer => "Javob berish uchun suring";
  @override
  String get answerBy => "Qoʻngʻiroqqa javob";
  @override
  String get answerButtons => "Tugmalar";
  @override
  String get answerSwipe => "Tepaga-pastga surish";
  @override
  String get answerSlider => "Oʻngga slayder";
  @override
  String get iconSet => "Belgilar";
  @override
  String get iconsOutlined => "Konturli";
  @override
  String get iconsFilled => "Toʻliq";
  @override
  String get iconsRounded => "Yumshoq";

  @override
  String get background => "Fondagi qoʻngʻiroqlar";
  @override
  String get backgroundOn => "Qabul qilish";
  @override
  String get backgroundOff => "Qabul qilmaslik";
  @override
  String get backgroundNote =>
      "Ilova yigʻilgan holatda ham aloqada qoladi: pardada jim bildirishnoma turadi, batareya biroz tezroq sarflanadi.";
  @override
  String get pushWake => 'Qoʻngʻiroqda uygʻotish (sinov rejimi)';
  @override
  String get pushWakeNote =>
      'Ilova doimiy aloqada turmaydi: qoʻngʻiroq kelganda ATS telefonni Google orqali push-xabar bilan uygʻotadi. Batareya kamroq sarflanadi, qoʻngʻiroq bir necha soniya kechroq ulanadi. Faqat ATS administratori buni qoʻllab-quvvatlashini tasdiqlagan boʻlsa yoqing — aks holda fondagi qoʻngʻiroqlar yetib kelmaydi.';
  @override
  String get systemCalls => 'Tizim qoʻngʻiroqlari (sinov rejimi)';
  @override
  String get systemCallsNote =>
      'Telefon SADO qoʻngʻiroqlaridan xabardor boʻladi: garnitura tugmalari, avtomobil va soat ishlaydi, oddiy mobil qoʻngʻiroq esa ovozni uzmasdan suhbatni kutishga qoʻyadi. Rejim yangi — ovozda muammo boʻlsa, uni oʻchiring.';
  @override
  String get batteryAsk => "Batareya cheklovini olib tashlash";
  @override
  String get batteryOk => "Batareya cheklovi olib tashlangan";
  @override
  String get autostartAsk => "Fonda ishlashga ruxsat berish";
  @override
  String get autostartNote =>
      "Xiaomi, Samsung, Huawei, Oppo va Vivo telefonlari ilovalarni oʻzi yopadi va kiruvchi qoʻngʻiroqlar kelmay qoladi. Ochilgan roʻyxatda SADO uchun avtomatik ishga tushish yoki cheklovsiz ishlashga ruxsat bering.";
  @override
  String get notifAsk => "Bildirishnomalarga ruxsat berish";
  @override
  String get notifNote =>
      "Bildirishnomalarsiz ilova yigʻilgan paytda kiruvchi qoʻngʻiroq jiringlamaydi va koʻrinmaydi.";
  @override
  String get missedCallTitle => "Oʻtkazib yuborilgan qoʻngʻiroq";
  @override
  String missedCallsTitle(int count) => "Oʻtkazib yuborilgan qoʻngʻiroqlar: $count";
  @override
  String get fullScreenAsk => "Qoʻngʻiroq ekranini qulf ustida koʻrsatishga ruxsat berish";
  @override
  String get fullScreenNote => "Busiz qulflangan telefonda kiruvchi qoʻngʻiroq faqat bildirishnomada koʻrinadi.";
  @override
  String get tabHome => "Bosh sahifa";
  @override
  String get tabKeypad => "Klaviatura";
  @override
  String get today => "Bugun";
  @override
  String get yesterdayTitle => "Kecha";
  @override
  String get earlier => "Avvalroq";
  @override
  String get answerAuto => "Uslubga mos";
  @override
  String get appIcon => "Ish stolidagi belgi";

  @override
  String get about => "Ilova haqida";
  @override
  String versionLabel(String version) => "Versiya $version";
  @override
  String get checkUpdates => "Yangilanishlarni tekshirish";
  @override
  String get updateNote => "Tekshiruv GitHub orqali va faqat tugma bosilganda bajariladi.";
  @override
  String get upToDate => "Sizda eng soʻnggi versiya";
  @override
  String updateAvailable(String version) => "$version versiyasi chiqdi";
  @override
  String get openDownload => "Yuklab olish sahifasini ochish";
  @override
  String get updateFailed => "Tekshirib boʻlmadi. Keyinroq urinib koʻring.";

  @override
  String get answerPill => "Yon tomonga surish";
  @override
  String get newContact => "Yangi kontakt";
  @override
  String get editContact => "Kontaktni oʻzgartirish";
  @override
  String get contactName => "Ism";
  @override
  String get save => "Saqlash";
  @override
  String get delete => "Oʻchirish";
  @override
  String get cancel => "Bekor qilish";
  @override
  String get noContacts => "Kontaktlar hali yoʻq";
  @override
  String get showPhoneContacts => "Telefon kontaktlarini koʻrsatish";
  @override
  String get fromPhone => "Telefondan";
  @override
  String get myContacts => 'Oʻz kontaktlarim';
  @override
  String get phoneContactsTitle => "Telefon kontaktlari";
  @override
  String get saveToContacts => "Kontaktlarga saqlash";
  @override
  String get transferTitle => "Qoʻngʻiroqni oʻtkazish";
  @override
  String get transferHint => "Oʻtkaziladigan raqam";
  @override
  String get dnd => "Bezovta qilmang";
  @override
  String get dndOn => "Yoqilgan";
  @override
  String get dndOff => "Oʻchirilgan";
  @override
  String get dndNote =>
      "Kiruvchi qoʻngʻiroqlar jiringlamaydi, qoʻngʻiroq qiluvchi «band» signalini eshitadi. Javobsizlar tarixda koʻrinadi.";
  @override
  String get ringtone => "Qoʻngʻiroq ohangi";
  @override
  String get ringtoneDefault => "Telefondagidek";
  @override
  String get ringVibration => "Qoʻngʻiroqda tebranish";
  @override
  String get redialHint => "Qoʻngʻiroq qilish uchun yana bir marta bosing";
  @override
  String dndStatus(String number) => "$number · bezovta qilmang";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Zumrad',
    SadoStyleId.night => 'Tun',
    SadoStyleId.air => 'Havo',
    SadoStyleId.sunset => 'Shafaq',
    SadoStyleId.cupertino => 'Kupertino',
    SadoStyleId.material => 'Material',
  };
}
