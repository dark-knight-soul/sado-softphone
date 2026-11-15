// Модели контактов и истории и демонстрационные данные для учётной записи `demo`.
// Когда появится API сервера Sado, контакты будут приходить оттуда.

enum Presence { free, busy, offline }

class Contact {
  const Contact({required this.name, required this.number, this.presence, this.isGroup = false});

  factory Contact.fromJson(Map<String, dynamic> json) =>
      Contact(name: json['name'] as String, number: json['number'] as String);

  final String name;
  final String number;

  /// Статус сотрудника; у отделов его нет.
  final Presence? presence;
  final bool isGroup;

  Map<String, dynamic> toJson() => {'name': name, 'number': number};
}

enum CallKind { outgoing, incoming, missed }

class HistoryEntry {
  const HistoryEntry({required this.number, required this.kind, required this.at, this.name, this.seconds = 0});

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    name: json['name'] as String?,
    number: json['number'] as String,
    kind: CallKind.values.asNameMap()[json['kind']] ?? CallKind.outgoing,
    seconds: (json['seconds'] as num?)?.toInt() ?? 0,
    at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
  );

  final String? name;
  final String number;
  final CallKind kind;

  /// Длительность разговора в секундах (0 — разговора не было).
  final int seconds;

  /// Когда звонок закончился.
  final DateTime at;

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    'number': number,
    'kind': kind.name,
    'seconds': seconds,
    'at': at.millisecondsSinceEpoch,
  };
}

const demoContacts = <Contact>[
  Contact(name: 'Азиз Каримов', number: '1002', presence: Presence.free),
  Contact(name: 'Дилноза Юсупова', number: '1004', presence: Presence.busy),
  Contact(name: 'Малика Тошева', number: '1006', presence: Presence.free),
  Contact(name: 'Шерзод Рахимов', number: '1005', presence: Presence.offline),
  Contact(name: 'Склад', number: '1010', isGroup: true),
  Contact(name: 'Бухгалтерия', number: '1020', isGroup: true),
  Contact(name: 'Касса', number: '1030', isGroup: true),
];

/// Образец истории: времена считаются от текущего момента, чтобы список всегда выглядел свежим.
List<HistoryEntry> demoHistory() {
  final now = DateTime.now();
  DateTime ago({int minutes = 0, int days = 0}) => now.subtract(Duration(minutes: minutes, days: days));
  return [
    HistoryEntry(name: 'Азиз Каримов', number: '1002', kind: CallKind.outgoing, seconds: 240, at: ago(minutes: 1)),
    HistoryEntry(name: 'Дилноза Юсупова', number: '1004', kind: CallKind.missed, at: ago(minutes: 2)),
    HistoryEntry(name: 'Склад', number: '1010', kind: CallKind.incoming, seconds: 75, at: ago(minutes: 3)),
    HistoryEntry(number: '905550122', kind: CallKind.incoming, seconds: 720, at: ago(days: 1)),
    HistoryEntry(name: 'Бухгалтерия', number: '1020', kind: CallKind.outgoing, seconds: 130, at: ago(days: 1)),
    HistoryEntry(name: 'Шерзод Рахимов', number: '1005', kind: CallKind.missed, at: ago(days: 3)),
  ];
}

final _nineDigits = RegExp(r'^\d{9}$');

/// Делает номер читаемым: девять цифр (номер в Узбекистане без кода страны)
/// показывает как «90 123 45 67», остальное не трогает.
String formatNumber(String raw) {
  if (!_nineDigits.hasMatch(raw)) return raw;
  return '${raw.substring(0, 2)} ${raw.substring(2, 5)} ${raw.substring(5, 7)} ${raw.substring(7)}';
}

/// Сколько длился разговор: «42 сек» или «4 мин» — слова подставляет вызывающий.
({int value, bool minutes}) splitDuration(int seconds) =>
    seconds < 60 ? (value: seconds, minutes: false) : (value: (seconds / 60).round(), minutes: true);

enum DayLabel { today, yesterday, earlier }

/// К какому дню относится время относительно [now] — чтобы показать «12:40», «вчера» или дату.
DayLabel dayLabelOf(DateTime at, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return DayLabel.today;
  return days == 1 ? DayLabel.yesterday : DayLabel.earlier;
}

String twoDigits(int n) => n.toString().padLeft(2, '0');
