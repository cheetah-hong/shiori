import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// The study screen's body, which tears the last card off once, when the
/// session ends: the card's sheet goes up along its tear line, turning a
/// little and fading, and 오늘 학습 끝 is there under it. Cards in between
/// are not torn (they switch as before), and with reduced motion the end
/// shows at once.
///
/// The session on screen keeps its state while it is torn: the card goes as
/// it was left, its covered parts open or not.
class SessionTear extends StatefulWidget {
  const SessionTear({
    super.key,
    required this.live,
    required this.done,
    required this.child,
    this.onEnd,
  });

  /// Called once when the session on screen gives way to 오늘 학습 끝 (torn
  /// or, with reduced motion, at once): the haptic tap.
  final VoidCallback? onEnd;

  /// [child] is a session with a card on screen.
  final bool live;

  /// [child] is 오늘 학습 끝.
  final bool done;

  final Widget child;

  @override
  State<SessionTear> createState() => _SessionTearState();
}

class _SessionTearState extends State<SessionTear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tear;

  /// The session being torn off, over [SessionTear.child].
  Widget? _torn;

  @override
  void initState() {
    super.initState();
    _tear = AnimationController(vsync: this, duration: _tearDuration)
      ..addStatusListener((status) {
        if (status.isCompleted && mounted) setState(() => _torn = null);
      });
  }

  @override
  void didUpdateWidget(SessionTear old) {
    super.didUpdateWidget(old);
    if (old.live && widget.done) widget.onEnd?.call();
    if (old.live && widget.done && !Motion.reduced(context)) {
      _torn = old.child;
      _tear.forward(from: 0);
    } else if (!widget.done && _torn != null) {
      _tear.stop();
      _torn = null;
    }
  }

  @override
  void dispose() {
    _tear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final torn = _torn;
    // Keyed so the session torn off is the very one that was on screen.
    return Stack(
      fit: StackFit.expand,
      children: [
        _layer(
          key: widget.live ? _liveKey : _otherKey,
          tearing: false,
          child: widget.child,
        ),
        if (torn != null) _layer(key: _liveKey, tearing: true, child: torn),
      ],
    );
  }

  /// The same widgets around a layer whether it is torn or not, so a
  /// session keeps its state when its tear starts.
  Widget _layer({
    required Key key,
    required bool tearing,
    required Widget child,
  }) => KeyedSubtree(
    key: key,
    child: IgnorePointer(
      ignoring: tearing,
      child: ExcludeSemantics(
        excluding: tearing,
        child: _TearScope(tear: tearing ? _tear : null, child: child),
      ),
    ),
  );
}

const Duration _tearDuration = Duration(milliseconds: 450);
const Key _liveKey = ValueKey('session-live');
const Key _otherKey = ValueKey('session-other');

class _TearScope extends InheritedWidget {
  const _TearScope({required this.tear, required super.child});

  /// The tear's progress, 0 to 1; null when this layer is not torn.
  final Animation<double>? tear;

  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TearScope>()?.tear ??
      kAlwaysDismissedAnimation;

  @override
  bool updateShouldNotify(_TearScope old) => old.tear != tear;
}

/// The card's place in a session: torn off when the session ends.
class TearCard extends StatelessWidget {
  const TearCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tear = _TearScope.of(context);
    return AnimatedBuilder(
      animation: tear,
      child: child,
      builder: (context, child) {
        final v = Curves.easeInCubic.transform(tear.value);
        final fade = _fadeLate.transform(tear.value);
        return Opacity(
          opacity: 1 - fade,
          child: FractionalTranslation(
            translation: Offset(0, -_tearRise * v),
            child: Transform.rotate(
              angle: -_tearTurn * v,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// How far the sheet goes up, in its own heights, and how much it turns
/// (radians, lifting its right side) by the end of the tear.
const double _tearRise = 0.6;
const double _tearTurn = 0.07;
const Curve _fadeLate = Interval(0.35, 1, curve: Curves.easeIn);

/// Everything of a session but its card: gone early in the tear, so only
/// the sheet is seen going.
class TearFade extends StatelessWidget {
  const TearFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _TearScope.of(context).drive(
      Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: _fadeEarly)),
    ),
    child: child,
  );
}

const Curve _fadeEarly = Interval(0, 0.3, curve: Curves.easeOut);
