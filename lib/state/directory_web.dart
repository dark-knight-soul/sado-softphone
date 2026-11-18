import 'directory.dart';

/// В браузерной версии справочника нет: она нужна только для просмотра экранов, а хранить и отправлять
/// из браузера пароль от телефонии незачем.
DirectoryClient createDirectoryClient() => const _NoDirectoryClient();

class _NoDirectoryClient implements DirectoryClient {
  const _NoDirectoryClient();

  @override
  Future<bool?> probe(Uri url) async => false;

  @override
  Future<DirectoryReply> fetch(Uri url, {required String number, required String password, String? etag}) async =>
      const DirectoryAbsent();
}
