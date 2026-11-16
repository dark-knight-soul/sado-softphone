import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../platform/phone_contacts.dart';
import '../state/call.dart';
import '../state/session.dart';
import '../state/settings.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import '../theme/styles.dart';
import 'update_section.dart';
import 'widgets.dart';

/// Вкладка «Ещё»: стиль, тема, язык, учётная запись.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final p = style.palette;
    final settings = ref.watch(settingsProvider);
    final account = ref.watch(sessionProvider);
    final controller = ref.read(settingsProvider.notifier);
    // У «Ночи» светлая и тёмная палитры совпадают — переключать тему нет смысла.
    final alwaysDark = identical(style.spec.light, style.spec.dark);

    return ListView(
      key: const Key('settings.list'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenTitle(s.settings),
        SectionLabel(s.style),
        SizedBox(
          height: 128,
          child: ListView.separated(
            key: const Key('settings.styles'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sadoStyles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final spec = sadoStyles[i];
              return _StyleCard(
                key: Key('style.${spec.id.name}'),
                spec: spec,
                name: s.styleName(spec.id),
                selected: spec.id == settings.styleId,
                onTap: () => controller.setStyle(spec.id),
              );
            },
          ),
        ),
        SectionLabel(s.theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: alwaysDark
              ? Text(s.themeAlwaysDark, style: TextStyle(fontSize: 14, color: p.muted))
              : Segmented<ThemeMode>(
                  options: {
                    ThemeMode.system: s.themeSystem,
                    ThemeMode.light: s.themeLight,
                    ThemeMode.dark: s.themeDark,
                  },
                  selected: settings.themeMode,
                  onChanged: controller.setThemeMode,
                ),
        ),
        SectionLabel(s.iconSet),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Segmented<IconSetId>(
            key: const Key('settings.icons'),
            options: {
              IconSetId.outlined: s.iconsOutlined,
              IconSetId.filled: s.iconsFilled,
              IconSetId.rounded: s.iconsRounded,
            },
            selected: settings.iconSet,
            onChanged: controller.setIconSet,
          ),
        ),
        const _AppIconRow(),
        SectionLabel(s.dnd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Segmented<bool>(
            key: const Key('settings.dnd'),
            options: {false: s.dndOff, true: s.dndOn},
            selected: settings.dnd,
            onChanged: controller.setDnd,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(s.dndNote, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
        ),
        // Мелодию входящих выбирает сам Android; в браузере и в демонстрации звонков через телефон нет.
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && account != null && !account.isDemo)
          const _RingRows(),
        if (phoneContactsAvailable(account)) ...[
          SectionLabel(s.phoneContactsTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Segmented<bool>(
              key: const Key('settings.phoneContacts'),
              options: {false: s.dndOff, true: s.dndOn},
              selected: settings.phoneContacts,
              // Включение просит разрешение у телефона; выключение просто прячет контакты.
              onChanged: (on) =>
                  on ? ref.read(phoneContactListProvider.notifier).enable() : controller.setPhoneContacts(false),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ListGroup(
          dividerIndent: 16,
          children: [
            ChoiceRow<AnswerMode>(
              key: const Key('settings.answer'),
              title: s.answerBy,
              options: {
                AnswerMode.auto: s.answerAuto,
                AnswerMode.buttons: s.answerButtons,
                AnswerMode.swipe: s.answerSwipe,
                AnswerMode.pill: s.answerPill,
                AnswerMode.slider: s.answerSlider,
              },
              selected: settings.answerMode,
              onChanged: controller.setAnswerMode,
            ),
            ChoiceRow<String>(
              key: const Key('settings.language'),
              title: s.language,
              // Пустая строка — «как в телефоне»: в Map нельзя удобно держать null-ключ с подписью.
              options: {'': s.langSystem, ...S.languageNames},
              selected: settings.lang ?? '',
              onChanged: (v) => controller.setLang(v.isEmpty ? null : v),
            ),
          ],
        ),
        if (account != null && !account.isDemo) ...[
          SectionLabel(s.background),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Segmented<bool>(
              key: const Key('settings.background'),
              options: {true: s.backgroundOn, false: s.backgroundOff},
              selected: settings.backgroundLink,
              onChanged: controller.setBackgroundLink,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(s.backgroundNote, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
          ),
          if (settings.backgroundLink) const _BatteryRow(),
          if (settings.backgroundLink) const _AutostartRow(),
          // Уведомления могли запретить; с Android 14 отдельно разрешается и экран звонка поверх блокировки.
          if (settings.backgroundLink)
            _PermissionRow(
              key: const Key('settings.notifications'),
              allowed: ref.read(callKeeperProvider).notificationsAllowed,
              open: ref.read(callKeeperProvider).openNotificationSettings,
              ask: s.notifAsk,
              note: s.notifNote,
            ),
          if (settings.backgroundLink)
            _PermissionRow(
              key: const Key('settings.fullScreen'),
              allowed: ref.read(callKeeperProvider).canFullScreenIntent,
              open: ref.read(callKeeperProvider).openFullScreenSettings,
              ask: s.fullScreenAsk,
              note: s.fullScreenNote,
            ),
        ],
        if (account != null) ...[
          SectionLabel(s.account),
          ListGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Avatar(icon: SadoIcons.of(context).person),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.number, style: TextStyle(fontSize: 16, color: p.text)),
                          const SizedBox(height: 2),
                          Text(
                            account.server,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('settings.signOut'),
                      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                      style: TextButton.styleFrom(foregroundColor: p.danger),
                      child: Text(s.signOut),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (account?.isDemo ?? false) ...[
          SectionLabel(s.demo),
          ListGroup(
            children: [
              InkWell(
                key: const Key('settings.demoIncoming'),
                onTap: () => ref.read(callProvider.notifier).simulateIncoming(number: '1002', name: 'Азиз Каримов'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Avatar(icon: SadoIcons.of(context).ring),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(s.demoIncoming, style: TextStyle(fontSize: 16, color: p.text)),
                      ),
                      Icon(SadoIcons.of(context).chevron, color: p.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(s.demoNote, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
          ),
        ],
        // Последним, чтобы служебный раздел не отодвигал настройки, которые меняют чаще.
        const AboutSection(),
      ],
    );
  }
}

/// Строка настройки с выбором из списка: слева название, справа текущее значение.
/// По нажатию снизу выезжает список вариантов.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;

  /// Значение → подпись, в порядке показа.
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final p = SadoStyle.of(context).palette;
    final picked = await showModalBottomSheet<T>(
      context: context,
      // Длинный список (языки) выше половины экрана: разрешаем окну расти и прокручиваться.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
            ),
            for (final entry in options.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == selected ? Icon(Icons.check, color: p.accent) : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = SadoStyle.of(context).palette;
    return InkWell(
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            // Название тоже может сжиматься: на узком экране с крупным системным шрифтом оно иначе
            // вытесняло бы значение за край строки.
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: p.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                options[selected] ?? '',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: p.muted),
              ),
            ),
            Icon(SadoIcons.of(context).chevron, color: p.muted),
          ],
        ),
      ),
    );
  }
}

/// Строка про ограничение батареи: кнопка, пока оно не снято, и подтверждение, когда снято.
/// Без снятия ограничения телефон в глубоком сне отключает приложению сеть.
class _BatteryRow extends ConsumerStatefulWidget {
  const _BatteryRow();

  @override
  ConsumerState<_BatteryRow> createState() => _BatteryRowState();
}

class _BatteryRowState extends ConsumerState<_BatteryRow> with WidgetsBindingObserver {
  bool? _unrestricted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Человек вернулся из системного окна — перепроверяем.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final value = await ref.read(callKeeperProvider).batteryUnrestricted();
    if (mounted) setState(() => _unrestricted = value);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final unrestricted = _unrestricted;
    if (unrestricted == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: unrestricted
          ? Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(s.batteryOk, style: TextStyle(fontSize: 13, color: p.success)),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('settings.battery'),
                onPressed: () => ref.read(callKeeperProvider).askBatteryExemption(),
                child: Text(s.batteryAsk),
              ),
            ),
    );
  }
}

/// Строка про «Автозапуск» на телефонах Xiaomi: кнопка открывает системный экран с переключателями.
/// Проверить, включён ли он, приложение не может, поэтому кнопка видна всегда (на других телефонах её нет).
class _AutostartRow extends ConsumerStatefulWidget {
  const _AutostartRow();

  @override
  ConsumerState<_AutostartRow> createState() => _AutostartRowState();
}

class _AutostartRowState extends ConsumerState<_AutostartRow> {
  bool _has = false;

  @override
  void initState() {
    super.initState();
    ref.read(callKeeperProvider).hasAutostartSettings().then((value) {
      if (mounted) setState(() => _has = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_has) return const SizedBox.shrink();
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            key: const Key('settings.autostart'),
            onPressed: () => ref.read(callKeeperProvider).openAutostartSettings(),
            child: Text(s.autostartAsk),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text(s.autostartNote, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Строка «разрешение не дано — вот кнопка, чтобы его дать». Видна, только пока разрешения нет;
/// после возвращения из системного окна перепроверяет его сама.
class _PermissionRow extends StatefulWidget {
  const _PermissionRow({super.key, required this.allowed, required this.open, required this.ask, required this.note});

  /// Дано ли разрешение сейчас.
  final Future<bool> Function() allowed;

  /// Открыть системный экран, где оно даётся.
  final Future<void> Function() open;
  final String ask;
  final String note;

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> with WidgetsBindingObserver {
  bool _allowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Человек вернулся из системного окна — перепроверяем.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final value = await widget.allowed();
    if (mounted) setState(() => _allowed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) return const SizedBox.shrink();
    final p = SadoStyle.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(onPressed: widget.open, child: Text(widget.ask)),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text(widget.note, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Мелодия и вибрация входящих. Значения хранит телефон (их читает фоновая служба), здесь только показ:
/// состояние читается при открытии, после возвращения в приложение и после каждого действия.
class _RingRows extends ConsumerStatefulWidget {
  const _RingRows();

  @override
  ConsumerState<_RingRows> createState() => _RingRowsState();
}

class _RingRowsState extends ConsumerState<_RingRows> with WidgetsBindingObserver {
  RingSettings? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(ref.read(callKeeperProvider).ringSettings());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Мелодию могли удалить или поменять, пока приложение было свёрнуто, — перечитываем.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _apply(ref.read(callKeeperProvider).ringSettings());
  }

  Future<void> _apply(Future<RingSettings> next) async {
    final value = await next;
    if (mounted) setState(() => _state = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final keeper = ref.read(callKeeperProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: ListGroup(
        dividerIndent: 16,
        children: [
          InkWell(
            key: const Key('settings.ringtone'),
            onTap: () => _apply(keeper.pickRingtone()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                children: [
                  // Подпись может сжиматься: на узком экране и длинном языке строка не должна вылезать за край.
                  Flexible(
                    child: Text(
                      s.ringtone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: p.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.title ?? s.ringtoneDefault,
                      key: const Key('settings.ringtone.title'),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: p.muted),
                    ),
                  ),
                  Icon(SadoIcons.of(context).chevron, color: p.muted),
                ],
              ),
            ),
          ),
          // Вкл/выкл — переключателем прямо в строке: выбирать из списка двух вариантов здесь лишний шаг.
          InkWell(
            key: const Key('settings.ringVibration'),
            onTap: () => _apply(keeper.setRingVibration(!state.vibrate)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.ringVibration,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: p.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    key: const Key('settings.ringVibration.switch'),
                    value: state.vibrate,
                    onChanged: (on) => _apply(keeper.setRingVibration(on)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Выбор значка приложения на рабочем столе: по одному значку на каждый стиль оформления.
/// На устройствах, где значок сменить нельзя, раздела нет.
class _AppIconRow extends ConsumerStatefulWidget {
  const _AppIconRow();

  @override
  ConsumerState<_AppIconRow> createState() => _AppIconRowState();
}

class _AppIconRowState extends ConsumerState<_AppIconRow> {
  /// Имена значков: шесть по стилям и два с надписью SADO; картинки лежат в assets/app_icons.
  static const _names = ['emerald', 'night', 'air', 'sunset', 'cupertino', 'material', 'sado', 'sadodark'];

  String? _current;

  @override
  void initState() {
    super.initState();
    ref.read(callKeeperProvider).appIcon().then((value) {
      if (mounted) setState(() => _current = value);
    });
  }

  Future<void> _pick(String name) async {
    if (name == _current) return;
    setState(() => _current = name);
    await ref.read(callKeeperProvider).setAppIcon(name);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(s.appIcon),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _names.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final name = _names[i];
              return GestureDetector(
                key: Key('appIcon.$name'),
                onTap: () => _pick(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: name == current ? p.accent : Colors.transparent, width: 2.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/app_icons/$name.png', width: 55, height: 55),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Карточка стиля с маленьким образцом его цветов и форм.
class _StyleCard extends StatelessWidget {
  const _StyleCard({super.key, required this.spec, required this.name, required this.selected, required this.onTap});

  final StyleSpec spec;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = SadoStyle.of(context).palette;
    // Образец рисуем в цветах самого стиля, а не текущего.
    final p = spec.resolve(Theme.of(context).brightness).palette;
    final keyRadius = spec.keyShape == KeyShape.rounded ? 5.0 : 9.0;
    Widget key() => Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: spec.keyShape == KeyShape.bare ? p.muted.withValues(alpha: 0.35) : p.surface,
        borderRadius: BorderRadius.circular(keyRadius),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 96,
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? current.accent : current.divider, width: selected ? 2.5 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [key(), const SizedBox(width: 5), key(), const SizedBox(width: 5), key()],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: spec.wideCallButton ? 62 : 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: p.go,
                      borderRadius: BorderRadius.circular(spec.wideCallButton ? spec.callButtonRadius / 2 : 13),
                    ),
                    child: Icon(SadoIcons.of(context).call, size: 14, color: p.onGo),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? current.accent : current.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
