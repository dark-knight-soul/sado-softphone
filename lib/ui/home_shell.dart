import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../state/dial_request.dart';
import '../state/home_filter.dart';
import '../state/setup_link.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import 'contacts_screen.dart';
import 'dialer_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Основа приложения после входа: вкладки и нижнее меню.
/// Порядок вкладок задаёт стиль (у «Купертино» и «Материала» он свой, как в их звонилках).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  AppTab _tab = AppTab.dial;

  @override
  void initState() {
    super.initState();
    // Номер из ссылки tel:/sip: — открываем экран набора. Сам номер подставит и сотрёт запрос экран набора.
    // fireImmediately: запрос мог прийти раньше, чем это окно построилось.
    ref.listenManual(dialRequestProvider, (_, next) {
      if (next != null && _tab != AppTab.dial) setState(() => _tab = AppTab.dial);
    }, fireImmediately: true);
    // Ссылка настройки, когда вход уже выполнен: учётную запись не трогаем, только объясняем, что делать.
    // Сообщение и очистка — после кадра: при fireImmediately окно ещё строится и не может искать ScaffoldMessenger.
    ref.listenManual(setupRequestProvider, (_, next) {
      if (next == null) return;
      Future.microtask(() {
        if (!mounted) return;
        ref.read(setupRequestProvider.notifier).clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.of(context).setupSignedIn)));
      });
    }, fireImmediately: true);
  }

  void _open(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ic = SadoIcons.of(context);
    final style = SadoStyle.of(context);
    // В духе Material Design: внизу только «Главная» и «Клавиатура»; контакты и настройки открываются
    // из верхней строки главного экрана.
    final unified = style.unifiedHome;
    (IconData, String) item(AppTab tab) => switch (tab) {
      AppTab.dial => (ic.dialpad, unified ? s.tabKeypad : s.tabDial),
      AppTab.history => unified ? (Icons.home_rounded, s.tabHome) : (ic.history, s.tabHistory),
      AppTab.contacts => (ic.contacts, s.tabContacts),
      AppTab.more => (ic.settings, s.tabMore),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (unified && (_tab == AppTab.history || _tab == AppTab.contacts)) _HomeHeader(tab: _tab, onTab: _open),
            // IndexedStack держит вкладки «живыми»: набранный номер и поиск не сбрасываются при переходах.
            // Порядок здесь постоянный — меняется только порядок кнопок в меню.
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: const [DialerScreen(), HistoryScreen(), ContactsScreen(), SettingsScreen()],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(
        // В стиле «Материал» всё, кроме клавиатуры, считается «Главной».
        current: unified && _tab != AppTab.dial ? AppTab.history : _tab,
        onTap: _open,
        items: [for (final tab in style.tabs) (tab, item(tab).$1, item(tab).$2)],
      ),
    );
  }
}

/// Верх главного экрана в духе Material Design: строка поиска (слева — меню с настройками)
/// и ряд фильтров: «Все», «Пропущенные», «Контакты».
class _HomeHeader extends ConsumerStatefulWidget {
  const _HomeHeader({required this.tab, required this.onTab});

  final AppTab tab;
  final ValueChanged<AppTab> onTab;

  @override
  ConsumerState<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<_HomeHeader> {
  late final TextEditingController _search = TextEditingController(text: ref.read(contactsQueryProvider));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final ic = SadoIcons.of(context);
    final missed = ref.watch(missedOnlyProvider);
    final onHistory = widget.tab == AppTab.history;

    // Flexible: на узком экране фильтры сжимаются (подпись обрезается), а не уезжают за край.
    // Доля ширины — по длине подписи, иначе длинное «Пропущенные» обрезалось бы и на обычном экране.
    Widget chip(String label, {required bool selected, required VoidCallback onTap, required Key key}) => Flexible(
      flex: label.length + 4,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? p.accent.withValues(alpha: 0.16) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: selected ? BorderSide.none : BorderSide(color: p.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.text),
              ),
            ),
          ),
        ),
      ),
    );

    void showHistory(bool missedOnly) {
      ref.read(missedOnlyProvider.notifier).set(missedOnly);
      widget.onTab(AppTab.history);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Material(
            color: p.card,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    // Ключ вкладки «Ещё»: в этом стиле настройки открываются отсюда.
                    key: Key('tab.${AppTab.more.index}'),
                    tooltip: s.tabMore,
                    onPressed: () => widget.onTab(AppTab.more),
                    icon: Icon(Icons.menu, color: p.text),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('home.search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      // Поиск идёт по контактам, поэтому сразу показываем их список.
                      onTap: () => widget.onTab(AppTab.contacts),
                      onChanged: (v) {
                        ref.read(contactsQueryProvider.notifier).set(v);
                        if (widget.tab != AppTab.contacts) widget.onTab(AppTab.contacts);
                      },
                      style: TextStyle(fontSize: 16, color: p.text),
                      decoration: InputDecoration(
                        hintText: s.searchHint,
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(ic.search, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              chip(
                s.filterAll,
                key: const Key('home.all'),
                selected: onHistory && !missed,
                onTap: () => showHistory(false),
              ),
              chip(
                s.filterMissed,
                key: const Key('home.missed'),
                selected: onHistory && missed,
                onTap: () => showHistory(true),
              ),
              chip(
                s.tabContacts,
                // Ключ вкладки «Контакты»: в этом стиле она открывается фильтром.
                key: Key('tab.${AppTab.contacts.index}'),
                selected: !onHistory,
                onTap: () => widget.onTab(AppTab.contacts),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onTap, required this.items});

  final AppTab current;
  final ValueChanged<AppTab> onTap;
  final List<(AppTab, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final style = SadoStyle.of(context);
    final p = style.palette;
    // Material, а не просто закрашенная коробка: иначе волна от нажатия рисуется под фоном меню.
    return Material(
      color: style.groupedLists ? p.card : p.bg,
      shape: Border(top: BorderSide(color: p.divider, width: 0.5)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: style.navPill ? 68 : 60,
          child: Row(
            children: [
              for (final (tab, icon, label) in items)
                Expanded(
                  child: InkWell(
                    // Ключ привязан к самой вкладке, а не к её месту в меню.
                    key: Key('tab.${tab.index}'),
                    onTap: () => onTap(tab),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (style.navPill)
                          // В духе Material Design: активная вкладка отмечена «пилюлей» под значком.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 60,
                            height: 30,
                            decoration: BoxDecoration(
                              color: tab == current ? p.accent.withValues(alpha: 0.16) : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(icon, size: 22, color: tab == current ? p.accent : p.muted),
                          )
                        else
                          Icon(icon, size: 24, color: tab == current ? p.accent : p.muted),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          // Меню фиксированной высоты: подпись растёт с системным шрифтом, но не больше чем на треть.
                          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: tab == current ? FontWeight.w600 : FontWeight.w400,
                            color: tab == current ? (style.navPill ? p.text : p.accent) : p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
