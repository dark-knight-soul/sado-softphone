import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'directory.dart';

/// Что умеет АТС сверх обычных звонков. Приложение работает с любыми АТС, а эти возможности у каждой свои
/// (служебные коды), поэтому по умолчанию их нет и кнопок для них не видно.
@immutable
class PbxFeatures {
  const PbxFeatures({this.conferencePrefix, this.conferenceDigits = 6, this.recordCode});

  /// Ничего сверх обычных звонков.
  static const none = PbxFeatures();

  /// Начало номера временной комнаты для конференции (например `*3`); за ним идёт случайный код из
  /// [conferenceDigits] цифр. null — конференции на АТС нет.
  final String? conferencePrefix;
  final int conferenceDigits;

  /// Код, который включает и выключает запись разговора (набирается во время звонка, например `*1`).
  /// null — записи по кнопке нет или этому номеру она не разрешена.
  final String? recordCode;

  bool get canConference => conferencePrefix != null && conferencePrefix!.isNotEmpty && conferenceDigits > 0;

  /// Номер новой временной комнаты: префикс и случайный код. Случайность — криптографическая: зная номер
  /// комнаты, в неё может войти любой сотрудник, так что код не должен угадываться.
  String newConferenceRoom([Random? random]) {
    final r = random ?? Random.secure();
    final code = [for (var i = 0; i < conferenceDigits; i++) r.nextInt(10)].join();
    return '$conferencePrefix$code';
  }

  @override
  bool operator ==(Object other) =>
      other is PbxFeatures &&
      other.conferencePrefix == conferencePrefix &&
      other.conferenceDigits == conferenceDigits &&
      other.recordCode == recordCode;

  @override
  int get hashCode => Object.hash(conferencePrefix, conferenceDigits, recordCode);
}

/// Возможности АТС текущей учётной записи. АТС сообщает о них вместе со справочником сотрудников
/// ([directoryProvider]); пока она ничего не сообщила — возможностей нет.
class PbxFeaturesController extends Notifier<PbxFeatures> {
  @override
  PbxFeatures build() => ref.watch(directoryProvider.select((d) => d?.features)) ?? PbxFeatures.none;

  /// Задать возможности напрямую (до следующего ответа АТС) — для тестов.
  void set(PbxFeatures features) {
    if (features != state) state = features;
  }
}

final pbxFeaturesProvider = NotifierProvider<PbxFeaturesController, PbxFeatures>(PbxFeaturesController.new);
