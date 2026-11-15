import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../platform/call_keeper.dart';
import '../state/app_version.dart';
import '../state/update_check.dart';
import '../theme/sado_style.dart';
import 'widgets.dart';

/// Раздел «О приложении» внизу настроек: номер версии и ручная проверка обновлений.
/// Приложение раздаётся APK-файлом с GitHub, само оно о новых версиях не узнаёт. Обращаемся
/// к GitHub только по нажатию — ни при запуске, ни в фоне, как обещано человеку.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  bool _checking = false;
  UpdateResult? _result;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await ref.read(updateCheckerProvider).check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = SadoStyle.of(context).palette;
    final result = _result;
    return Column(
      key: const Key('settings.about'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(s.about),
        ListGroup(
          dividerIndent: 16,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                s.versionLabel(appVersion),
                key: const Key('settings.version'),
                style: TextStyle(fontSize: 16, color: p.text),
              ),
            ),
            // В браузерной версии APK не нужен — кнопку не показываем, номер версии оставляем.
            if (!kIsWeb)
              InkWell(
                key: const Key('settings.checkUpdates'),
                onTap: _checking ? null : _check,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.checkUpdates, style: TextStyle(fontSize: 16, color: p.accent)),
                      ),
                      if (_checking)
                        SizedBox(
                          key: const Key('settings.updateProgress'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.muted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (!kIsWeb && result != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              switch (result) {
                UpToDate() => s.upToDate,
                UpdateAvailable(:final version) => s.updateAvailable(version),
                UpdateFailed() => s.updateFailed,
              },
              key: const Key('settings.updateStatus'),
              style: TextStyle(
                fontSize: 14,
                color: switch (result) {
                  UpToDate() => p.success,
                  UpdateAvailable() => p.text,
                  UpdateFailed() => p.danger,
                },
              ),
            ),
          ),
        if (!kIsWeb && result is UpdateAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('settings.openRelease'),
                onPressed: () => ref.read(callKeeperProvider).openUrl(result.url),
                child: Text(s.openDownload),
              ),
            ),
          ),
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(s.updateNote, style: TextStyle(fontSize: 13, color: p.muted, height: 1.4)),
          ),
      ],
    );
  }
}
