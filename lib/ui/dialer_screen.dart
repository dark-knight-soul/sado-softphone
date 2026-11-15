import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../sip/call_engine.dart';
import '../state/call.dart';
import '../state/contacts.dart';
import '../state/dial_request.dart';
import '../state/session.dart';
import '../state/settings.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import 'contacts_screen.dart' show showContactForm;
import 'widgets.dart';

/// Экран набора номера.
class DialerScreen extends ConsumerStatefulWidget {
  const DialerScreen({super.key});

  @override
  ConsumerState<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends ConsumerState<DialerScreen> {
  static const _maxLength = 20;
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

  String _number = '';

  @override
  void initState() {
    super.initState();
    // Номер из ссылки tel:/sip: заменяет то, что набрано. Звонок не начинаем — человек нажмёт сам.
    // fireImmediately: запрос мог прийти раньше, чем экран построился.
    ref.listenManual(dialRequestProvider, (_, next) {
      if (next == null) return;
      setState(() => _number = next.length > _maxLength ? next.substring(0, _maxLength) : next);
      // Забываем запрос после кадра: оболочка с вкладками тоже его читает, и стирать его посреди рассылки нельзя.
      Future.microtask(() {
        if (mounted) ref.read(dialRequestProvider.notifier).clear();
      });
    }, fireImmediately: true);
  }

  void _press(String key) {
    if (_number.length >= _maxLength) return;
    setState(() => _number += key);
  }

  void _backspace() {
    if (_number.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _clear() {
    if (_number.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _number = '');
  }

  void _call() {
    if (_number.isEmpty) {
      // Поле пустое — как в обычном телефоне, подставляем последний набранный номер.
      // Звонок начнётся со второго нажатия, чтобы человек видел, куда звонит.
      final last = ref.read(callProvider.notifier).lastDialed;
      if (last == null) return;
      HapticFeedback.selectionClick();
      setState(() => _number = last);
      return;
    }
    ref.read(callProvider.notifier).dial(_number);
    // Как в обычном телефоне: после вызова поле пустое. Вернуть номер можно кнопкой вызова (повтор).
    setState(() => _number = '');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final p = style.palette;
    final ic = SadoIcons.of(context);
    final number = ref.watch(sessionProvider.select((a) => a?.number)) ?? '';
    final link = ref.watch(linkProvider);
    final dnd = ref.watch(settingsProvider.select((v) => v.dnd));
    // Русские буквы на клавишах — только когда приложение на русском.
    final russian = Localizations.localeOf(context).languageCode == 'ru';
    final (linkText, linkColor) = switch (link.state) {
      LinkState.online when dnd => (s.dndStatus(number), p.muted),
      LinkState.online => (s.online(number), p.success),
      LinkState.connecting => (s.linkConnecting(number), p.muted),
      LinkState.failed when link.error == LinkError.auth => (s.linkAuth(number), p.danger),
      LinkState.failed || LinkState.offline => (s.linkOffline(number), p.danger),
    };

    return LayoutBuilder(
      builder: (context, box) {
        // Размер клавиш подстраиваем и под высоту, и под ширину экрана: всё должно помещаться
        // и на маленьких телефонах, и у стилей с широкими клавишами.
        // В стиле «Материал» просветы между клавишами одинаковые по горизонтали и по вертикали.
        final gapV = style.numberInSheet ? style.keyGap : style.keyGap * 0.55;
        final byHeight =
            (box.maxHeight - (style.numberInSheet ? 290 : 250)) / (4 * (DialKey.heightFor(style, 1) + gapV));
        final byWidth = (box.maxWidth - 24) / (3 * DialKey.widthFor(style, 1) + 2 * style.keyGap);
        final keySize = math.min(byHeight, byWidth).clamp(44.0, style.keyAspect == null ? 78.0 : 92.0);
        final keyWidth = DialKey.widthFor(style, keySize);
        final gap = keySize * style.keyGap;
        final gridWidth = keyWidth * 3 + gap * 2;
        final empty = _number.isEmpty;

        // Кнопка «стереть». Короткое нажатие стирает цифру, долгое — весь номер.
        // Пока номера нет, её не видно и не нажать.
        Widget backspace(double width, double height) => IgnorePointer(
          ignoring: empty,
          child: AnimatedOpacity(
            opacity: empty ? 0 : 1,
            duration: const Duration(milliseconds: 120),
            // Без стандартной «волны» Android: у кнопки нет своей подложки, и волна расплывалась
            // серым пятном на соседние клавиши. Вместо неё значок коротко приглушается и сжимается.
            child: PressFade(
              key: const Key('dialer.backspace'),
              onTap: _backspace,
              onLongPress: _clear,
              child: SizedBox(
                width: width,
                height: height,
                child: Icon(ic.backspace, size: 28, color: p.muted),
              ),
            ),
          ),
        );
        final callButton = CallButton(
          key: const Key('dialer.call'),
          icon: ic.call,
          label: s.call,
          color: p.go,
          onColor: p.onGo,
          onTap: _call,
          size: keySize.clamp(56.0, 72.0),
        );
        final numberText = FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatNumber(_number),
            key: const Key('dialer.number'),
            maxLines: 1,
            style: TextStyle(
              fontSize: 36,
              fontWeight: style.keyShape == KeyShape.bare || style.numberInSheet ? FontWeight.w300 : FontWeight.w500,
              color: p.text,
              letterSpacing: 0.5,
            ),
          ),
        );
        final status = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: linkColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              linkText,
              key: const Key('dialer.link'),
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          ],
        );
        final rows = [
          for (var row = 0; row < 4; row++)
            Padding(
              padding: EdgeInsets.only(bottom: keySize * gapV),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) SizedBox(width: gap),
                    DialKey(
                      key: Key('key.${_keys[row * 3 + col]}'),
                      label: _keys[row * 3 + col],
                      letters: style.keyLetters ? (DialKey.lettersOf[_keys[row * 3 + col]] ?? '') : null,
                      letters2: style.keyLetters && style.numberInSheet && russian
                          ? (DialKey.cyrillicOf[_keys[row * 3 + col]] ?? '')
                          : null,
                      size: keySize,
                      onTap: () => _press(_keys[row * 3 + col]),
                      // Долгое нажатие на «0» ставит «+» для международных номеров.
                      onLongPress: _keys[row * 3 + col] == '0' ? () => _press('+') : null,
                    ),
                  ],
                ],
              ),
            ),
        ];

        if (style.numberInSheet) {
          // В духе Material Design: сверху — действия с номером, ниже «лист» с номером, клавишами
          // и кнопкой вызова по центру. «Стереть» стоит в строке номера справа.
          final known = empty || ref.watch(contactsProvider.select((list) => list.any((c) => c.number == _number)));
          return Column(
            children: [
              const SizedBox(height: 14),
              status,
              Expanded(
                child: known
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.topLeft,
                        child: InkWell(
                          key: const Key('dialer.saveContact'),
                          onTap: () => showContactForm(context, ref, number: _number),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 18, 24, 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(ic.addCall, color: p.accent, size: 26),
                                const SizedBox(width: 24),
                                Flexible(
                                  child: Text(
                                    s.newContact,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 18, color: p.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 62,
                      child: Row(
                        children: [
                          const SizedBox(width: 56),
                          Expanded(child: Center(child: numberText)),
                          backspace(56, 56),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...rows,
                    const SizedBox(height: 6),
                    // Кнопка вызова — чуть больше трети ширины, но не уже, чем нужно для подписи.
                    SizedBox(width: math.min(gridWidth, math.max(150.0, gridWidth * 0.4)), child: callButton),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        }

        final keypad = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rows,
            const SizedBox(height: 6),
            SizedBox(
              width: gridWidth,
              child: style.wideCallButton
                  // Широкая кнопка вызова занимает два левых столбца, «стереть» — третий.
                  ? Row(
                      children: [
                        Expanded(child: callButton),
                        SizedBox(width: gap),
                        backspace(keyWidth, DialKey.heightFor(style, keySize)),
                      ],
                    )
                  // Круглая кнопка вызова — под средним столбцом, «стереть» — ровно под правым.
                  : Row(
                      children: [
                        SizedBox(width: keyWidth),
                        SizedBox(width: gap),
                        SizedBox(
                          width: keyWidth,
                          child: Center(child: callButton),
                        ),
                        SizedBox(width: gap),
                        backspace(keyWidth, DialKey.heightFor(style, keySize)),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
          ],
        );

        return Column(
          children: [
            const SizedBox(height: 14),
            status,
            Expanded(
              child: Center(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: numberText),
              ),
            ),
            if (style.keypadSheet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: keypad,
              )
            else
              keypad,
          ],
        );
      },
    );
  }
}
