import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/demo_data.dart';
import '../theme/sado_style.dart';

part 'strings_de.dart';
part 'strings_en.dart';
part 'strings_es.dart';
part 'strings_fr.dart';
part 'strings_it.dart';
part 'strings_pt.dart';
part 'strings_ru.dart';
part 'strings_tr.dart';
part 'strings_uz.dart';

/// Все надписи приложения. Каждый язык — в своём файле `strings_<код>.dart`. Получить: `S.of(context)`.
///
/// Сделано обычными классами, без генератора кода: если в одном из языков забыть
/// надпись, приложение просто не соберётся.
abstract class S {
  const S();

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// Как назвать собеседника: имя, а если его нет — номер; если скрыт и номер — «Неизвестный номер».
  String caller(String? name, String number) => name ?? (number.isEmpty ? unknownCaller : formatNumber(number));

  /// Все языки приложения: код → надписи.
  static const _all = <String, S>{
    'en': _En(),
    'ru': _Ru(),
    'uz': _Uz(),
    'de': _De(),
    'es': _Es(),
    'fr': _Fr(),
    'it': _It(),
    'pt': _Pt(),
    'tr': _Tr(),
  };

  /// Названия языков на них самих, в порядке показа в настройках.
  static const languageNames = <String, String>{
    'uz': 'Oʻzbek',
    'ru': 'Русский',
    'en': 'English',
    'de': 'Deutsch',
    'es': 'Español',
    'fr': 'Français',
    'it': 'Italiano',
    'pt': 'Português',
    'tr': 'Türkçe',
  };

  /// Языки телефона, для которых перевода нет, но русский обычно понятнее английского.
  static const _preferRussian = {'kk', 'ky', 'tg', 'tk', 'be'};

  /// Какой язык приложения показать при таком языке телефона: свой, если перевод есть,
  /// иначе английский (а для языков из [_preferRussian] — русский).
  static String resolveCode(String code) {
    if (_all.containsKey(code)) return code;
    return _preferRussian.contains(code) ? 'ru' : 'en';
  }

  /// Надписи по коду языка — там, где нет экрана (например, для уведомления о звонке).
  static S byCode(String code) => _all[resolveCode(code)]!;

  static final supportedLocales = [for (final code in _all.keys) Locale(code)];

  /// Выбор языка по языку телефона — для `MaterialApp.localeResolutionCallback`.
  static Locale resolveLocale(Locale? device, Iterable<Locale> supported) =>
      Locale(resolveCode(device?.languageCode ?? 'en'));

  // Вход
  String get tagline;
  String get server;
  String get number;
  String get password;
  String get signIn;
  String get signInQr;
  String get qrHint;
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
  String get soundOutput;
  String get outputEarpiece;
  String get outputBluetooth;
  String get outputWired;
  String get hold;
  String get onHold;

  /// Подпись карточки второго звонка, который звонит во время разговора.
  String get secondCall;

  /// Кнопка «поменять местами» текущий разговор и разговор на удержании.
  String get swapCalls;

  /// Перевод с консультацией: кнопка в окне перевода «сначала поговорить с тем, кому переводим».
  String get talkFirst;

  /// Кнопка «соединить» текущего собеседника с удержанным (и уйти из разговора).
  String get connectCalls;

  /// Кнопка «объединить» оба разговора в конференцию и подпись самого звонка-конференции.
  String get mergeCalls;
  String get conference;

  /// Запись разговора: кнопка «записать» и пометка «идёт запись».
  String get record;
  String get recordingOn;

  /// АТС не соединила двух собеседников.
  String get failConnect;
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
  // Ссылка настройки (QR-код от администратора)
  String get setupFilled;
  String get setupSignedIn;
  String get pasteSetup;
  String get noSetupInClipboard;

  /// Сканер QR-кода: подсказка на экране камеры.
  String get scanHint;

  /// В прочитанном QR-коде нет ссылки настройки.
  String get scanNotSetup;

  /// Камеры нет или к ней не дали доступ.
  String get scanNoCamera;
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

  /// Режим «будить по звонку» (push): заголовок и пояснение.
  String get pushWake;
  String get pushWakeNote;

  /// Пробный режим «Системные звонки»: телефон знает о звонках приложения (гарнитура, машина, сотовый звонок).
  String get systemCalls;
  String get systemCallsNote;
  String get batteryAsk;
  String get batteryOk;
  String get autostartAsk;
  String get autostartNote;
  String get notifAsk;
  String get notifNote;
  String get missedCallTitle;
  String missedCallsTitle(int count);
  String get fullScreenAsk;
  String get fullScreenNote;
  String get tabHome;
  String get tabKeypad;
  String get today;
  String get yesterdayTitle;
  String get earlier;
  String get answerAuto;
  String get appIcon;

  // О приложении и проверка обновлений
  String get about;
  String versionLabel(String version);
  String get checkUpdates;
  String get updateNote;
  String get upToDate;
  String updateAvailable(String version);
  String get openDownload;
  String get updateFailed;

  // Контакты, перевод, «Не беспокоить»
  String get answerPill;
  String get newContact;
  String get editContact;
  String get contactName;
  String get save;
  String get delete;
  String get cancel;
  String get noContacts;
  String get showPhoneContacts;
  String get fromPhone;

  /// Заголовок своих контактов, когда ниже идёт справочник сотрудников с АТС.
  String get myContacts;
  String get phoneContactsTitle;
  String get saveToContacts;
  String get transferTitle;
  String get transferHint;
  String get dnd;
  String get dndOn;
  String get dndOff;
  String get dndNote;
  String get ringtone;
  String get ringtoneDefault;
  String get ringVibration;
  String get redialHint;
  String dndStatus(String number);

  String styleName(SadoStyleId id);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => S._all.containsKey(locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture<S>(S.byCode(locale.languageCode));

  @override
  bool shouldReload(_SDelegate old) => false;
}
