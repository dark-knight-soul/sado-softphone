// Push-уведомления: разбор сведений, которые телефон отдаёт приложению для АТС.
import 'package:flutter_test/flutter_test.dart';
import 'package:sado/platform/call_keeper.dart';

void main() {
  test('полный ответ телефона разбирается', () {
    final info = PushInfo.fromMap({'provider': 'fcm', 'project': 'my-pbx', 'token': 'abc:123'});
    expect(info, isNotNull);
    expect(info!.provider, 'fcm');
    expect(info.project, 'my-pbx');
    expect(info.token, 'abc:123');
  });

  test('неполный или непонятный ответ значит «push нет»', () {
    expect(PushInfo.fromMap(null), isNull);
    expect(PushInfo.fromMap('fcm'), isNull);
    expect(PushInfo.fromMap(<String, String>{}), isNull);
    expect(PushInfo.fromMap({'provider': 'fcm', 'project': 'my-pbx'}), isNull);
    expect(PushInfo.fromMap({'provider': 'fcm', 'project': 'my-pbx', 'token': ''}), isNull);
    expect(PushInfo.fromMap({'provider': 'fcm', 'project': '', 'token': 'abc'}), isNull);
    expect(PushInfo.fromMap({'provider': 1, 'project': 'my-pbx', 'token': 'abc'}), isNull);
  });

  test('там, где push нет (не Android, сборка без Google), сторож так и отвечает', () async {
    final keeper = NoopCallKeeper();
    expect(await keeper.pushInfo(), isNull);
    expect(await keeper.takePushWake(), isFalse);
  });
}
