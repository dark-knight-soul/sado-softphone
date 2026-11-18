import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call.dart';
import 'pbx_features.dart';

/// Какие разговоры сейчас записываются по кнопке — номера звонков ([CallInfo.id]).
///
/// Запись ведёт АТС: приложение лишь набирает во время разговора служебный код, который включает и выключает
/// её ([PbxFeatures.recordCode]). Сообщить приложению, идёт ли запись, АТС не может, поэтому состояние здесь —
/// это то, что нажал человек. Если АТС отказала (она даёт звуковой сигнал ошибки), пометка «идёт запись»
/// останется до следующего нажатия.
class RecordingController extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    // Звонок закончился — его записи тоже конец. Проверяем не сразу, а когда оба звонка обновились:
    // при переключении между двумя разговорами они меняются по очереди, и в промежутке один из них
    // на миг не числится ни текущим, ни вторым.
    var scheduled = false;
    void prune() {
      if (scheduled) return;
      scheduled = true;
      Future.microtask(() {
        scheduled = false;
        if (!ref.mounted) return;
        final alive = {ref.read(callProvider)?.id, ref.read(otherCallProvider)?.id};
        final kept = state.where(alive.contains).toSet();
        if (kept.length != state.length) state = kept;
      });
    }

    ref.listen(callProvider, (_, _) => prune());
    ref.listen(otherCallProvider, (_, _) => prune());
    return const {};
  }

  /// Включить или выключить запись текущего разговора. Ничего не делает, если АТС не сообщила код записи
  /// (значит, этому номеру запись не разрешена или АТС её не умеет) или разговор ещё не соединён.
  void toggle() {
    final code = ref.read(pbxFeaturesProvider).recordCode;
    final call = ref.read(callProvider);
    if (code == null || call == null || call.since == null || call.held) return;
    ref.read(callProvider.notifier).sendDtmf(code);
    state = state.contains(call.id) ? ({...state}..remove(call.id)) : {...state, call.id};
  }
}

final recordingProvider = NotifierProvider<RecordingController, Set<int>>(RecordingController.new);
