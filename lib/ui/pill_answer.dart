import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sado_style.dart';

/// Ответ свайпом в стороны: широкая белая ручка стоит в середине «пилюли»,
/// вправо — ответить, влево — отклонить.
class PillSwipeAnswer extends StatefulWidget {
  const PillSwipeAnswer({
    super.key,
    required this.palette,
    required this.acceptIcon,
    required this.declineIcon,
    required this.acceptLabel,
    required this.declineLabel,
    required this.onAccept,
    required this.onDecline,
  });

  final CallPalette palette;
  final IconData acceptIcon;
  final IconData declineIcon;
  final String acceptLabel;
  final String declineLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Какую долю пути от середины до края нужно пройти, чтобы жест засчитался.
  static const threshold = 0.6;

  @override
  State<PillSwipeAnswer> createState() => _PillSwipeAnswerState();
}

class _PillSwipeAnswerState extends State<PillSwipeAnswer> {
  // Положение ручки: -1 — у левого края (отклонить), +1 — у правого (ответить).
  double _value = 0;
  bool _done = false;

  void _end(DragEndDetails d) {
    if (_done) return;
    final flung = (d.primaryVelocity ?? 0).abs() > 900;
    if (_value.abs() >= PillSwipeAnswer.threshold || (flung && _value.abs() > 0.2)) {
      _done = true;
      HapticFeedback.mediumImpact();
      _value > 0 ? widget.onAccept() : widget.onDecline();
      return;
    }
    setState(() => _value = 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    // Один вид во всех стилях: высокая дорожка, ручка — широкая белая «таблетка»
    // с зелёной трубкой, по краям — слова без значков.
    // Дорожка 96 высотой, ручка 96×72.
    const height = 96.0;
    const handleWidth = 96.0;
    const handleHeight = 72.0;
    const edge = (height - handleHeight) / 2;
    final t = _value.abs();
    const rest = Colors.white;
    // Если «зелёный» в стиле сам почти белый (как у «Заката»), трубку рисуем цветом фона, иначе её не видно.
    final restIcon = c.go.computeLuminance() > 0.7 ? c.bg : c.go;
    final handleColor = _value >= 0 ? Color.lerp(rest, c.go, t)! : Color.lerp(rest, c.hangup, t)!;
    final handleIconColor = _value >= 0 ? Color.lerp(restIcon, c.onGo, t)! : Color.lerp(restIcon, c.onHangup, t)!;
    // Дорожка — цвет «листа», если он в стиле есть и отличается от фона, иначе цвет клавиш.
    final sheet = c.sheet;
    final baseTrack = sheet != null && sheet != c.bg ? sheet : c.surface;
    // Дорожка слегка окрашивается в сторону движения: зелёным — «ответить», красным — «отклонить».
    final track = Color.lerp(baseTrack, _value >= 0 ? c.go : c.hangup, t * 0.28)!;

    // Слово у края дорожки; противоположное направлению движения бледнеет.
    Widget end({required bool accept}) {
      final faded = accept ? _value < 0 : _value > 0;
      return Expanded(
        child: Opacity(
          opacity: faded ? 0.25 : 1,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                accept ? widget.acceptLabel : widget.declineLabel,
                maxLines: 1,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text),
              ),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: LayoutBuilder(
        builder: (context, box) {
          final run = (box.maxWidth - handleWidth) / 2 - edge;
          // Тянуть можно в любом месте «пилюли», не только за ручку.
          return GestureDetector(
            key: const Key('answer.pill'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              if (_done || run <= 0) return;
              setState(() => _value = (_value + d.delta.dx / run).clamp(-1.0, 1.0));
            },
            onHorizontalDragEnd: _end,
            child: Container(
              height: height,
              decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height / 2)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Подсказки по краям: слева «отклонить», справа «ответить». Посередине — место под ручку.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        end(accept: false),
                        const SizedBox(width: handleWidth + 8),
                        end(accept: true),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(run * _value, 0),
                    child: Semantics(
                      button: true,
                      label: widget.acceptLabel,
                      onTap: widget.onAccept,
                      child: Container(
                        width: handleWidth,
                        height: handleHeight,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(handleHeight / 2),
                          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Icon(
                          _value < -0.15 ? widget.declineIcon : widget.acceptIcon,
                          color: handleIconColor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
