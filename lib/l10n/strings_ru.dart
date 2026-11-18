part of 'strings.dart';

/// Русский.
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
  String get qrHint =>
      "Наведите камеру телефона на QR-код от администратора — SADO откроется с заполненной формой входа.";
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
  String get soundOutput => 'Куда выводить звук';
  @override
  String get outputEarpiece => 'Телефон';
  @override
  String get outputBluetooth => 'Bluetooth';
  @override
  String get outputWired => 'Наушники';
  @override
  String get hold => 'Удержать';
  @override
  String get onHold => 'На удержании';
  @override
  String get secondCall => 'Второй звонок';
  @override
  String get swapCalls => 'Переключить';
  @override
  String get talkFirst => 'Сначала поговорить';
  @override
  String get connectCalls => 'Соединить';
  @override
  String get mergeCalls => 'Объединить';
  @override
  String get conference => 'Конференция';
  @override
  String get record => 'Записать';
  @override
  String get recordingOn => 'Идёт запись';
  @override
  String get failConnect => 'Не удалось соединить';
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
  String get setupFilled => 'Данные получены по ссылке. Проверьте адрес сервера и нажмите «Войти».';
  @override
  String get setupSignedIn => 'Вы уже вошли. Чтобы применить ссылку, сначала выйдите из учётной записи.';
  @override
  String get pasteSetup => 'Вставить ссылку настройки';
  @override
  String get noSetupInClipboard => 'В буфере обмена нет ссылки настройки';
  @override
  String get scanHint => 'Наведите камеру на QR-код от администратора';
  @override
  String get scanNotSetup => 'В этом QR-коде нет ссылки настройки SADO';
  @override
  String get scanNoCamera =>
      'Нет доступа к камере. Разрешите его в настройках телефона или наведите на код обычную камеру.';
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
  String get pushWake => 'Будить по звонку (пробный режим)';
  @override
  String get pushWakeNote =>
      'Приложение не держит связь постоянно: при звонке АТС будит телефон push-уведомлением через Google. Батарея расходуется меньше, звонок соединяется на несколько секунд дольше. Включайте, только если администратор АТС подтвердил, что она это умеет, — иначе звонки в фоне не дойдут.';
  @override
  String get systemCalls => 'Системные звонки (пробный режим)';
  @override
  String get systemCallsNote =>
      'Телефон узнаёт о звонках SADO: работают кнопка гарнитуры, машина и часы, а обычный сотовый звонок ставит разговор на удержание, а не обрывает звук. Режим новый — если со звуком что-то не так, выключите его.';
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
  String get missedCallTitle => "Пропущенный звонок";
  @override
  String missedCallsTitle(int count) => "Пропущенные звонки: $count";
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
  String get about => "О приложении";
  @override
  String versionLabel(String version) => "Версия $version";
  @override
  String get checkUpdates => "Проверить обновления";
  @override
  String get updateNote => "Проверка обращается к GitHub и выполняется только по нажатию.";
  @override
  String get upToDate => "У вас последняя версия";
  @override
  String updateAvailable(String version) => "Доступна версия $version";
  @override
  String get openDownload => "Открыть страницу загрузки";
  @override
  String get updateFailed => "Не удалось проверить. Попробуйте позже.";

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
  String get showPhoneContacts => "Показать контакты телефона";
  @override
  String get fromPhone => "Из телефона";
  @override
  String get myContacts => 'Свои контакты';
  @override
  String get phoneContactsTitle => "Контакты телефона";
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
  String get ringtone => "Мелодия звонка";
  @override
  String get ringtoneDefault => "Как в телефоне";
  @override
  String get ringVibration => "Вибрация при звонке";
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
