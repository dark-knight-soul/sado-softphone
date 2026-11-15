import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../state/call.dart';
import '../state/contacts.dart';
import '../state/history.dart';
import '../state/home_filter.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import 'contacts_screen.dart' show showContactForm;
import 'widgets.dart';

/// История звонков с фильтром «Все / Пропущенные».
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final p = style.palette;
    // В стиле «Материал» заголовок и фильтр стоят в общей верхней строке главного экрана (см. HomeShell).
    final unified = style.unifiedHome;
    final missedOnly = ref.watch(missedOnlyProvider);
    final all = ref.watch(historyProvider);
    // Следим за контактами, чтобы имена в истории появлялись сразу после сохранения.
    ref.watch(contactsProvider);
    final nameOf = ref.read(contactsProvider.notifier).nameOf;
    final entries = missedOnly ? all.where((e) => e.kind == CallKind.missed).toList() : all;
    final now = DateTime.now();
    Widget rowOf(HistoryEntry e) => _HistoryRow(
      entry: e,
      name: e.name ?? nameOf(e.number),
      now: now,
      unified: unified,
      // На скрытый номер перезвонить нельзя.
      onTap: e.number.isEmpty
          ? null
          : () => ref.read(callProvider.notifier).dial(e.number, name: e.name ?? nameOf(e.number)),
      // Долгое нажатие на незнакомый номер — сохранить его в контакты.
      onLongPress: e.number.isEmpty || (e.name ?? nameOf(e.number)) != null
          ? null
          : () => showContactForm(context, ref, number: e.number),
    );
    // В стиле «Материал» история разбита по дням: «Сегодня», «Вчера», «Раньше».
    final byDay = <DayLabel, List<HistoryEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(dayLabelOf(e.at, now), () => []).add(e);
    }
    String dayTitle(DayLabel day) => switch (day) {
      DayLabel.today => s.today,
      DayLabel.yesterday => s.yesterdayTitle,
      DayLabel.earlier => s.earlier,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!unified) ...[
          ScreenTitle(s.history),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Segmented<bool>(
              options: {false: s.filterAll, true: s.filterMissed},
              selected: missedOnly,
              onChanged: ref.read(missedOnlyProvider.notifier).set,
            ),
          ),
        ],
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.historyEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 15),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: unified
                      ? [
                          for (final day in DayLabel.values)
                            if (byDay[day] != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 12, 20, 8),
                                child: Text(
                                  dayTitle(day),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.accent),
                                ),
                              ),
                              ListGroup(children: [for (final e in byDay[day]!) rowOf(e)]),
                            ],
                        ]
                      : [
                          ListGroup(children: [for (final e in entries) rowOf(e)]),
                        ],
                ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.name,
    required this.now,
    required this.onTap,
    this.onLongPress,
    this.unified = false,
  });

  /// Вид строки в духе Material Design: время стоит в подписи, справа — значок трубки.
  final bool unified;

  final HistoryEntry entry;
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Имя для показа: из самой записи или из контактов.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final missed = entry.kind == CallKind.missed;
    final icon = switch (entry.kind) {
      CallKind.outgoing => SadoIcons.of(context).outgoing,
      CallKind.incoming => SadoIcons.of(context).incoming,
      CallKind.missed => SadoIcons.of(context).missed,
    };
    final d = splitDuration(entry.seconds);
    final length = missed ? s.missed : (d.minutes ? s.minutes(d.value) : s.seconds(d.value));
    // Под именем — номер, под «голым» номером — только длительность.
    final clock = '${twoDigits(entry.at.hour)}:${twoDigits(entry.at.minute)}';
    final when = switch (dayLabelOf(entry.at, now)) {
      DayLabel.today => clock,
      // В стиле «Материал» день уже написан в заголовке группы, поэтому в строке — только время.
      DayLabel.yesterday => unified ? clock : s.yesterday,
      DayLabel.earlier => '${twoDigits(entry.at.day)}.${twoDigits(entry.at.month)}',
    };
    final details = [
      if (name != null && entry.number.isNotEmpty) entry.number,
      length,
      if (unified) when,
    ].join(unified ? ' • ' : ' · ');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Avatar(name: name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.caller(name, entry.number),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: missed ? p.danger : p.text),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: missed ? p.danger : p.muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unified)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(SadoIcons.of(context).call, size: 22, color: onTap == null ? p.divider : p.text),
              )
            else
              Text(when, style: TextStyle(fontSize: 13, color: p.muted)),
          ],
        ),
      ),
    );
  }
}
