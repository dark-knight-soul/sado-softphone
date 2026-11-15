import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Показывать в истории только пропущенные. Вынесено из экрана истории, потому что в «Материале»
/// фильтр стоит в общей верхней строке главного экрана, а не внутри самой истории.
class MissedOnly extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final missedOnlyProvider = NotifierProvider<MissedOnly, bool>(MissedOnly.new);

/// Текст поиска по контактам из верхней строки главного экрана («Материал»).
class ContactsQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final contactsQueryProvider = NotifierProvider<ContactsQuery, String>(ContactsQuery.new);
