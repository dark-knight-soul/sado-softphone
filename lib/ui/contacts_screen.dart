import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../platform/phone_contacts.dart';
import '../state/call.dart';
import '../state/contact_status.dart';
import '../state/contacts.dart';
import '../state/directory.dart';
import '../state/home_filter.dart';
import '../state/session.dart';
import '../state/settings.dart';
import '../theme/sado_icons.dart';
import '../theme/sado_style.dart';
import 'widgets.dart';

/// Открывает окно создания или изменения контакта. [number] — заранее подставленный номер
/// (например, при сохранении из истории).
Future<void> showContactForm(BuildContext context, WidgetRef ref, {Contact? existing, String? number}) async {
  final result = await showModalBottomSheet<Contact>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ContactForm(existing: existing, number: number),
  );
  if (result == null) return;
  final contacts = ref.read(contactsProvider.notifier);
  existing == null ? contacts.add(result) : contacts.replace(existing, result);
}

/// Контакты: своя записная книжка с поиском по имени и номеру.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Открыли контакты — самое время обновить справочник сотрудников (не чаще раза в минуту).
    Future.microtask(() {
      if (mounted) ref.read(directoryProvider.notifier).refresh(force: true);
    });
  }

  bool _matches(Contact c, String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || c.name.toLowerCase().contains(q) || c.number.contains(q);
  }

  /// Долгое нажатие на контакт: изменить или удалить.
  Future<void> _menu(Contact contact) async {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('contact.edit'),
              title: Text(s.editContact),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              key: const Key('contact.delete'),
              title: Text(s.delete, style: TextStyle(color: p.danger)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            // Запас снизу, чтобы последняя строка не прижималась к полоске жестов.
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await showContactForm(context, ref, existing: contact);
    if (action == 'delete') ref.read(contactsProvider.notifier).remove(contact);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = SadoStyle.of(context);
    final p = style.palette;
    // В стиле «Материал» поиск и заголовок стоят в общей верхней строке главного экрана (см. HomeShell).
    final unified = style.unifiedHome;
    final query = unified ? ref.watch(contactsQueryProvider) : _query;
    final all = ref.watch(contactsProvider);
    final people = all.where((c) => !c.isGroup && _matches(c, query)).toList();
    final groups = all.where((c) => c.isGroup && _matches(c, query)).toList();
    // Справочник АТС по отделам, в порядке сервера. Тех, кто уже есть в своих контактах, не повторяем.
    final own = {for (final c in all) c.number};
    final directory = ref.watch(directoryProvider)?.entries ?? const <DirectoryEntry>[];
    final byDepartment = <String, List<Contact>>{};
    for (final e in directory) {
      if (own.contains(e.number)) continue;
      final c = Contact(name: e.name, number: e.number);
      if (_matches(c, query)) (byDepartment[e.department] ??= []).add(c);
    }
    // Адресная книга телефона: только чтение, поэтому у её строк нет меню «изменить / удалить».
    final phoneAll = ref.watch(visiblePhoneContactsProvider);
    final phone = phoneAll.where((c) => _matches(c, query)).toList();
    final canOfferPhone = phoneContactsAvailable(ref.watch(sessionProvider));
    final phoneOn = ref.watch(settingsProvider.select((s) => s.phoneContacts));
    void dial(Contact c) => ref.read(callProvider.notifier).dial(c.number, name: c.name);
    // Статусы от АТС (свободен, говорит, не в сети); у образца для знакомства они записаны в самих контактах.
    final statuses = ref.watch(contactStatusProvider);
    Widget rowOf(Contact c) => _ContactRow(
      contact: c,
      presence: statuses[c.number] ?? c.presence,
      onCall: () => dial(c),
      onLongPress: () => _menu(c),
    );
    final phoneButton = canOfferPhone && !phoneOn
        ? Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TextButton.icon(
                key: const Key('contacts.phone'),
                onPressed: () => ref.read(phoneContactListProvider.notifier).enable(),
                icon: const Icon(Icons.contacts_outlined, size: 20),
                label: Text(s.showPhoneContacts, style: const TextStyle(fontSize: 15)),
              ),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unified)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TextButton.icon(
                key: const Key('contacts.add'),
                onPressed: () => showContactForm(context, ref),
                icon: Icon(SadoIcons.of(context).addCall, size: 22),
                label: Text(s.newContact, style: const TextStyle(fontSize: 15)),
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(child: ScreenTitle(s.contacts)),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: IconButton(
                  key: const Key('contacts.add'),
                  tooltip: s.newContact,
                  onPressed: () => showContactForm(context, ref),
                  icon: Icon(Icons.add, color: p.accent, size: 28),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('contacts.search'),
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: Icon(SadoIcons.of(context).search, color: p.muted),
                isDense: true,
              ),
            ),
          ),
        ],
        ?phoneButton,
        Expanded(
          child: people.isEmpty && groups.isEmpty && phone.isEmpty && byDepartment.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      // Пусто, потому что ничего не нашлось, или потому что контактов ещё нет вовсе.
                      all.isEmpty && phoneAll.isEmpty && directory.isEmpty ? s.noContacts : s.nothingFound,
                      key: Key(
                        all.isEmpty && phoneAll.isEmpty && directory.isEmpty ? 'contacts.empty' : 'contacts.notFound',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 15),
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(top: unified ? 0 : 12, bottom: 16),
                  children: [
                    if (people.isNotEmpty) ...[
                      // Заголовок нужен, только когда ниже идут другие разделы.
                      if (byDepartment.isNotEmpty)
                        SectionLabel(s.myContacts)
                      else if (groups.isNotEmpty)
                        SectionLabel(s.employees),
                      ListGroup(children: [for (final c in people) rowOf(c)]),
                    ],
                    // Коллеги из справочника АТС: их нельзя изменить или удалить, поэтому без меню.
                    for (final MapEntry(key: department, value: colleagues) in byDepartment.entries) ...[
                      SectionLabel(department.isEmpty ? s.employees : department),
                      ListGroup(
                        key: Key('contacts.department.$department'),
                        children: [
                          for (final c in colleagues)
                            _ContactRow(contact: c, presence: statuses[c.number], onCall: () => dial(c)),
                        ],
                      ),
                    ],
                    if (groups.isNotEmpty) ...[
                      SectionLabel(s.departments),
                      ListGroup(children: [for (final c in groups) rowOf(c)]),
                    ],
                    if (phone.isNotEmpty) ...[
                      SectionLabel(s.fromPhone),
                      ListGroup(
                        children: [for (final c in phone) _ContactRow(contact: c, onCall: () => dial(c))],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onCall, this.onLongPress, this.presence});

  final Contact contact;

  /// Статус номера, если он известен; иначе под именем показываем просто номер.
  final Presence? presence;
  final VoidCallback onCall;

  /// Нет у контактов из телефона: их здесь не изменить.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final ic = SadoIcons.of(context);
    final (String? status, Color color) = switch (presence) {
      Presence.free => (s.statusFree, p.success),
      Presence.busy => (s.statusBusy, p.danger),
      Presence.offline => (s.statusOffline, p.muted),
      null => (contact.isGroup ? s.group : null, p.muted),
    };

    return InkWell(
      onTap: onCall,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 6, 9),
        child: Row(
          children: [
            Avatar(name: contact.name, icon: contact.isGroup ? ic.group : null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: p.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status == null ? formatNumber(contact.number) : '$status · ${contact.number}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCall,
              icon: Icon(ic.call, color: p.go),
            ),
          ],
        ),
      ),
    );
  }
}

/// Нижнее окно: имя и номер контакта.
class _ContactForm extends StatefulWidget {
  const _ContactForm({this.existing, this.number});

  final Contact? existing;
  final String? number;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _number = TextEditingController(text: widget.existing?.number ?? widget.number ?? '');

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(Contact(name: _name.text.trim(), number: _number.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.fieldRequired : null;
    return Padding(
      // Поднимаем содержимое над клавиатурой телефона.
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? s.newContact : s.editContact,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('contact.name'),
              controller: _name,
              // Если номер уже подставлен, сразу ставим курсор в имя.
              autofocus: true,
              validator: required,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: s.contactName),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('contact.number'),
              controller: _number,
              validator: required,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+*#]'))],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: s.number),
            ),
            const SizedBox(height: 16),
            FilledButton(key: const Key('contact.save'), onPressed: _submit, child: Text(s.save)),
          ],
        ),
      ),
    );
  }
}
