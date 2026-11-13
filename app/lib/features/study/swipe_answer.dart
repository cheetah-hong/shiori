import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// A study card that can be swiped to answer: right 알고있음, left 다시
/// 학습. The buttons stay; this is a shortcut.
///
/// The card follows the finger and tilts a little; past [threshold] of its
/// width (or flung) it leaves that way and the answer is given, short of it
/// it comes back. A drag that starts within [edge] of the screen's left
/// edge is left to the system's back gesture. With reduced motion the card
/// stays still and only the label shows. VoiceOver offers 알고있음 and 다시
/// 학습 as actions on the card.
class SwipeToAnswer extends StatefulWidget {
  const SwipeToAnswer({
    super.key,
    required this.child,
    required this.onAnswer,
    this.enabled = true,
    this.endsSession = false,
    this.onThreshold,
  });

  final Widget child;

  /// Gives the answer; false when it was not stored (the card then comes
  /// back to its place).
  final Future<bool> Function(Answer answer) onAnswer;

  /// False while an answer is being written: drags do nothing.
  final bool enabled;

  /// 알고있음 here ends the session: the card comes back to its place (to
  /// be torn off) instead of leaving.
  final bool endsSession;

  /// Called each time the drag crosses the threshold toward an answer (and
  /// once for a fling that never crossed it): the haptic tap.
  final VoidCallback? onThreshold;

  /// Share of the card's width a drag must pass.
  static const double threshold = 0.3;

  /// A fling: this fast (logical pixels a second) and at least [flingMin].
  static const double flingVelocity = 800;
  static const double flingMin = 48;

  /// Width at the screen's left edge left to the back gesture.
  static const double edge = 24;

  /// Most the card tilts, in degrees, at the threshold and beyond.
  static const double maxTilt = 4;

  static const Duration back = Duration(milliseconds: 220);
  static const Duration away = Duration(milliseconds: 180);
  static const Duration settle = Duration(milliseconds: 160);

  @override
  State<SwipeToAnswer> createState() => _SwipeToAnswerState();
}

class _SwipeToAnswerState extends State<SwipeToAnswer>
    with SingleTickerProviderStateMixin {
  /// How far the drag has gone, in logical pixels (right positive).
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  /// The side whose threshold the drag is past: 1 right, -1 left, 0 none.
  int _past = 0;

  /// An answer is on its way; the card takes no more drags.
  bool _answering = false;

  double _width = 1;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && !_answering;

  double get _threshold => _width * SwipeToAnswer.threshold;

  void _onUpdate(DragUpdateDetails details) {
    if (!_active) return;
    _offset.value += details.delta.dx;
    final past = _offset.value >= _threshold
        ? 1
        : _offset.value <= -_threshold
        ? -1
        : 0;
    if (past != 0 && past != _past) widget.onThreshold?.call();
    _past = past;
  }

  void _onEnd(DragEndDetails details) {
    if (!_active) return;
    final dx = _offset.value;
    final velocity = details.primaryVelocity ?? 0;
    final flung =
        velocity.abs() >= SwipeToAnswer.flingVelocity &&
        dx.abs() >= SwipeToAnswer.flingMin &&
        velocity.sign == dx.sign;
    if (dx.abs() >= _threshold || flung) {
      if (_past == 0) widget.onThreshold?.call();
      _answer(dx > 0 ? Answer.known : Answer.retry);
    } else {
      _comeBack(SwipeToAnswer.back);
    }
  }

  void _onCancel() {
    if (_answering) return;
    _comeBack(SwipeToAnswer.back);
  }

  void _comeBack(Duration duration) {
    _past = 0;
    final length = Motion.of(context, duration);
    if (length == Duration.zero) {
      _offset.value = 0;
      return;
    }
    _offset.animateTo(0, duration: length, curve: Motion.easeOut);
  }

  /// Leaves to the side of [answer] (or comes back when the answer ends the
  /// session, or with reduced motion), then gives the answer.
  Future<void> _answer(Answer answer) async {
    _answering = true;
    final reduced = Motion.reduced(context);
    if (reduced) {
      _offset.value = 0;
    } else if (widget.endsSession && answer == Answer.known) {
      await _offset.animateTo(
        0,
        duration: SwipeToAnswer.settle,
        curve: Motion.easeOut,
      );
    } else {
      final side = answer == Answer.known ? 1 : -1;
      await _offset.animateTo(
        side * (_width + _flyPast),
        duration: SwipeToAnswer.away,
        curve: Curves.easeIn,
      );
    }
    if (!mounted) return;
    _past = 0;
    final stored = await widget.onAnswer(answer);
    if (!mounted) return;
    _answering = false;
    // Stored: the card is on its way out and stays where it went. Not
    // stored: it comes back and takes drags again.
    if (!stored) _offset.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduced = Motion.reduced(context);
    return Semantics(
      container: true,
      customSemanticsActions: widget.enabled
          ? {
              const CustomSemanticsAction(label: '알고있음'): () =>
                  unawaited(widget.onAnswer(Answer.known)),
              const CustomSemanticsAction(label: '다시 학습'): () =>
                  unawaited(widget.onAnswer(Answer.retry)),
            }
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          _width = box.maxWidth.isFinite && box.maxWidth > 0 ? box.maxWidth : 1;
          return RawGestureDetector(
            gestures: {
              _AwayFromEdgeDrag:
                  GestureRecognizerFactoryWithHandlers<_AwayFromEdgeDrag>(
                    _AwayFromEdgeDrag.new,
                    (r) => r
                      // The card moves from where the finger went down.
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onUpdate = _onUpdate
                      ..onEnd = _onEnd
                      ..onCancel = _onCancel,
                  ),
            },
            child: AnimatedBuilder(
              animation: _offset,
              builder: (context, child) {
                final dx = _offset.value;
                final progress = (dx / _threshold).clamp(-1.0, 1.0);
                final turn = reduced
                    ? 0.0
                    : (dx / _width).clamp(-1.0, 1.0) *
                          SwipeToAnswer.maxTilt *
                          math.pi /
                          180;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(
                      offset: Offset(reduced ? 0 : dx, 0),
                      child: Transform.rotate(
                        angle: turn,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                    _Label(
                      text: '알고있음',
                      color: t.accentText,
                      alignment: Alignment.topRight,
                      opacity: progress > 0 ? progress : 0,
                    ),
                    _Label(
                      text: '다시 학습',
                      color: t.text2,
                      alignment: Alignment.topLeft,
                      opacity: progress < 0 ? -progress : 0,
                    ),
                  ],
                );
              },
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// How far past the screen a card that leaves goes.
const double _flyPast = 80;

/// The answer a drag is heading for, at the card's top corner on that side.
/// Shown only while dragging; screen readers use the card's actions.
class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
    required this.alignment,
    required this.opacity,
  });

  final String text;
  final Color color;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Opacity(
                opacity: opacity,
                child: Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: Weights.emphasis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sideways drag that leaves pointers starting near the screen's left
/// edge to the back gesture.
class _AwayFromEdgeDrag extends HorizontalDragGestureRecognizer {
  _AwayFromEdgeDrag() : super();

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx >= SwipeToAnswer.edge && super.isPointerAllowed(event);
}
