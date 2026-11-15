import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../state/call.dart';
import '../state/settings.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import 'pill_answer.dart';
import 'swipe_answer.dart';
import 'widgets.dart';

/// Общая рамка экранов звонка: свой фон, свои значки строки состояния,
/// и запрет уйти с экрана системной кнопкой «Назад», пока звонок идёт.
class _CallFrame extends StatelessWidget {
  const _CallFrame({required this.palette, required this.child, this.gradient, this.bottomSafe = true});

  final CallPalette palette;
  final Widget child;

  /// Фон переходом цвета сверху вниз (в духе iOS); null — сплошной.
  final List<Color>? gradient;

  /// Оставлять ли отступ под полоску жестов. У раскладки с нижним «листом» лист сам доходит до края экрана.
  final bool bottomSafe;

  @override
  Widget build(BuildContext context) {
    final colors = gradient;
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayFor(palette.bg),
        child: Scaffold(
          backgroundColor: palette.bg,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: colors == null
                  ? null
                  : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            ),
            child: SafeArea(
              bottom: bottomSafe,
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Имя собеседника и подпись — по центру. Используется на входящем и в разговоре.
class _Caller extends StatelessWidget {
  const _Caller({
    required this.call,
    required this.palette,
    required this.status,
    this.avatar = 96,
    this.large = false,
    this.bold = false,
    this.statusAbove = false,
    this.titleSize,
    this.statusGap = 6,
  });

  /// Просвет между подписью и именем.
  final double statusGap;

  /// Свой размер имени; null — 34 у крупного и 27 у обычного.
  final double? titleSize;

  final CallInfo call;
  final CallPalette palette;
  final Widget status;

  /// Размер аватара; 0 — без аватара.
  final double avatar;

  /// Крупное имя, как в стилях «Купертино» и «Материал».
  final bool large;

  /// Жирное крупное имя (входящий в стиле «Купертино»).
  final bool bold;

  /// Подпись стоит над именем, а не под ним (так стоит таймер в стиле «Материал»).
  final bool statusAbove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (avatar > 0) ...[
          Avatar(name: call.name, size: avatar, background: palette.surface, foreground: palette.text),
          const SizedBox(height: 16),
        ],
        if (statusAbove) ...[status, SizedBox(height: statusGap)],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.caller(call.name, call.number),
              key: const Key('call.title'),
              maxLines: 1,
              style: TextStyle(
                fontSize: titleSize ?? (large ? 34 : 27),
                fontWeight: large ? (bold ? FontWeight.w700 : FontWeight.w400) : FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ),
        if (call.name != null && call.number.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(call.number, style: TextStyle(fontSize: 16, color: palette.muted)),
        ],
        if (!statusAbove) ...[const SizedBox(height: 6), status],
      ],
    );
  }
}

/// Шапка разговора в духе iOS: слева маленький аватар, рядом — таймер и под ним крупное имя.
class _CallerLeft extends StatelessWidget {
  const _CallerLeft({required this.call, required this.palette, required this.status});

  final CallInfo call;
  final CallPalette palette;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Avatar(name: call.name, size: 60, background: palette.surface, foreground: palette.text),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.caller(call.name, call.number),
                    key: const Key('call.title'),
                    maxLines: 1,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: palette.text, height: 1.15),
                  ),
                ),
                if (call.name != null && call.number.isNotEmpty)
                  Text(call.number, style: TextStyle(fontSize: 15, color: palette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Маленькая круглая кнопка с подписью — такие стоят над ползунком ответа в стиле «Купертино».
class _MiniAction extends StatelessWidget {
  const _MiniAction({super.key, required this.icon, required this.label, required this.palette, this.onTap});

  final IconData icon;
  final String label;
  final CallPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Material(
              color: palette.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(icon, size: 24, color: palette.text),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: palette.text)),
        ],
      ),
    );
  }
}

/// Способ ответа с учётом стиля: «как в стиле» превращается в принятый у этого стиля.
AnswerMode _answerModeFor(AnswerMode chosen, SadoStyle style) => chosen != AnswerMode.auto
    ? chosen
    : switch (style.callLayout) {
        CallLayout.cupertino => AnswerMode.slider,
        CallLayout.material => AnswerMode.pill,
        CallLayout.standard => AnswerMode.buttons,
      };

/// Входящий звонок: принять или отклонить.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    if (call == null) return const SizedBox.shrink();
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final c = style.palette.call;
    final ic = SadoIcons.of(context);
    final controller = ref.read(callProvider.notifier);
    final mode = _answerModeFor(ref.watch(settingsProvider.select((v) => v.answerMode)), style);
    final silenced = ref.watch(ringSilencedProvider);
    final layout = style.callLayout;
    final screen = MediaQuery.sizeOf(context);
    final cupertino = layout == CallLayout.cupertino;
    // В стиле «Купертино» над ползунком стоят две маленькие круглые кнопки — у нас это «Без звука» и «Отклонить».
    final cupertinoSlider = cupertino && mode == AnswerMode.slider;
    // На сколько поднять дорожку-«пилюлю» над низом экрана: её низ — примерно на 83% высоты экрана.
    final pillLift = (screen.height * 0.169 - MediaQuery.paddingOf(context).bottom - 12).clamp(16.0, 140.0);
    final VoidCallback? silenceTap = silenced ? null : ref.read(ringSilencedProvider.notifier).silence;

    // «Без звука»: мелодия и вибрация замолкают, звонок продолжает идти.
    final Widget silence = layout == CallLayout.material
        // «Чип» над кнопкой ответа — в духе Material Design.
        ? Material(
            // В тёмной теме в стиле «Материал» чип светлее фона (как дорожка ответа), в светлой — белый.
            color: ThemeData.estimateBrightnessForColor(c.bg) == Brightness.dark ? (c.sheet ?? c.surface) : c.surface,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('call.silence'),
              onTap: silenceTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic.silent, size: 20, color: silenced ? c.muted.withValues(alpha: 0.5) : c.text),
                    const SizedBox(width: 10),
                    Text(
                      s.silent,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: silenced ? c.muted.withValues(alpha: 0.5) : c.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : TextButton.icon(
            key: const Key('call.silence'),
            onPressed: silenceTap,
            style: TextButton.styleFrom(
              foregroundColor: c.text,
              disabledForegroundColor: c.muted.withValues(alpha: 0.5),
            ),
            icon: Icon(ic.silent, size: 20),
            label: Text(s.silent),
          );

    final Widget answer = switch (mode) {
      // Свайп вверх-вниз: ручке отдаём всё свободное место, ход подстраиваем под высоту экрана.
      AnswerMode.swipe => LayoutBuilder(
        builder: (context, box) => Center(
          child: VerticalSwipeAnswer(
            palette: c,
            icon: ic.call,
            declineIcon: ic.callEnd,
            acceptHint: s.swipeUpToAnswer,
            declineHint: s.swipeDownToDecline,
            acceptLabel: s.accept,
            onAccept: controller.accept,
            onDecline: controller.hangUp,
            // Там, где высота не ограничена (раскладка «Материала»), берём средний ход.
            travel: box.maxHeight.isFinite ? ((box.maxHeight - 132) / 2).clamp(36.0, 96.0) : 64.0,
          ),
        ),
      ),
      AnswerMode.slider => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SliderAnswer(
            palette: c,
            icon: ic.call,
            hint: s.slideToAnswer,
            acceptLabel: s.accept,
            declineLabel: s.decline,
            onAccept: controller.accept,
            onDecline: controller.hangUp,
            // В стиле «Купертино» кружок белый с зелёной трубкой.
            knobColor: cupertino ? Colors.white : null,
            knobIconColor: cupertino ? c.go : null,
            showDecline: !cupertinoSlider,
            large: cupertino,
          ),
        ),
      ),
      AnswerMode.pill => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: PillSwipeAnswer(
            palette: c,
            acceptIcon: ic.call,
            declineIcon: ic.callEnd,
            // В стиле «Материал»: на дорожке написано «Ответить», а не «Принять».
            acceptLabel: s.answerVerb,
            declineLabel: s.decline,
            onAccept: controller.accept,
            onDecline: controller.hangUp,
          ),
        ),
      ),
      // «Как в стиле» сюда не доходит — оно уже заменено выше; ветка нужна, чтобы перечисление было полным.
      AnswerMode.buttons || AnswerMode.auto => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              // heightFactor: без него Center растягивается на всю высоту, и кнопки оказываются посередине экрана.
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: CallButton(
                    key: const Key('call.decline'),
                    icon: ic.callEnd,
                    label: s.decline,
                    color: c.hangup,
                    onColor: c.onHangup,
                    onTap: controller.hangUp,
                    showLabel: true,
                    labelColor: c.muted,
                    size: 72,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Center(
                  heightFactor: 1,
                  child: CallButton(
                    key: const Key('call.accept'),
                    icon: ic.call,
                    label: s.accept,
                    color: c.go,
                    onColor: c.onGo,
                    onTap: controller.accept,
                    showLabel: true,
                    labelColor: c.muted,
                    size: 72,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    };

    final incomingText = Text(s.incomingCall, style: TextStyle(fontSize: 16, color: c.muted));

    final Widget body = switch (layout) {
      // В духе iOS: сверху мелкая подпись и крупное имя, внизу — ползунок, над ним две круглые кнопки.
      CallLayout.cupertino => Column(
        children: [
          const SizedBox(height: 44),
          incomingText,
          const SizedBox(height: 6),
          _Caller(call: call, palette: c, avatar: 0, large: true, bold: true, status: const SizedBox.shrink()),
          if (!cupertinoSlider) silence,
          Expanded(
            child: cupertinoSlider
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _MiniAction(
                                key: const Key('call.silence'),
                                icon: ic.silent,
                                label: s.silent,
                                palette: c,
                                onTap: silenceTap,
                              ),
                              _MiniAction(
                                key: const Key('call.decline'),
                                icon: ic.callEnd,
                                label: s.decline,
                                palette: c,
                                onTap: controller.hangUp,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 34),
                        answer,
                      ],
                    ),
                  )
                : answer,
          ),
          // В стиле «Купертино» ползунок стоит не у самого края, а заметно выше — примерно на 87% высоты экрана.
          SizedBox(height: cupertinoSlider ? (MediaQuery.sizeOf(context).height * 0.07).clamp(24.0, 64.0) : 28),
        ],
      ),
      // В духе Material Design: сверху мелкая подпись, крупное имя и номер;
      // аватара на входящем нет; «чип» и дорожка ответа стоят не у края, а заметно выше —
      // низ дорожки приходится примерно на 83% высоты экрана.
      CallLayout.material => Column(
        children: [
          SizedBox(height: (screen.height * 0.045).clamp(16.0, 40.0)),
          _Caller(
            call: call,
            palette: c,
            avatar: 0,
            large: true,
            titleSize: 44,
            statusAbove: true,
            statusGap: 14,
            status: Text(s.incomingCall, style: TextStyle(fontSize: 17, color: c.muted)),
          ),
          const Spacer(),
          silence,
          SizedBox(height: mode == AnswerMode.pill ? 41 : 16),
          answer,
          // Дорожка-«пилюля» поднята; остальным способам ответа хватает обычного отступа.
          SizedBox(height: mode == AnswerMode.pill ? pillLift : 24),
        ],
      ),
      CallLayout.standard => Column(
        children: [
          const SizedBox(height: 40),
          _Caller(call: call, palette: c, avatar: 104, status: incomingText),
          const SizedBox(height: 4),
          silence,
          Expanded(child: answer),
          // «Пилюля» и в обычных стилях стоит на той же высоте, что в стиле «Материал».
          SizedBox(height: mode == AnswerMode.pill ? pillLift : 20),
        ],
      ),
    };

    return _CallFrame(palette: c, gradient: c.incomingGradient, child: body);
  }
}

/// Исходящий вызов и сам разговор.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  /// Открыты ли клавиши донабора (для голосовых меню: «нажмите 1…»).
  bool _keypad = false;
  String _tones = '';

  /// Раскрыт ли второй ряд кнопок под «Ещё» (раскладка «Материала»).
  bool _more = false;

  /// Окно «Перевести звонок»: номер набирается клавишами приложения, а не клавиатурой телефона.
  Future<void> _transfer() async {
    final s = S.of(context);
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransferSheet(title: s.transferTitle, hint: s.transferHint, action: s.transfer),
    );
    if (target == null || target.isEmpty || !mounted) return;
    ref.read(callProvider.notifier).transfer(target);
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    if (call == null) return const SizedBox.shrink();
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final c = style.palette.call;
    final ic = SadoIcons.of(context);
    final controller = ref.read(callProvider.notifier);
    final layout = style.callLayout;
    final cupertino = layout == CallLayout.cupertino;
    final unified = layout == CallLayout.material;
    final active = call.phase == CallPhase.active;
    final screen = MediaQuery.sizeOf(context);
    final statusStyle = TextStyle(
      fontSize: cupertino ? 16 : 17,
      color: c.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final Widget status = call.phase == CallPhase.outgoing
        ? Text(s.calling, key: const Key('call.status'), style: statusStyle)
        : call.held
        ? Text(s.onHold, key: const Key('call.status'), style: statusStyle)
        : _Elapsed(key: const Key('call.status'), since: call.since ?? DateTime.now(), style: statusStyle);

    // Размеры кнопок: в стиле «Купертино» круги крупнее; в стиле «Материал» четыре овала в ряд должны поместиться на любом экране.
    final actionSize = cupertino ? 76.0 : (unified ? 64.0 : _CallAction.defaultSize);
    final actionWidth = unified ? ((screen.width - 24) / 4 - 10).clamp(54.0, 88.0) : null;
    _CallAction action(String key, IconData icon, String label, {bool on = false, VoidCallback? onTap}) => _CallAction(
      key: Key(key),
      icon: icon,
      label: label,
      palette: c,
      active: on,
      onTap: onTap,
      size: actionSize,
      width: actionWidth,
    );

    final mic = action('call.mute', ic.micOff, s.mic, on: call.muted, onTap: controller.toggleMute);
    // Донабор, удержание и перевод имеют смысл только в идущем разговоре.
    final keypad = action(
      'call.keypad',
      ic.dialpad,
      s.keypad,
      onTap: active ? () => setState(() => _keypad = true) : null,
    );
    final speaker = action('call.speaker', ic.speaker, s.speaker, on: call.speaker, onTap: controller.toggleSpeaker);
    final hold = action('call.hold', ic.hold, s.hold, on: call.held, onTap: active ? controller.toggleHold : null);
    final transfer = action('call.transfer', ic.transfer, s.transfer, onTap: active ? _transfer : null);
    final more = action(
      'call.more',
      Icons.more_vert,
      s.tabMore,
      on: _more,
      onTap: () => setState(() => _more = !_more),
    );
    final end = CallButton(
      key: const Key('call.hangup'),
      icon: ic.callEnd,
      label: s.hangUp,
      color: c.hangup,
      onColor: c.onHangup,
      onTap: controller.hangUp,
      size: cupertino && !_keypad ? actionSize : 72,
    );
    final pad = _DtmfPad(
      palette: c,
      tones: _tones,
      onKey: (k) {
        controller.sendDtmf(k);
        setState(() => _tones += k);
      },
      onClose: () => setState(() => _keypad = false),
    );
    // Место под надпись держим всегда, чтобы экран не прыгал, но показываем её только
    // у действительно зашифрованного звонка.
    final secure = Visibility(
      visible: call.secure,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Row(
        key: const Key('call.secure'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ic.lock, size: 14, color: c.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              s.secureHd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
          ),
        ],
      ),
    );

    // Ряд кнопок: каждая занимает ровно треть ширины, поэтому ряд помещается на любом экране.
    // Если кнопок две, они стоят по центру, занимая те же трети.
    Widget row(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (children.length == 2) const Spacer(),
        for (final child in children) Expanded(flex: 2, child: Center(child: child)),
        if (children.length == 2) const Spacer(),
      ],
    );

    final Widget body = switch (layout) {
      // В духе iOS: имя слева вверху, сетка кнопок внизу, «Завершить» — во втором ряду посередине.
      CallLayout.cupertino => Column(
        children: [
          const SizedBox(height: 14),
          secure,
          const SizedBox(height: 14),
          _CallerLeft(call: call, palette: c, status: status),
          if (_keypad) ...[
            // FittedBox: если клавишам всё же не хватает высоты, они уменьшаются, а не вылезают за экран.
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, child: pad),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: end),
            const SizedBox(height: 30),
          ] else ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row([speaker, hold, mic]),
                  const SizedBox(height: 22),
                  row([
                    transfer,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        end,
                        const SizedBox(height: 8),
                        Text(s.hangUp, style: TextStyle(fontSize: 13, color: c.text)),
                      ],
                    ),
                    keypad,
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
      // В духе Material Design: таймер и имя сверху, крупный аватар посередине, кнопки — на нижнем «листе».
      CallLayout.material => Column(
        children: [
          const SizedBox(height: 14),
          secure,
          SizedBox(height: _keypad ? 2 : 10),
          _Caller(call: call, palette: c, status: status, avatar: 0, large: true, statusAbove: true),
          Expanded(
            child: _keypad
                ? FittedBox(fit: BoxFit.scaleDown, child: pad)
                : LayoutBuilder(
                    builder: (context, box) {
                      final size = math.min(box.maxHeight - 32, math.min(box.maxWidth * 0.46, 176.0));
                      // На маленьком экране аватару может не хватить места — тогда обходимся без него.
                      if (size < 72) return const SizedBox.shrink();
                      return Center(
                        child: Avatar(name: call.name, size: size, background: c.surface, foreground: c.text),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 18, 12, 18 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: c.sheet ?? c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_keypad) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in [keypad, mic, speaker, more]) Expanded(child: Center(child: b)),
                    ],
                  ),
                  // «Ещё» раскрывает второй ряд: удержание и перевод.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topCenter,
                    child: _more
                        ? Padding(padding: const EdgeInsets.only(top: 16), child: row([hold, transfer]))
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 18),
                ],
                // Широкая красная «пилюля» со значком.
                SizedBox(
                  key: const Key('call.hangup'),
                  width: math.max(150.0, screen.width * 0.44),
                  height: 64,
                  child: Material(
                    color: c.hangup,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: controller.hangUp,
                      child: Icon(ic.callEnd, size: 30, color: c.onHangup, semanticLabel: s.hangUp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      CallLayout.standard => Column(
        children: [
          const SizedBox(height: 18),
          secure,
          SizedBox(height: _keypad ? 8 : 24),
          // С открытыми клавишами аватар прячем, иначе на маленьком экране всё не поместится.
          _Caller(call: call, palette: c, status: status, avatar: _keypad ? 0 : 92),
          if (_keypad)
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, child: pad),
            )
          else ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row([mic, keypad, speaker]),
                  const SizedBox(height: 22),
                  row([hold, transfer]),
                ],
              ),
            ),
            const Spacer(),
          ],
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: end),
          const SizedBox(height: 30),
        ],
      ),
    };

    return _CallFrame(palette: c, gradient: c.gradient, bottomSafe: !unified, child: body);
  }
}

/// Нижнее окно для перевода звонка: номер набирается клавишами приложения — такими же, как на экране набора.
class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.title, required this.hint, required this.action});

  final String title;
  final String hint;
  final String action;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
  static const _maxLength = 20;

  String _number = '';

  void _press(String key) {
    if (_number.length >= _maxLength) return;
    setState(() => _number += key);
  }

  void _backspace() {
    if (_number.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _submit() => Navigator.of(context).pop(_number);

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final p = style.palette;
    final ic = SadoIcons.of(context);
    final screen = MediaQuery.sizeOf(context);
    // Клавиши подгоняем и под ширину окна, и под высоту экрана (окно не должно закрывать весь экран).
    final byWidth = (screen.width - 40) / (3 * DialKey.widthFor(style, 1) + 2 * style.keyGap);
    final byHeight = (screen.height * 0.42) / (4 * DialKey.heightFor(style, 1) + 0.6);
    final keySize = math.min(byWidth, byHeight).clamp(40.0, 68.0);
    final empty = _number.isEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text),
            ),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          empty ? widget.hint : _number,
                          key: const Key('transfer.number'),
                          maxLines: 1,
                          style: empty
                              ? TextStyle(fontSize: 15, color: p.muted)
                              : TextStyle(fontSize: 28, color: p.text, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: empty,
                    child: AnimatedOpacity(
                      opacity: empty ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: PressFade(
                        key: const Key('transfer.backspace'),
                        onTap: _backspace,
                        onLongPress: () => setState(() => _number = ''),
                        child: SizedBox(width: 48, height: 48, child: Icon(ic.backspace, size: 26, color: p.muted)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var row = 0; row < 4; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) SizedBox(width: keySize * style.keyGap),
                      DialKey(
                        key: Key('transfer.key.${_keys[row * 3 + col]}'),
                        label: _keys[row * 3 + col],
                        letters: style.keyLetters ? (DialKey.lettersOf[_keys[row * 3 + col]] ?? '') : null,
                        size: keySize,
                        onTap: () => _press(_keys[row * 3 + col]),
                        // Долгое нажатие на «0» ставит «+», как на экране набора.
                        onLongPress: _keys[row * 3 + col] == '0' ? () => _press('+') : null,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              key: const Key('transfer.submit'),
              onPressed: empty ? null : _submit,
              child: Text(widget.action),
            ),
          ],
        ),
      ),
    );
  }
}

/// Клавиши донабора во время разговора.
class _DtmfPad extends StatelessWidget {
  const _DtmfPad({required this.palette, required this.tones, required this.onKey, required this.onClose});

  final CallPalette palette;
  final String tones;
  final ValueChanged<String> onKey;
  final VoidCallback onClose;

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    // Размер клавиш — как на экране набора: крупные на обычном телефоне, меньше на маленьком.
    // Считаем и по высоте, и по ширине: у стилей с широкими клавишами три клавиши иначе не помещаются в ряд.
    final screen = MediaQuery.sizeOf(context);
    // Из высоты вычитаем строку состояния и полоску навигации: на телефоне с тремя кнопками внизу их немало.
    final byHeight = (screen.height - MediaQuery.paddingOf(context).vertical - 330) / 4.6;
    final byWidth = (screen.width - 32) / (3 * DialKey.widthFor(style, 1) + 2 * style.keyGap);
    final keySize = math.min(byHeight, byWidth).clamp(44.0, 78.0);
    // Системная кнопка «Назад» закрывает клавиши, а не пытается уйти с экрана разговора.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Высота строки задана явно: иначе у крупного шрифта строка выше отведённого места и цифры обрезаются снизу.
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                tones,
                key: const Key('call.tones'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(fontSize: 20, height: 1.2, color: palette.text, letterSpacing: 2),
              ),
            ),
          ),
          for (var row = 0; row < 4; row++)
            Padding(
              padding: EdgeInsets.only(bottom: keySize > 60 ? 12 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) SizedBox(width: keySize * style.keyGap),
                    DialKey(
                      key: Key('dtmf.${_keys[row * 3 + col]}'),
                      label: _keys[row * 3 + col],
                      letters: style.keyLetters ? (DialKey.lettersOf[_keys[row * 3 + col]] ?? '') : null,
                      size: keySize,
                      background: palette.surface,
                      foreground: palette.text,
                      onTap: () => onKey(_keys[row * 3 + col]),
                    ),
                  ],
                ],
              ),
            ),
          IconButton(
            key: const Key('call.keypadClose'),
            onPressed: onClose,
            icon: Icon(Icons.keyboard_arrow_down, color: palette.muted, size: 28),
          ),
        ],
      ),
    );
  }
}

/// Кнопка действия во время звонка (микрофон, динамик и т. д.) с подписью.
/// Без [onTap] кнопка неактивна и выглядит бледнее — так честнее, чем кнопка, которая ничего не делает.
class _CallAction extends StatelessWidget {
  const _CallAction({
    super.key,
    required this.icon,
    required this.label,
    required this.palette,
    this.active = false,
    this.onTap,
    this.size = _CallAction.defaultSize,
    this.width,
  });

  static const defaultSize = 70.0;

  final IconData icon;
  final String label;
  final CallPalette palette;
  final bool active;
  final VoidCallback? onTap;

  /// Высота кнопки (у круглой — и ширина).
  final double size;

  /// Ширина кнопки-овала; null — по форме из стиля.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final radius = style.actionRadius ?? (style.keyShape == KeyShape.rounded ? style.keyRadius + 2 : null);
    final ShapeBorder shape = radius != null
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.clamp(0.0, size / 2)))
        : const CircleBorder();
    // У «плиток» кнопка шире, чем высота, — в духе Material Design.
    final buttonWidth = width ?? (style.actionRadius != null ? size * 1.24 : size);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: buttonWidth,
            height: size,
            child: Material(
              color: active ? palette.accent : palette.surface,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(icon, size: 28, color: active ? palette.onAccent : palette.text),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              // В стиле «Купертино» подписи под кнопками белые, в остальных стилях — приглушённые.
              color: style.callLayout == CallLayout.cupertino ? palette.text : palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Таймер разговора. Раз в секунду перерисовывает только сам себя, а не весь экран.
class _Elapsed extends StatefulWidget {
  const _Elapsed({super.key, required this.since, required this.style});

  final DateTime since;
  final TextStyle style;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    final total = d.isNegative ? 0 : d.inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return Text('$mm:$ss', style: widget.style);
  }
}
