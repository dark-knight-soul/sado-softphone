import 'package:material_ui/material_ui.dart';

/// Пять стилей оформления. Имя (`name`) сохраняется в настройках — не переименовывать.
enum SadoStyleId { emerald, night, air, sunset, cupertino, material }

/// Вкладки нижнего меню. Порядок у стилей разный (см. [StyleSpec.tabs]).
enum AppTab { dial, history, contacts, more }

/// Как разложены кнопки на экране разговора.
enum CallLayout {
  /// Кнопки сеткой, «Завершить» отдельно внизу.
  standard,

  /// В духе iOS: имя слева вверху, кнопки сеткой внизу, «Завершить» внутри сетки.
  cupertino,

  /// В духе Material Design: имя сверху, крупный аватар посередине, кнопки на нижнем «листе».
  material,
}

/// Форма клавиш набора номера.
enum KeyShape {
  /// Круглые с заливкой.
  circle,

  /// Скруглённые прямоугольники.
  rounded,

  /// Без фона, только крупная цифра.
  bare,
}

/// Цвета экрана звонка. У «Заката» и «Купертино» он окрашен иначе, чем остальные экраны.
@immutable
class CallPalette {
  const CallPalette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.go,
    required this.onGo,
    required this.hangup,
    required this.onHangup,
    this.sheet,
    this.gradient,
    this.incomingGradient,
  });

  final Color bg;
  final Color surface;
  final Color text;
  final Color muted;

  /// Цвет включённой кнопки (например, «Динамик»).
  final Color accent;
  final Color onAccent;

  /// Кнопка «Принять».
  final Color go;
  final Color onGo;

  /// Кнопка «Завершить» / «Отклонить».
  final Color hangup;
  final Color onHangup;

  /// Фон нижнего «листа» с кнопками (для раскладки «Материала»); null — как [surface].
  final Color? sheet;

  /// Фон экрана разговора переходом цвета сверху вниз; null — сплошной [bg].
  final List<Color>? gradient;

  /// То же для экрана входящего звонка.
  final List<Color>? incomingGradient;
}

/// Набор цветов одного стиля для светлой или тёмной темы.
@immutable
class SadoPalette {
  const SadoPalette({
    required this.brightness,
    required this.bg,
    required this.card,
    required this.surface,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.go,
    required this.onGo,
    required this.danger,
    required this.onDanger,
    required this.success,
    required this.divider,
    this.callOverride,
  });

  final Brightness brightness;

  /// Фон экрана.
  final Color bg;

  /// Фон карточки списка (в стилях без карточек равен [bg]).
  final Color card;

  /// Фон клавиш, полей ввода, аватаров.
  final Color surface;
  final Color text;

  /// Второстепенный текст.
  final Color muted;
  final Color accent;
  final Color onAccent;

  /// Кнопка «Позвонить».
  final Color go;
  final Color onGo;
  final Color danger;
  final Color onDanger;
  final Color success;
  final Color divider;

  /// Отдельные цвета экрана звонка; если не заданы — берутся обычные.
  final CallPalette? callOverride;

  CallPalette get call =>
      callOverride ??
      CallPalette(
        bg: bg,
        surface: surface,
        text: text,
        muted: muted,
        accent: accent,
        onAccent: onAccent,
        go: go,
        onGo: onGo,
        hangup: danger,
        onHangup: onDanger,
        sheet: card,
      );
}

/// Описание стиля: цвета для светлой и тёмной темы плюс формы.
@immutable
class StyleSpec {
  const StyleSpec({
    required this.id,
    required this.light,
    required this.dark,
    required this.keyShape,
    this.keyRadius = 14,
    this.controlRadius = 12,
    this.wideCallButton = false,
    this.callButtonRadius = 14,
    this.groupedLists = false,
    this.largeTitles = false,
    this.squareAvatars = false,
    this.keyLetters = false,
    this.tabs = const [AppTab.dial, AppTab.history, AppTab.contacts, AppTab.more],
    this.callLayout = CallLayout.standard,
    this.actionRadius,
    this.navPill = false,
    this.keypadSheet = false,
    this.keyAspect,
    this.keyGap = 0.3,
    this.numberInSheet = false,
    this.unifiedHome = false,
  });

  final SadoStyleId id;
  final SadoPalette light;
  final SadoPalette dark;
  final KeyShape keyShape;
  final double keyRadius;

  /// Скругление полей ввода и обычных кнопок.
  final double controlRadius;

  /// Широкая кнопка вызова с подписью вместо круглой.
  final bool wideCallButton;
  final double callButtonRadius;

  /// Списки в скруглённых карточках на сером фоне.
  final bool groupedLists;

  /// Крупные заголовки экранов.
  final bool largeTitles;

  /// Аватары-«подушечки» вместо кругов.
  final bool squareAvatars;

  /// Буквы под цифрами на клавишах (ABC, DEF…), как на телефонах.
  final bool keyLetters;

  /// Порядок вкладок нижнего меню.
  final List<AppTab> tabs;
  final CallLayout callLayout;

  /// Скругление кнопок на экране разговора; null — круглые.
  final double? actionRadius;

  /// Активная вкладка нижнего меню выделяется «пилюлей» под значком.
  final bool navPill;

  /// Клавиши набора лежат на отдельном «листе» со скруглёнными верхними углами.
  final bool keypadSheet;

  /// Ширина клавиши относительно её высоты; null — по форме клавиши.
  final double? keyAspect;

  /// Просвет между клавишами в долях размера клавиши.
  final double keyGap;

  /// Набранный номер и кнопка «стереть» стоят на «листе» над клавишами, а кнопка вызова — по центру под ними.
  final bool numberInSheet;

  /// Единый главный экран (в духе Material Design): внизу две вкладки («Главная» и «Клавиатура»), сверху поиск
  /// и фильтры, история разбита по дням; контакты и настройки открываются из верхней строки.
  final bool unifiedHome;

  SadoStyle resolve(Brightness brightness) =>
      SadoStyle(spec: this, palette: brightness == Brightness.dark ? dark : light);
}

/// Стиль, готовый к использованию в виджетах: `SadoStyle.of(context)`.
@immutable
class SadoStyle extends ThemeExtension<SadoStyle> {
  const SadoStyle({required this.spec, required this.palette});

  final StyleSpec spec;
  final SadoPalette palette;

  SadoStyleId get id => spec.id;
  KeyShape get keyShape => spec.keyShape;
  double get keyRadius => spec.keyRadius;
  double get controlRadius => spec.controlRadius;
  bool get wideCallButton => spec.wideCallButton;
  double get callButtonRadius => spec.callButtonRadius;
  bool get groupedLists => spec.groupedLists;
  bool get largeTitles => spec.largeTitles;
  bool get squareAvatars => spec.squareAvatars;
  bool get keyLetters => spec.keyLetters;
  List<AppTab> get tabs => spec.tabs;
  CallLayout get callLayout => spec.callLayout;
  double? get actionRadius => spec.actionRadius;
  bool get navPill => spec.navPill;
  bool get keypadSheet => spec.keypadSheet;
  double? get keyAspect => spec.keyAspect;
  double get keyGap => spec.keyGap;
  bool get numberInSheet => spec.numberInSheet;
  bool get unifiedHome => spec.unifiedHome;

  static SadoStyle of(BuildContext context) => Theme.of(context).extension<SadoStyle>()!;

  @override
  SadoStyle copyWith({StyleSpec? spec, SadoPalette? palette}) =>
      SadoStyle(spec: spec ?? this.spec, palette: palette ?? this.palette);

  // Стили не смешиваем: при смене просто переключаемся на середине анимации.
  @override
  SadoStyle lerp(covariant SadoStyle? other, double t) => (other == null || t < 0.5) ? this : other;
}
