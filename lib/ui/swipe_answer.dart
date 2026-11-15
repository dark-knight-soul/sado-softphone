import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sado_style.dart';

/// Ответ на входящий свайпом по вертикали: ручку тянут вверх, чтобы ответить,
/// и вниз, чтобы отклонить.
class VerticalSwipeAnswer extends StatefulWidget {
  const VerticalSwipeAnswer({
    super.key,
    required this.palette,
    required this.icon,
    required this.declineIcon,
    required this.acceptHint,
    required this.declineHint,
    required this.acceptLabel,
    required this.onAccept,
    required this.onDecline,
    this.travel = 96,
  });

  final CallPalette palette;
  final IconData icon;
  final IconData declineIcon;
  final String acceptHint;
  final String declineHint;

  /// Подпись для программ чтения с экрана: двойное касание по ручке отвечает на звонок.
  final String acceptLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// На сколько можно утянуть ручку в каждую сторону.
  final double travel;

  /// Какую долю пути нужно пройти, чтобы жест засчитался.
  static const threshold = 0.45;

  @override
  State<VerticalSwipeAnswer> createState() => _VerticalSwipeAnswerState();
}

class _VerticalSwipeAnswerState extends State<VerticalSwipeAnswer> with SingleTickerProviderStateMixin {
  // Смещение ручки: -1 — до упора вверх (ответить), +1 — до упора вниз (отклонить).
  double _offset = 0;
  bool _dragging = false;
  bool _done = false;

  // Лёгкое покачивание ручки подсказывает, что её нужно тянуть.
  late final AnimationController _hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Если в телефоне отключены анимации — не качаем.
    if (MediaQuery.of(context).disableAnimations) {
      _hint.stop();
    } else if (!_hint.isAnimating && !_dragging && !_done) {
      _hint.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    if (_done) return;
    setState(() => _offset = (_offset + d.delta.dy / widget.travel).clamp(-1.0, 1.0));
  }

  void _end(DragEndDetails d) {
    if (_done) return;
    // Быстрый взмах засчитываем, даже если путь пройден не до конца.
    final flung = (d.primaryVelocity ?? 0).abs() > 900;
    final enough = _offset.abs() >= VerticalSwipeAnswer.threshold || (flung && _offset.abs() > 0.2);
    if (enough) {
      _done = true;
      HapticFeedback.mediumImpact();
      _offset < 0 ? widget.onAccept() : widget.onDecline();
      return;
    }
    setState(() {
      _offset = 0;
      _dragging = false;
    });
    if (!MediaQuery.of(context).disableAnimations) _hint.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final t = _offset.abs();
    final color = _offset < 0 ? Color.lerp(c.surface, c.go, t)! : Color.lerp(c.surface, c.hangup, t)!;
    final onColor = _offset < 0 ? Color.lerp(c.text, c.onGo, t)! : Color.lerp(c.text, c.onHangup, t)!;
    const size = 76.0;

    // Подсказка той стороны, куда тянут, плавно исчезает — иначе ручка наезжает на её текст.
    final acceptHintOpacity = _offset > 0 ? 0.3 : (1 - t * 2).clamp(0.0, 1.0);
    final declineHintOpacity = _offset < 0 ? 0.3 : (1 - t * 2).clamp(0.0, 1.0);

    // Тянуть можно не только за саму ручку, а в любом месте этой области: в спешке по кружку не попадают.
    return GestureDetector(
      key: const Key('answer.swipe'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _hint.stop();
        setState(() => _dragging = true);
      },
      onVerticalDragUpdate: _update,
      onVerticalDragEnd: _end,
      child: SizedBox(
        width: double.infinity,
        height: widget.travel * 2 + size + 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: acceptHintOpacity,
              child: _Hint(icon: Icons.keyboard_arrow_up, text: widget.acceptHint, color: c.muted),
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _hint,
                  builder: (context, child) {
                    final idle = _dragging || _done ? 0.0 : -8 * Curves.easeInOut.transform(_hint.value);
                    return Transform.translate(offset: Offset(0, _offset * widget.travel + idle), child: child);
                  },
                  child: Semantics(
                    button: true,
                    label: widget.acceptLabel,
                    onTap: widget.onAccept,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Icon(_offset > 0.15 ? widget.declineIcon : widget.icon, color: onColor, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: declineHintOpacity,
              child: _Hint(icon: Icons.keyboard_arrow_down, text: widget.declineHint, color: c.muted, iconBelow: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.color, this.iconBelow = false});

  final IconData icon;
  final String text;
  final Color color;
  final bool iconBelow;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: TextStyle(fontSize: 14, color: color));
    final arrow = Icon(icon, size: 22, color: color);
    return Column(mainAxisSize: MainAxisSize.min, children: iconBelow ? [label, arrow] : [arrow, label]);
  }
}

/// Ответ ползунком: кружок ведут вправо до конца дорожки. Отклонить — отдельной кнопкой под ней.
class SliderAnswer extends StatefulWidget {
  const SliderAnswer({
    super.key,
    required this.palette,
    required this.icon,
    required this.hint,
    required this.acceptLabel,
    required this.declineLabel,
    required this.onAccept,
    required this.onDecline,
    this.knobColor,
    this.knobIconColor,
    this.showDecline = true,
    this.large = false,
  });

  final CallPalette palette;
  final IconData icon;
  final String hint;

  /// Цвет кружка и значка на нём; по умолчанию — зелёный кружок со светлой трубкой.
  final Color? knobColor;
  final Color? knobIconColor;

  /// Показывать ли под дорожкой кнопку «Отклонить» (в «Купертино» она стоит отдельно, над дорожкой).
  final bool showDecline;

  /// Крупная «стеклянная» дорожка, в духе iOS: выше, с тонкой светлой рамкой и подписью строго по центру.
  final bool large;
  final String acceptLabel;
  final String declineLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  static const threshold = 0.85;

  @override
  State<SliderAnswer> createState() => _SliderAnswerState();
}

class _SliderAnswerState extends State<SliderAnswer> {
  // Положение кружка: 0 — слева, 1 — справа до упора.
  double _value = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final height = widget.large ? 84.0 : 68.0;
    final thumb = widget.large ? 72.0 : 58.0;
    final pad = (height - thumb) / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: LayoutBuilder(
            builder: (context, box) {
              final run = box.maxWidth - thumb - pad * 2;
              return Container(
                height: height,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: widget.large ? Border.all(color: c.text.withValues(alpha: 0.22)) : null,
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: (1 - _value * 1.6).clamp(0.0, 1.0),
                        child: Padding(
                          // Обычно подпись стоит правее кружка; в стиле «Купертино» — по центру оставшегося места.
                          padding: EdgeInsets.only(
                            left: thumb + (widget.large ? pad : 0),
                            right: widget.large ? 14 : 0,
                          ),
                          child: Text(
                            widget.hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: widget.large ? 17 : 16,
                              color: widget.large ? c.text.withValues(alpha: 0.86) : c.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pad + run * _value,
                      child: Semantics(
                        button: true,
                        label: widget.acceptLabel,
                        onTap: widget.onAccept,
                        child: GestureDetector(
                          key: const Key('answer.slider'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (d) {
                            if (_done || run <= 0) return;
                            setState(() => _value = (_value + d.delta.dx / run).clamp(0.0, 1.0));
                          },
                          onHorizontalDragEnd: (_) {
                            if (_done) return;
                            if (_value >= SliderAnswer.threshold) {
                              _done = true;
                              HapticFeedback.mediumImpact();
                              widget.onAccept();
                            } else {
                              setState(() => _value = 0);
                            }
                          },
                          child: Container(
                            width: thumb,
                            height: thumb,
                            decoration: BoxDecoration(color: widget.knobColor ?? c.go, shape: BoxShape.circle),
                            child: Icon(
                              widget.icon,
                              color: widget.knobIconColor ?? c.onGo,
                              size: widget.large ? 32 : 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.showDecline) ...[
          const SizedBox(height: 14),
          TextButton(
            key: const Key('call.decline'),
            onPressed: widget.onDecline,
            style: TextButton.styleFrom(foregroundColor: c.hangup == c.go ? c.text : c.hangup),
            child: Text(widget.declineLabel, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ],
    );
  }
}
