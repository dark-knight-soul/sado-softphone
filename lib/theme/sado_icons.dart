import 'package:material_ui/material_ui.dart';

/// Наборы значков. Имя (`name`) сохраняется в настройках — не переименовывать.
enum IconSetId { outlined, filled, rounded }

/// Все значки приложения в одном наборе. Экраны берут их отсюда (`SadoIcons.of(context)`),
/// а не напрямую из `Icons`, — поэтому набор меняется одной настройкой.
///
/// Все поля — константы: при сборке в приложение попадают только реально использованные значки.
@immutable
class SadoIcons extends ThemeExtension<SadoIcons> {
  const SadoIcons({
    required this.id,
    required this.dialpad,
    required this.history,
    required this.contacts,
    required this.settings,
    required this.call,
    required this.callEnd,
    required this.backspace,
    required this.micOff,
    required this.speaker,
    required this.hold,
    required this.transfer,
    required this.addCall,
    required this.lock,
    required this.search,
    required this.show,
    required this.hide,
    required this.outgoing,
    required this.incoming,
    required this.missed,
    required this.group,
    required this.person,
    required this.ring,
    required this.message,
    required this.silent,
    required this.chevron,
    required this.qr,
  });

  final IconSetId id;
  final IconData dialpad;
  final IconData history;
  final IconData contacts;
  final IconData settings;
  final IconData call;
  final IconData callEnd;
  final IconData backspace;
  final IconData micOff;
  final IconData speaker;
  final IconData hold;
  final IconData transfer;
  final IconData addCall;
  final IconData lock;
  final IconData search;

  /// «Глаз» в поле пароля: показать и скрыть.
  final IconData show;
  final IconData hide;
  final IconData outgoing;
  final IconData incoming;
  final IconData missed;
  final IconData group;
  final IconData person;
  final IconData ring;
  final IconData message;
  final IconData silent;
  final IconData chevron;
  final IconData qr;

  static SadoIcons of(BuildContext context) => Theme.of(context).extension<SadoIcons>() ?? outlined;

  static SadoIcons byId(IconSetId id) => switch (id) {
    IconSetId.outlined => outlined,
    IconSetId.filled => filled,
    IconSetId.rounded => rounded,
  };

  /// Контурные — лёгкие, с тонкой линией.
  static const outlined = SadoIcons(
    id: IconSetId.outlined,
    dialpad: Icons.dialpad_outlined,
    history: Icons.history_outlined,
    contacts: Icons.people_outline,
    settings: Icons.settings_outlined,
    call: Icons.call_outlined,
    callEnd: Icons.call_end_outlined,
    backspace: Icons.backspace_outlined,
    micOff: Icons.mic_off_outlined,
    speaker: Icons.volume_up_outlined,
    hold: Icons.pause_outlined,
    transfer: Icons.phone_forwarded_outlined,
    addCall: Icons.person_add_alt_outlined,
    lock: Icons.lock_outline,
    search: Icons.search_outlined,
    show: Icons.visibility_outlined,
    hide: Icons.visibility_off_outlined,
    outgoing: Icons.call_made_outlined,
    incoming: Icons.call_received_outlined,
    missed: Icons.call_missed_outlined,
    group: Icons.apartment_outlined,
    person: Icons.person_outline,
    ring: Icons.ring_volume_outlined,
    message: Icons.chat_bubble_outline,
    silent: Icons.notifications_off_outlined,
    chevron: Icons.chevron_right_outlined,
    qr: Icons.qr_code_2_outlined,
  );

  /// Закрашенные — плотные, заметные.
  static const filled = SadoIcons(
    id: IconSetId.filled,
    dialpad: Icons.dialpad,
    history: Icons.history,
    contacts: Icons.people,
    settings: Icons.settings,
    call: Icons.call,
    callEnd: Icons.call_end,
    backspace: Icons.backspace,
    micOff: Icons.mic_off,
    speaker: Icons.volume_up,
    hold: Icons.pause,
    transfer: Icons.phone_forwarded,
    addCall: Icons.person_add_alt_1,
    lock: Icons.lock,
    search: Icons.search,
    show: Icons.visibility,
    hide: Icons.visibility_off,
    outgoing: Icons.call_made,
    incoming: Icons.call_received,
    missed: Icons.call_missed,
    group: Icons.apartment,
    person: Icons.person,
    ring: Icons.ring_volume,
    message: Icons.chat_bubble,
    silent: Icons.notifications_off,
    chevron: Icons.chevron_right,
    qr: Icons.qr_code_2,
  );

  /// Скруглённые — закрашенные с мягкими углами.
  static const rounded = SadoIcons(
    id: IconSetId.rounded,
    dialpad: Icons.dialpad_rounded,
    history: Icons.history_rounded,
    contacts: Icons.people_alt_rounded,
    settings: Icons.settings_rounded,
    call: Icons.call_rounded,
    callEnd: Icons.call_end_rounded,
    backspace: Icons.backspace_rounded,
    micOff: Icons.mic_off_rounded,
    speaker: Icons.volume_up_rounded,
    hold: Icons.pause_rounded,
    transfer: Icons.phone_forwarded_rounded,
    addCall: Icons.person_add_alt_1_rounded,
    lock: Icons.lock_rounded,
    search: Icons.search_rounded,
    show: Icons.visibility_rounded,
    hide: Icons.visibility_off_rounded,
    outgoing: Icons.call_made_rounded,
    incoming: Icons.call_received_rounded,
    missed: Icons.call_missed_rounded,
    group: Icons.apartment_rounded,
    person: Icons.person_rounded,
    ring: Icons.ring_volume_rounded,
    message: Icons.chat_bubble_rounded,
    silent: Icons.notifications_off_rounded,
    chevron: Icons.chevron_right_rounded,
    qr: Icons.qr_code_2_rounded,
  );

  @override
  SadoIcons copyWith() => this;

  // Наборы не смешиваем: при смене просто переключаемся на середине анимации.
  @override
  SadoIcons lerp(covariant SadoIcons? other, double t) => (other == null || t < 0.5) ? this : other;
}
