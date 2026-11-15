import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'sado_icons.dart';
import 'sado_style.dart';

const _white = Color(0xFFFFFFFF);

/// 1. «Изумруд» — самый первый макет: спокойный, зелёный акцент, круглые клавиши.
const _emerald = StyleSpec(
  id: SadoStyleId.emerald,
  keyShape: KeyShape.circle,
  light: SadoPalette(
    brightness: Brightness.light,
    bg: _white,
    card: _white,
    surface: Color(0xFFF0F3F2),
    text: Color(0xFF17201C),
    muted: Color(0xFF6B7772),
    accent: Color(0xFF0F6E56),
    onAccent: _white,
    go: Color(0xFF0F6E56),
    onGo: _white,
    danger: Color(0xFFA32D2D),
    onDanger: _white,
    success: Color(0xFF1D9E75),
    divider: Color(0xFFE3E7E5),
  ),
  dark: SadoPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF101413),
    card: Color(0xFF101413),
    surface: Color(0xFF1C2321),
    text: Color(0xFFEEF3F1),
    muted: Color(0xFF93A09B),
    accent: Color(0xFF2FBF8F),
    onAccent: Color(0xFF04221A),
    go: Color(0xFF2FBF8F),
    onGo: Color(0xFF04221A),
    danger: Color(0xFFE24B4A),
    onDanger: _white,
    success: Color(0xFF2FBF8F),
    divider: Color(0xFF26302D),
  ),
);

/// 2. «Ночь» — всегда тёмный, лаймовый акцент, клавиши-плитки.
const _nightPalette = SadoPalette(
  brightness: Brightness.dark,
  bg: Color(0xFF0F1115),
  card: Color(0xFF0F1115),
  surface: Color(0xFF1D2129),
  text: Color(0xFFF2F3F5),
  muted: Color(0xFF9AA0AA),
  accent: Color(0xFFB8F04A),
  onAccent: Color(0xFF1A2406),
  go: Color(0xFFB8F04A),
  onGo: Color(0xFF1A2406),
  danger: Color(0xFFE24B4A),
  onDanger: _white,
  success: Color(0xFFB8F04A),
  divider: Color(0xFF272C36),
);

const _night = StyleSpec(
  id: SadoStyleId.night,
  keyShape: KeyShape.rounded,
  keyRadius: 16,
  controlRadius: 14,
  wideCallButton: true,
  callButtonRadius: 16,
  squareAvatars: true,
  light: _nightPalette,
  dark: _nightPalette,
);

/// 3. «Воздух» — светлый и лёгкий, фиолетовый акцент, цифры без фона.
const _air = StyleSpec(
  id: SadoStyleId.air,
  keyShape: KeyShape.bare,
  controlRadius: 16,
  light: SadoPalette(
    brightness: Brightness.light,
    bg: _white,
    card: _white,
    surface: Color(0xFFF1EFFB),
    text: Color(0xFF1B1830),
    muted: Color(0xFF77738F),
    accent: Color(0xFF534AB7),
    onAccent: _white,
    go: Color(0xFF534AB7),
    onGo: _white,
    danger: Color(0xFFE24B4A),
    onDanger: _white,
    success: Color(0xFF1D9E75),
    divider: Color(0xFFE7E4F5),
  ),
  dark: SadoPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF12111A),
    card: Color(0xFF12111A),
    surface: Color(0xFF211F30),
    text: Color(0xFFEDEBFA),
    muted: Color(0xFFA09CB8),
    accent: Color(0xFF9C94F0),
    onAccent: Color(0xFF15123A),
    go: Color(0xFF9C94F0),
    onGo: Color(0xFF15123A),
    danger: Color(0xFFE24B4A),
    onDanger: _white,
    success: Color(0xFF5DCAA5),
    divider: Color(0xFF2B2940),
  ),
);

/// Экран звонка «Заката» целиком коралловый — и в светлой, и в тёмной теме.
const _sunsetCall = CallPalette(
  bg: Color(0xFFD85A30),
  surface: Color(0xFF993C1D),
  text: Color(0xFFFAECE7),
  muted: Color(0xFFF5C4B3),
  accent: Color(0xFFFAECE7),
  onAccent: Color(0xFF712B13),
  go: Color(0xFFFAECE7),
  onGo: Color(0xFF712B13),
  hangup: Color(0xFFFAECE7),
  onHangup: Color(0xFF993C1D),
);

/// 4. «Закат» — тёплый, коралловый, кнопки-пилюли.
const _sunset = StyleSpec(
  id: SadoStyleId.sunset,
  keyShape: KeyShape.rounded,
  keyRadius: 18,
  controlRadius: 18,
  wideCallButton: true,
  callButtonRadius: 28,
  squareAvatars: true,
  light: SadoPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFAECE7),
    card: Color(0xFFFAECE7),
    surface: Color(0xFFF5C4B3),
    text: Color(0xFF4A1B0C),
    muted: Color(0xFF993C1D),
    accent: Color(0xFFD85A30),
    onAccent: _white,
    go: Color(0xFFD85A30),
    onGo: _white,
    danger: Color(0xFFA32D2D),
    onDanger: _white,
    success: Color(0xFF3B6D11),
    divider: Color(0xFFF0CFC2),
    callOverride: _sunsetCall,
  ),
  dark: SadoPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF1F1410),
    card: Color(0xFF1F1410),
    surface: Color(0xFF3A241B),
    text: Color(0xFFFAECE7),
    muted: Color(0xFFD9A48F),
    accent: Color(0xFFF0997B),
    onAccent: Color(0xFF4A1B0C),
    go: Color(0xFFF0997B),
    onGo: Color(0xFF4A1B0C),
    danger: Color(0xFFE24B4A),
    onDanger: _white,
    success: Color(0xFF97C459),
    divider: Color(0xFF45291F),
    callOverride: _sunsetCall,
  ),
);

/// Экран звонка «Купертино» всегда тёмный, с мягким переходом цвета, в духе iOS;
/// кнопки — полупрозрачные «стеклянные» круги.
const _cupertinoCall = CallPalette(
  bg: Color(0xFF2B3A44),
  surface: Color(0x33FFFFFF),
  text: _white,
  muted: Color(0xC7FFFFFF),
  gradient: [Color(0xFF5C4A3B), Color(0xFF434841), Color(0xFF22384E)],
  incomingGradient: [Color(0xFF3B7578), Color(0xFF145468), Color(0xFF0C3A57)],
  accent: _white,
  onAccent: Color(0xFF1C1C1E),
  go: Color(0xFF34C759),
  onGo: _white,
  hangup: Color(0xFFFF3B30),
  onHangup: _white,
);

/// 5. «Купертино» — в духе iOS: крупные заголовки, списки карточками, круглые кнопки.
const _cupertino = StyleSpec(
  id: SadoStyleId.cupertino,
  keyShape: KeyShape.circle,
  controlRadius: 12,
  groupedLists: true,
  largeTitles: true,
  keyLetters: true,
  tabs: [AppTab.history, AppTab.contacts, AppTab.dial, AppTab.more],
  callLayout: CallLayout.cupertino,
  light: SadoPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F7),
    card: _white,
    surface: Color(0xFFE5E5EA),
    text: Color(0xFF000000),
    muted: Color(0xFF8E8E93),
    accent: Color(0xFF007AFF),
    onAccent: _white,
    go: Color(0xFF34C759),
    onGo: _white,
    danger: Color(0xFFFF3B30),
    onDanger: _white,
    success: Color(0xFF34C759),
    divider: Color(0xFFD1D1D6),
    callOverride: _cupertinoCall,
  ),
  dark: SadoPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    text: _white,
    muted: Color(0xFF8E8E93),
    accent: Color(0xFF0A84FF),
    onAccent: _white,
    go: Color(0xFF30D158),
    onGo: _white,
    danger: Color(0xFFFF453A),
    onDanger: _white,
    success: Color(0xFF30D158),
    divider: Color(0xFF38383A),
    callOverride: _cupertinoCall,
  ),
);

/// Экран звонка «Материала» в тёмной теме: кнопка «Завершить» кораллово-красная
/// (обычный «цвет ошибки» тёмной темы слишком бледный), а нижний «лист» светлее фона.
const _materialDarkCall = CallPalette(
  bg: Color(0xFF1A1B21),
  surface: Color(0xFF0F1014),
  text: Color(0xFFE4E5F0),
  muted: Color(0xFFA9ABBD),
  accent: Color(0xFFC3C7F0),
  onAccent: Color(0xFF2A2F52),
  go: Color(0xFF6DB87A),
  onGo: Color(0xFF0D2B14),
  hangup: Color(0xFFEC6A5E),
  onHangup: Color(0xFF3A0B07),
  sheet: Color(0xFF282930),
);

/// 6. «Материал» — в духе Material Design: клавиши-овалы темнее «листа», на котором лежат,
/// номер и «стереть» в верхней строке листа, зелёная кнопка-пилюля по центру, сиреневый акцент.
const _material = StyleSpec(
  id: SadoStyleId.material,
  keyShape: KeyShape.rounded,
  keyRadius: 100,
  keyAspect: 1.85,
  keyGap: 0.105,
  keyLetters: true,
  controlRadius: 24,
  wideCallButton: true,
  callButtonRadius: 32,
  groupedLists: true,
  tabs: [AppTab.history, AppTab.dial],
  callLayout: CallLayout.material,
  unifiedHome: true,
  actionRadius: 26,
  navPill: true,
  keypadSheet: true,
  numberInSheet: true,
  light: SadoPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF7F7FE),
    card: Color(0xFFECEDF8),
    surface: _white,
    text: Color(0xFF1A1B21),
    muted: Color(0xFF5D5E6C),
    accent: Color(0xFF4C5A9E),
    onAccent: _white,
    go: Color(0xFF2F8043),
    onGo: _white,
    danger: Color(0xFFB3261E),
    onDanger: _white,
    success: Color(0xFF2F8043),
    divider: Color(0xFFDCDDE8),
  ),
  dark: SadoPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF1A1B21),
    card: Color(0xFF1F2027),
    surface: Color(0xFF0F1014),
    text: Color(0xFFE4E5F0),
    muted: Color(0xFFA9ABBD),
    accent: Color(0xFFC3C7F0),
    onAccent: Color(0xFF2A2F52),
    go: Color(0xFF6DB87A),
    onGo: Color(0xFF0D2B14),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
    success: Color(0xFF6DB87A),
    divider: Color(0xFF2C2D36),
    callOverride: _materialDarkCall,
  ),
);

/// Все стили в порядке показа в настройках.
const sadoStyles = <StyleSpec>[_emerald, _night, _air, _sunset, _cupertino, _material];

StyleSpec styleSpecOf(SadoStyleId id) => sadoStyles.firstWhere((s) => s.id == id);

/// Собирает тему приложения из стиля.
ThemeData buildTheme(StyleSpec spec, Brightness brightness, [SadoIcons icons = SadoIcons.outlined]) {
  final style = spec.resolve(brightness);
  final p = style.palette;
  final textFamily = Typography.material2021(platform: defaultTargetPlatform).black.bodyMedium?.fontFamily;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: p.brightness).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.bg,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    error: p.danger,
    onError: p.onDanger,
    outlineVariant: p.divider,
  );
  // Рамка «как у подчёркнутого поля», но без линии: так подпись остаётся внутри закрашенного поля,
  // а не съезжает на его край.
  final fieldBorder = UnderlineInputBorder(
    borderRadius: BorderRadius.circular(style.controlRadius),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [style, icons],
    dividerTheme: DividerThemeData(color: p.divider, thickness: 0.5, space: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: style.groupedLists ? p.card : p.surface,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder,
      errorBorder: fieldBorder,
      focusedErrorBorder: fieldBorder,
      floatingLabelStyle: TextStyle(color: p.accent),
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size.fromHeight(52),
        // Шрифт берём тот же, что у остального текста: стиль кнопки не наследует его сам, и без этого
        // подпись рисовалась бы шрифтом по умолчанию.
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: textFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style.controlRadius)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.accent)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style.controlRadius)),
    ),
  );
}
