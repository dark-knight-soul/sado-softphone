import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';

/// Аватар с инициалами. Для номера без имени показывает значок человека.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.name, this.icon, this.size = 44, this.background, this.foreground});

  final String? name;
  final IconData? icon;
  final double size;
  final Color? background;
  final Color? foreground;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    final letters = words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return RegExp(r'^[\d+*#]').hasMatch(letters) ? '' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final p = style.palette;
    final fg = foreground ?? p.accent;
    final text = icon == null && name != null ? initials(name!) : '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? p.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(style.squareAvatars ? size * 0.3 : size / 2),
      ),
      child: text.isEmpty
          ? Icon(icon ?? SadoIcons.of(context).person, size: size * 0.5, color: fg)
          : Text(
              text,
              style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: fg, height: 1),
            ),
    );
  }
}

/// Одна клавиша набора номера. Вид зависит от стиля.
class DialKey extends StatelessWidget {
  const DialKey({
    super.key,
    required this.label,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.letters,
    this.letters2,
    this.background,
    this.foreground,
  });

  /// Буквы под цифрами, как на телефонах. У «1», «*» и «#» букв нет.
  static const lettersOf = <String, String>{
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  /// Русские буквы — второй строкой, когда приложение на русском.
  static const cyrillicOf = <String, String>{
    '2': 'АБВГ',
    '3': 'ДЕЁЖЗ',
    '4': 'ИЙКЛ',
    '5': 'МНОП',
    '6': 'РСТУ',
    '7': 'ФХЦЧ',
    '8': 'ШЩЪЫ',
    '9': 'ЬЭЮЯ',
  };

  final String label;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Подпись под цифрой. null — стиль без букв; пустая строка — буквы есть, но не у этой клавиши
  /// (место под них всё равно оставляем, чтобы цифры стояли на одной линии).
  final String? letters;

  /// Вторая строка букв (русские); null — без неё.
  final String? letters2;

  /// Свои цвета — для клавиш на экране звонка, у которого отдельная палитра.
  final Color? background;
  final Color? foreground;

  /// Высота клавиши при данном размере: «плитки» ниже круга.
  static double heightFor(SadoStyle style, double size) => style.keyShape == KeyShape.rounded ? size * 0.86 : size;

  /// Ширина клавиши: по пропорции из стиля, а если её нет — по форме.
  static double widthFor(SadoStyle style, double size) {
    final aspect = style.keyAspect;
    if (aspect != null) return heightFor(style, size) * aspect;
    return style.keyShape == KeyShape.rounded ? size * 1.12 : size;
  }

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final p = style.palette;
    final bare = style.keyShape == KeyShape.bare;
    final rounded = style.keyShape == KeyShape.rounded;
    final height = heightFor(style, size);
    final ShapeBorder shape = rounded
        // Радиус не больше половины высоты: при большом значении получается овал-«стадион».
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(style.keyRadius.clamp(0.0, height / 2)))
        : const CircleBorder();
    final color = foreground ?? p.text;
    final withLetters = letters != null;
    final twoLines = withLetters && letters2 != null;
    // Клавиша — фиксированного размера, поэтому её подписи не увеличиваем вместе с системным шрифтом:
    // при «очень крупном» тексте они вылезали бы за края.
    final digit = Text(
      label,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: size * (bare ? 0.46 : 0.4) * (twoLines ? 0.9 : (withLetters ? 0.86 : 1)),
        fontWeight: bare || twoLines ? FontWeight.w300 : FontWeight.w400,
        color: color,
        height: 1,
      ),
    );
    Widget small(String text) => SizedBox(
      height: size * (twoLines ? 0.15 : 0.2),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: (size * (twoLines ? 0.125 : 0.14)).clamp(8.0, 11.5),
          // В стиле «Материал» буквы тонкие, у остальных стилей — плотные.
          fontWeight: twoLines ? FontWeight.w400 : FontWeight.w600,
          letterSpacing: twoLines ? 0.6 : 1.4,
          color: color.withValues(alpha: 0.6),
          height: twoLines ? 1.25 : 1.5,
        ),
      ),
    );
    return SizedBox(
      width: widthFor(style, size),
      height: height,
      child: Material(
        color: bare ? Colors.transparent : (background ?? p.surface),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress,
          child: Center(
            child: withLetters
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [digit, small(letters!), if (twoLines) small(letters2!)],
                  )
                : digit,
          ),
        ),
      ),
    );
  }
}

/// Нажимаемая область без «волны»: пока палец на ней, содержимое приглушается и чуть сжимается.
/// Для значков, у которых нет своей подложки, — стандартная волна там расплывается пятном вокруг.
class PressFade extends StatefulWidget {
  const PressFade({super.key, required this.child, required this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressFade> createState() => _PressFadeState();
}

class _PressFadeState extends State<PressFade> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.86 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: _down ? 0.5 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Главная кнопка звонка: «Позвонить», «Принять», «Завершить».
/// В одних стилях круглая (подпись — под ней, если [showLabel]), в других широкая с подписью внутри.
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
    this.showLabel = false,
    this.labelColor,
    this.size = 68,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback? onTap;
  final bool showLabel;
  final Color? labelColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    if (style.wideCallButton) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: SizedBox(
          height: 58,
          width: double.infinity,
          child: Material(
            color: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style.callButtonRadius)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: onColor, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onColor,
                        fontSize: style.numberInSheet ? 17 : 16,
                        // В стиле «Материал» подпись на кнопке вызова не жирная.
                        fontWeight: style.numberInSheet ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, color: onColor, size: size * 0.44, semanticLabel: label),
        ),
      ),
    );
    if (!showLabel) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: labelColor ?? style.palette.muted)),
      ],
    );
  }
}

/// Заголовок экрана: в «Купертино» крупный, в остальных стилях обычный.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        text,
        style: style.largeTitles
            ? TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: style.palette.text, letterSpacing: -0.5)
            : TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: style.palette.text),
      ),
    );
  }
}

/// Подзаголовок раздела в списке.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(style.groupedLists ? 32 : 20, 18, 20, 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: style.palette.muted)),
    );
  }
}

/// Группа строк списка: в «Купертино» — скруглённая карточка, в остальных — просто строки.
/// Между строками ставит тонкие разделители.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children, this.dividerIndent = 76});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final rows = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Divider(indent: dividerIndent, height: 0.5),
        children[i],
      ],
    ];
    final column = Column(mainAxisSize: MainAxisSize.min, children: rows);
    if (!style.groupedLists) return column;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: style.palette.card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: column,
      ),
    );
  }
}

/// Переключатель из нескольких вариантов («Все / Пропущенные», тема, язык).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.selected, required this.onChanged});

  /// Значение → подпись, в порядке показа.
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final p = style.palette;
    final radius = style.controlRadius;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key != selected ? Colors.transparent : (style.groupedLists ? p.card : p.accent),
                    borderRadius: BorderRadius.circular(radius - 3),
                  ),
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: entry.key == selected ? FontWeight.w600 : FontWeight.w400,
                      color: entry.key != selected ? p.text : (style.groupedLists ? p.text : p.onAccent),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Цвет значков в строке состояния телефона под цвет фона экрана.
SystemUiOverlayStyle overlayFor(Color background) => ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? SystemUiOverlayStyle.light
    : SystemUiOverlayStyle.dark;
