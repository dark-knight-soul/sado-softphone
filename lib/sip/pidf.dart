import '../data/demo_data.dart';

/// Номер, похожий на внутренний (короткий, из одних цифр): только за такими есть смысл следить —
/// городской или мобильный номер АТС «статусом» не снабжает.
bool isExtensionLike(String number) => RegExp(r'^\d{2,7}$').hasMatch(number);

/// Разбирает статус номера из уведомления АТС (тело в формате PIDF, RFC 3863 — так его присылают
/// Asterisk, FreeSWITCH и Kamailio на подписку «presence»).
///
/// Возвращает null, если по телу ничего понять нельзя.
///
/// Правила: `<basic>closed</basic>` — не в сети; «открыт» и при этом отмечен разговор (значок `on-the-phone`
/// или `busy` из RFC 4480 либо пометка вида «On the phone», «Ringing», «On hold») — говорит; иначе свободен.
Presence? presenceFromPidf(String? body) {
  if (body == null || body.isEmpty) return null;
  final text = body.toLowerCase();
  final basic = RegExp(r'<(?:[\w-]+:)?basic>\s*(open|closed)\s*<').firstMatch(text)?.group(1);
  if (basic == null) return null;
  if (basic == 'closed') return Presence.offline;
  final busyMark = RegExp(r'<(?:[\w-]+:)?(?:on-the-phone|busy)\s*/?>').hasMatch(text);
  final busyNote = RegExp(r'<(?:[\w-]+:)?note[^>]*>[^<]*(?:on the phone|ringing|on hold|busy|in use|talking)')
      .hasMatch(text);
  return busyMark || busyNote ? Presence.busy : Presence.free;
}
