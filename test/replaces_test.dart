import 'package:flutter_test/flutter_test.dart';
import 'package:sado/sip/sip_engine.dart';

// Метки для заголовка Replaces («Соединить» при переводе с консультацией).
// На учебном движке это место не проверить: ошибка видна только на настоящей АТС,
// где «Соединить» просто не сработает. Поэтому правило закреплено здесь.
void main() {
  const ours = 'our-tag';
  const pbx = 'pbx-tag';

  test('звонили мы: наша метка в From, метка АТС в To', () {
    final tags = replacesTags(incoming: false, fromTag: ours, toTag: pbx);
    expect(tags.toTag, pbx, reason: 'to-tag в Replaces — метка АТС');
    expect(tags.fromTag, ours, reason: 'from-tag в Replaces — наша метка');
  });

  test('звонили нам: метки в исходном INVITE стоят наоборот, в Replaces — всё равно АТС и мы', () {
    final tags = replacesTags(incoming: true, fromTag: pbx, toTag: ours);
    expect(tags.toTag, pbx, reason: 'to-tag в Replaces — метка АТС');
    expect(tags.fromTag, ours, reason: 'from-tag в Replaces — наша метка');
  });
}
