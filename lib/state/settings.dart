import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';

/// Хранилище настроек на телефоне. Подменяется настоящим в `main()`.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider нужно подменить в ProviderScope'),
);

/// Как отвечать на входящий звонок. Имя (`name`) сохраняется в настройках — не переименовывать.
enum AnswerMode {
  /// Две кнопки: «Отклонить» и «Принять».
  buttons,

  /// Ручку тянут вверх, чтобы ответить, вниз — чтобы отклонить.
  swipe,

  /// Кружок ведут вправо по дорожке; «Отклонить» — отдельной кнопкой.
  slider,

  /// Ручка в середине «пилюли»: вправо — ответить, влево — отклонить.
  pill,

  /// Как принято в выбранном стиле: «Купертино» — ползунок, «Материал» — «пилюля», остальные — кнопки.
  auto,
}

@immutable
class Settings {
  const Settings({
    required this.styleId,
    required this.themeMode,
    required this.lang,
    required this.answerMode,
    required this.iconSet,
    required this.backgroundLink,
    required this.dnd,
  });

  final SadoStyleId styleId;
  final ThemeMode themeMode;

  /// Код языка (`ru`, `uz`, `en`) или null — как в системе.
  final String? lang;
  final AnswerMode answerMode;
  final IconSetId iconSet;

  /// Оставаться на связи с АТС, когда приложение свёрнуто (постоянная фоновая служба).
  final bool backgroundLink;

  /// «Не беспокоить»: входящие не звонят, звонящий слышит «занято».
  final bool dnd;

  /// [lang] передаётся отдельной функцией, потому что его нужно уметь сбрасывать в null.
  Settings copyWith({
    SadoStyleId? styleId,
    ThemeMode? themeMode,
    String? Function()? lang,
    AnswerMode? answerMode,
    IconSetId? iconSet,
    bool? backgroundLink,
    bool? dnd,
  }) => Settings(
    styleId: styleId ?? this.styleId,
    themeMode: themeMode ?? this.themeMode,
    lang: lang == null ? this.lang : lang(),
    answerMode: answerMode ?? this.answerMode,
    iconSet: iconSet ?? this.iconSet,
    backgroundLink: backgroundLink ?? this.backgroundLink,
    dnd: dnd ?? this.dnd,
  );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.styleId == styleId &&
      other.themeMode == themeMode &&
      other.lang == lang &&
      other.answerMode == answerMode &&
      other.iconSet == iconSet &&
      other.backgroundLink == backgroundLink &&
      other.dnd == dnd;

  @override
  int get hashCode => Object.hash(styleId, themeMode, lang, answerMode, iconSet, backgroundLink, dnd);
}

class SettingsController extends Notifier<Settings> {
  static const _kStyle = 'style';
  static const _kTheme = 'themeMode';
  static const _kLang = 'lang';
  static const _kAnswer = 'answerMode';
  static const _kIcons = 'iconSet';
  static const _kBackground = 'backgroundLink';
  static const _kDnd = 'dnd';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  Settings build() {
    final p = ref.watch(prefsProvider);
    return Settings(
      styleId: SadoStyleId.values.asNameMap()[p.getString(_kStyle)] ?? SadoStyleId.emerald,
      themeMode: ThemeMode.values.asNameMap()[p.getString(_kTheme)] ?? ThemeMode.system,
      lang: p.getString(_kLang),
      answerMode: AnswerMode.values.asNameMap()[p.getString(_kAnswer)] ?? AnswerMode.auto,
      iconSet: IconSetId.values.asNameMap()[p.getString(_kIcons)] ?? IconSetId.outlined,
      backgroundLink: p.getBool(_kBackground) ?? true,
      dnd: p.getBool(_kDnd) ?? false,
    );
  }

  void setStyle(SadoStyleId id) {
    state = state.copyWith(styleId: id);
    _prefs.setString(_kStyle, id.name);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString(_kTheme, mode.name);
  }

  void setLang(String? lang) {
    state = state.copyWith(lang: () => lang);
    if (lang == null) {
      _prefs.remove(_kLang);
    } else {
      _prefs.setString(_kLang, lang);
    }
  }

  void setAnswerMode(AnswerMode mode) {
    state = state.copyWith(answerMode: mode);
    _prefs.setString(_kAnswer, mode.name);
  }

  void setBackgroundLink(bool on) {
    state = state.copyWith(backgroundLink: on);
    _prefs.setBool(_kBackground, on);
  }

  void setDnd(bool on) {
    state = state.copyWith(dnd: on);
    _prefs.setBool(_kDnd, on);
  }

  void setIconSet(IconSetId id) {
    state = state.copyWith(iconSet: id);
    _prefs.setString(_kIcons, id.name);
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);
