import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/demo_data.dart';
import '../theme/sado_style.dart';

/// Все надписи приложения на трёх языках. Получить: `S.of(context)`.
///
/// Сделано обычными классами, без генератора кода: если в одном из языков забыть
/// надпись, приложение просто не соберётся.
abstract class S {
  const S();

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// Как назвать собеседника: имя, а если его нет — номер; если скрыт и номер — «Неизвестный номер».
  String caller(String? name, String number) => name ?? (number.isEmpty ? unknownCaller : formatNumber(number));

  /// Надписи по коду языка — там, где нет экрана (например, для уведомления о звонке).
  static S byCode(String code) => switch (code) {
    'uz' => const _Uz(),
    'en' => const _En(),
    _ => const _Ru(),
  };

  /// Первый язык — запасной, если язык телефона не поддерживается.
  static const supportedLocales = [Locale('ru'), Locale('uz'), Locale('en')];

  // Вход
  String get tagline;
  String get server;
  String get number;
  String get password;
  String get signIn;
  String get signInQr;
  String get soon;
  String get fieldRequired;

  // Нижнее меню
  String get tabDial;
  String get tabHistory;
  String get tabContacts;
  String get tabMore;

  // Набор номера
  String online(String number);
  String get call;
  String get calling;

  // История
  String get history;
  String get filterAll;
  String get filterMissed;
  String get missed;
  String minutes(int n);
  String get yesterday;

  // Контакты
  String get contacts;
  String get searchHint;
  String get employees;
  String get departments;
  String get statusFree;
  String get statusBusy;
  String get statusOffline;
  String get group;
  String get nothingFound;

  // Звонок
  String get incomingCall;
  String get unknownCaller;
  String get decline;
  String get accept;
  String get answerVerb;
  String get replyText;
  String get silent;
  String get secureHd;
  String get mic;
  String get keypad;
  String get speaker;
  String get hold;
  String get onHold;
  String get inCall;
  String get transfer;
  String get addCall;
  String get hangUp;

  // Настройки
  String get settings;
  String get style;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get themeAlwaysDark;
  String get language;
  String get langSystem;
  String get account;
  String get signOut;
  String get demo;
  String get demoIncoming;
  String get demoNote;
  // Вход: ход и ошибки
  String get tryDemo;
  String get insecureServer;
  String get signingIn;
  String get errAuth;
  String get errNetwork;
  String get errOther;

  // Связь с АТС
  String linkConnecting(String number);
  String linkOffline(String number);
  String linkAuth(String number);

  // Пустые списки
  String seconds(int n);
  String get historyEmpty;
  String get contactsLater;

  // Почему звонок не удался
  String get failBusy;
  String get failRejected;
  String get failNoAnswer;
  String get failUnavailable;
  String get failMic;
  String get failOffline;
  String get failOther;

  // Ответ на входящий и значки
  String get swipeUpToAnswer;
  String get swipeDownToDecline;
  String get slideToAnswer;
  String get answerBy;
  String get answerButtons;
  String get answerSwipe;
  String get answerSlider;
  String get iconSet;
  String get iconsOutlined;
  String get iconsFilled;
  String get iconsRounded;

  // Звонки в фоне
  String get background;
  String get backgroundOn;
  String get backgroundOff;
  String get backgroundNote;
  String get batteryAsk;
  String get batteryOk;
  String get autostartAsk;
  String get autostartNote;
  String get notifAsk;
  String get notifNote;
  String get fullScreenAsk;
  String get fullScreenNote;
  String get tabHome;
  String get tabKeypad;
  String get today;
  String get yesterdayTitle;
  String get earlier;
  String get answerAuto;
  String get appIcon;

  // Контакты, перевод, «Не беспокоить»
  String get answerPill;
  String get newContact;
  String get editContact;
  String get contactName;
  String get save;
  String get delete;
  String get cancel;
  String get noContacts;
  String get saveToContacts;
  String get transferTitle;
  String get transferHint;
  String get dnd;
  String get dndOn;
  String get dndOff;
  String get dndNote;
  String get redialHint;
  String dndStatus(String number);

  String styleName(SadoStyleId id);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => const ['ru', 'uz', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture<S>(S.byCode(locale.languageCode));

  @override
  bool shouldReload(_SDelegate old) => false;
}

class _Ru extends S {
  const _Ru();

  @override
  String get tagline => 'Телефон вашей компании';
  @override
  String get server => 'Сервер';
  @override
  String get number => 'Номер';
  @override
  String get password => 'Пароль';
  @override
  String get signIn => 'Войти';
  @override
  String get signInQr => 'Войти по QR-коду';
  @override
  String get soon => 'Скоро появится';
  @override
  String get fieldRequired => 'Заполните поле';

  @override
  String get tabDial => 'Набор';
  @override
  String get tabHistory => 'История';
  @override
  String get tabContacts => 'Контакты';
  @override
  String get tabMore => 'Ещё';

  @override
  String online(String number) => '$number · на связи';
  @override
  String get call => 'Позвонить';
  @override
  String get calling => 'Вызов…';

  @override
  String get history => 'История';
  @override
  String get filterAll => 'Все';
  @override
  String get filterMissed => 'Пропущенные';
  @override
  String get missed => 'пропущен';
  @override
  String minutes(int n) => '$n мин';
  @override
  String get yesterday => 'вчера';

  @override
  String get contacts => 'Контакты';
  @override
  String get searchHint => 'Имя или номер';
  @override
  String get employees => 'Сотрудники';
  @override
  String get departments => 'Отделы';
  @override
  String get statusFree => 'свободен';
  @override
  String get statusBusy => 'разговаривает';
  @override
  String get statusOffline => 'не в сети';
  @override
  String get group => 'группа';
  @override
  String get nothingFound => 'Никого не нашлось';

  @override
  String get incomingCall => 'Входящий звонок';
  @override
  String get unknownCaller => 'Неизвестный номер';
  @override
  String get decline => 'Отклонить';
  @override
  String get accept => 'Принять';
  @override
  String get answerVerb => 'Ответить';
  @override
  String get replyText => 'Ответить текстом';
  @override
  String get silent => 'Без звука';
  @override
  String get secureHd => 'Защищённый звонок · HD';
  @override
  String get mic => 'Микрофон';
  @override
  String get keypad => 'Клавиши';
  @override
  String get speaker => 'Динамик';
  @override
  String get hold => 'Удержать';
  @override
  String get onHold => 'На удержании';
  @override
  String get inCall => 'Идёт разговор';
  @override
  String get transfer => 'Перевести';
  @override
  String get addCall => 'Добавить';
  @override
  String get hangUp => 'Завершить';

  @override
  String get settings => 'Настройки';
  @override
  String get style => 'Стиль';
  @override
  String get theme => 'Тема';
  @override
  String get themeSystem => 'Авто';
  @override
  String get themeLight => 'Светлая';
  @override
  String get themeDark => 'Тёмная';
  @override
  String get themeAlwaysDark => 'Этот стиль всегда тёмный';
  @override
  String get language => 'Язык';
  @override
  String get langSystem => 'Авто';
  @override
  String get account => 'Учётная запись';
  @override
  String get signOut => 'Выйти';
  @override
  String get demo => 'Демонстрация';
  @override
  String get demoIncoming => 'Показать входящий звонок';
  @override
  String get demoNote => 'Это демонстрация без АТС: звонки ненастоящие, контакты и история — образец.';
  @override
  String get tryDemo => 'Посмотреть без сервера';
  @override
  String get insecureServer =>
      "Адрес ws:// не шифруется: в сети видно, кто кому звонит, а пароль можно подобрать. Если сервер умеет, используйте wss://.";
  @override
  String get signingIn => 'Подключение…';
  @override
  String get errAuth => 'Неверный номер или пароль';
  @override
  String get errNetwork => 'Сервер не отвечает. Проверьте адрес и интернет';
  @override
  String get errOther => 'Не удалось войти';
  @override
  String linkConnecting(String number) => '$number · подключение…';
  @override
  String linkOffline(String number) => '$number · нет связи';
  @override
  String linkAuth(String number) => '$number · ошибка входа';
  @override
  String seconds(int n) => '$n сек';
  @override
  String get historyEmpty => 'Здесь появятся ваши звонки';
  @override
  String get contactsLater =>
      'Список сотрудников появится, когда приложение научится брать его с сервера. Пока звоните с экрана набора.';
  @override
  String get failBusy => 'Занято';
  @override
  String get failRejected => 'Звонок отклонён';
  @override
  String get failNoAnswer => 'Не отвечает';
  @override
  String get failUnavailable => 'Абонент недоступен';
  @override
  String get failMic => 'Нет доступа к микрофону. Разрешите его в настройках телефона';
  @override
  String get failOffline => 'Нет связи с АТС';
  @override
  String get failOther => 'Звонок не удался';

  @override
  String get swipeUpToAnswer => "Вверх — ответить";
  @override
  String get swipeDownToDecline => "Вниз — отклонить";
  @override
  String get slideToAnswer => "Проведите, чтобы ответить";
  @override
  String get answerBy => "Ответ на звонок";
  @override
  String get answerButtons => "Кнопки";
  @override
  String get answerSwipe => "Свайп вверх-вниз";
  @override
  String get answerSlider => "Ползунок вправо";
  @override
  String get iconSet => "Значки";
  @override
  String get iconsOutlined => "Контурные";
  @override
  String get iconsFilled => "Плотные";
  @override
  String get iconsRounded => "Мягкие";

  @override
  String get background => "Звонки в фоне";
  @override
  String get backgroundOn => "Принимать";
  @override
  String get backgroundOff => "Не принимать";
  @override
  String get backgroundNote =>
      "Приложение остаётся на связи, когда свёрнуто, и само выходит на связь после перезагрузки телефона. В шторке висит тихое уведомление, батарея расходуется немного быстрее.";
  @override
  String get batteryAsk => "Снять ограничение батареи";
  @override
  String get batteryOk => "Ограничение батареи снято";
  @override
  String get autostartAsk => "Разрешить работу в фоне";
  @override
  String get autostartNote =>
      "Телефоны Xiaomi, Samsung, Huawei, Oppo и Vivo сами закрывают приложения, и входящие перестают доходить. В открывшемся списке разрешите SADO автозапуск или работу без ограничений.";
  @override
  String get notifAsk => "Разрешить уведомления";
  @override
  String get notifNote => "Без уведомлений входящий звонок не зазвонит и не покажется, пока приложение свёрнуто.";
  @override
  String get fullScreenAsk => "Разрешить экран звонка поверх блокировки";
  @override
  String get fullScreenNote => "Без этого на заблокированном телефоне входящий виден только в уведомлении.";
  @override
  String get tabHome => "Главная";
  @override
  String get tabKeypad => "Клавиатура";
  @override
  String get today => "Сегодня";
  @override
  String get yesterdayTitle => "Вчера";
  @override
  String get earlier => "Раньше";
  @override
  String get answerAuto => "Как в стиле";
  @override
  String get appIcon => "Значок на рабочем столе";

  @override
  String get answerPill => "Свайп в стороны";
  @override
  String get newContact => "Новый контакт";
  @override
  String get editContact => "Изменить контакт";
  @override
  String get contactName => "Имя";
  @override
  String get save => "Сохранить";
  @override
  String get delete => "Удалить";
  @override
  String get cancel => "Отмена";
  @override
  String get noContacts => "Контактов пока нет";
  @override
  String get saveToContacts => "Сохранить в контакты";
  @override
  String get transferTitle => "Перевести звонок";
  @override
  String get transferHint => "Номер, на который перевести";
  @override
  String get dnd => "Не беспокоить";
  @override
  String get dndOn => "Включено";
  @override
  String get dndOff => "Выключено";
  @override
  String get dndNote => "Входящие не звонят, звонящий слышит «занято». Пропущенные видны в истории.";
  @override
  String get redialHint => "Нажмите вызов ещё раз, чтобы позвонить";
  @override
  String dndStatus(String number) => "$number · не беспокоить";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Изумруд',
    SadoStyleId.night => 'Ночь',
    SadoStyleId.air => 'Воздух',
    SadoStyleId.sunset => 'Закат',
    SadoStyleId.cupertino => 'Купертино',
    SadoStyleId.material => 'Материал',
  };
}

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
  String get hold => 'Kutish';
  @override
  String get onHold => 'Kutish rejimida';
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

class _En extends S {
  const _En();

  @override
  String get tagline => 'Your company phone';
  @override
  String get server => 'Server';
  @override
  String get number => 'Extension';
  @override
  String get password => 'Password';
  @override
  String get signIn => 'Sign in';
  @override
  String get signInQr => 'Sign in with QR code';
  @override
  String get soon => 'Coming soon';
  @override
  String get fieldRequired => 'Fill in this field';

  @override
  String get tabDial => 'Keypad';
  @override
  String get tabHistory => 'Recents';
  @override
  String get tabContacts => 'Contacts';
  @override
  String get tabMore => 'More';

  @override
  String online(String number) => '$number · online';
  @override
  String get call => 'Call';
  @override
  String get calling => 'Calling…';

  @override
  String get history => 'Recents';
  @override
  String get filterAll => 'All';
  @override
  String get filterMissed => 'Missed';
  @override
  String get missed => 'missed';
  @override
  String minutes(int n) => '$n min';
  @override
  String get yesterday => 'yesterday';

  @override
  String get contacts => 'Contacts';
  @override
  String get searchHint => 'Name or number';
  @override
  String get employees => 'People';
  @override
  String get departments => 'Departments';
  @override
  String get statusFree => 'available';
  @override
  String get statusBusy => 'on a call';
  @override
  String get statusOffline => 'offline';
  @override
  String get group => 'group';
  @override
  String get nothingFound => 'No one found';

  @override
  String get incomingCall => 'Incoming call';
  @override
  String get unknownCaller => 'Unknown number';
  @override
  String get decline => 'Decline';
  @override
  String get accept => 'Accept';
  @override
  String get answerVerb => 'Answer';
  @override
  String get replyText => 'Reply with text';
  @override
  String get silent => 'Silence';
  @override
  String get secureHd => 'Secure call · HD';
  @override
  String get mic => 'Mute';
  @override
  String get keypad => 'Keypad';
  @override
  String get speaker => 'Speaker';
  @override
  String get hold => 'Hold';
  @override
  String get onHold => 'On hold';
  @override
  String get inCall => 'Call in progress';
  @override
  String get transfer => 'Transfer';
  @override
  String get addCall => 'Add';
  @override
  String get hangUp => 'End';

  @override
  String get settings => 'Settings';
  @override
  String get style => 'Style';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'Auto';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeAlwaysDark => 'This style is always dark';
  @override
  String get language => 'Language';
  @override
  String get langSystem => 'Auto';
  @override
  String get account => 'Account';
  @override
  String get signOut => 'Sign out';
  @override
  String get demo => 'Demo';
  @override
  String get demoIncoming => 'Show an incoming call';
  @override
  String get demoNote => "This is a demo without a PBX: calls aren't real, contacts and history are samples.";
  @override
  String get tryDemo => 'Try without a server';
  @override
  String get insecureServer =>
      "A ws:// address is not encrypted: others on the network can see who calls whom and can try to guess the password. Use wss:// if your server supports it.";
  @override
  String get signingIn => 'Connecting…';
  @override
  String get errAuth => 'Wrong extension or password';
  @override
  String get errNetwork => "The server isn't responding. Check the address and your connection";
  @override
  String get errOther => "Couldn't sign in";
  @override
  String linkConnecting(String number) => '$number · connecting…';
  @override
  String linkOffline(String number) => '$number · offline';
  @override
  String linkAuth(String number) => '$number · sign-in error';
  @override
  String seconds(int n) => '$n sec';
  @override
  String get historyEmpty => 'Your calls will appear here';
  @override
  String get contactsLater =>
      'Your colleagues will appear here once the app can load them from the server. For now, call from the keypad.';
  @override
  String get failBusy => 'Busy';
  @override
  String get failRejected => 'Call declined';
  @override
  String get failNoAnswer => 'No answer';
  @override
  String get failUnavailable => 'Unavailable';
  @override
  String get failMic => 'No microphone access. Allow it in phone settings';
  @override
  String get failOffline => 'No connection to the PBX';
  @override
  String get failOther => 'Call failed';

  @override
  String get swipeUpToAnswer => "Swipe up to answer";
  @override
  String get swipeDownToDecline => "Swipe down to decline";
  @override
  String get slideToAnswer => "Slide to answer";
  @override
  String get answerBy => "Answering calls";
  @override
  String get answerButtons => "Buttons";
  @override
  String get answerSwipe => "Swipe up or down";
  @override
  String get answerSlider => "Slide right";
  @override
  String get iconSet => "Icons";
  @override
  String get iconsOutlined => "Outlined";
  @override
  String get iconsFilled => "Filled";
  @override
  String get iconsRounded => "Rounded";

  @override
  String get background => "Background calls";
  @override
  String get backgroundOn => "Receive";
  @override
  String get backgroundOff => "Don't receive";
  @override
  String get backgroundNote =>
      "The app stays connected while minimized: a quiet notification stays in the shade, and the battery drains a little faster.";
  @override
  String get batteryAsk => "Remove battery restriction";
  @override
  String get batteryOk => "Battery restriction removed";
  @override
  String get autostartAsk => "Allow background activity";
  @override
  String get autostartNote =>
      "Xiaomi, Samsung, Huawei, Oppo and Vivo phones close apps on their own, and incoming calls stop arriving. In the list that opens, allow SADO to autostart or run without restrictions.";
  @override
  String get notifAsk => "Allow notifications";
  @override
  String get notifNote =>
      "Without notifications an incoming call will not ring or show up while the app is in the background.";
  @override
  String get fullScreenAsk => "Allow the call screen over the lock screen";
  @override
  String get fullScreenNote => "Without this, an incoming call on a locked phone shows only as a notification.";
  @override
  String get tabHome => "Home";
  @override
  String get tabKeypad => "Keypad";
  @override
  String get today => "Today";
  @override
  String get yesterdayTitle => "Yesterday";
  @override
  String get earlier => "Earlier";
  @override
  String get answerAuto => "Match the style";
  @override
  String get appIcon => "Home screen icon";

  @override
  String get answerPill => "Swipe sideways";
  @override
  String get newContact => "New contact";
  @override
  String get editContact => "Edit contact";
  @override
  String get contactName => "Name";
  @override
  String get save => "Save";
  @override
  String get delete => "Delete";
  @override
  String get cancel => "Cancel";
  @override
  String get noContacts => "No contacts yet";
  @override
  String get saveToContacts => "Save to contacts";
  @override
  String get transferTitle => "Transfer call";
  @override
  String get transferHint => "Number to transfer to";
  @override
  String get dnd => "Do not disturb";
  @override
  String get dndOn => "On";
  @override
  String get dndOff => "Off";
  @override
  String get dndNote => "Incoming calls don't ring and the caller hears a busy tone. Missed calls stay in Recents.";
  @override
  String get redialHint => "Tap call again to dial";
  @override
  String dndStatus(String number) => "$number · do not disturb";

  @override
  String styleName(SadoStyleId id) => switch (id) {
    SadoStyleId.emerald => 'Emerald',
    SadoStyleId.night => 'Night',
    SadoStyleId.air => 'Air',
    SadoStyleId.sunset => 'Sunset',
    SadoStyleId.cupertino => 'Cupertino',
    SadoStyleId.material => 'Material',
  };
}
