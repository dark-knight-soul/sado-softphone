import 'update_check.dart';

/// В браузерной версии кнопки проверки нет (ей не нужен APK), поэтому заглушка никогда
/// не вызывается. Если вызовут — честно отвечает «не удалось», а не «последняя версия».
UpdateChecker createUpdateChecker() => _NoUpdateChecker();

class _NoUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateResult> check() async => const UpdateFailed();
}
