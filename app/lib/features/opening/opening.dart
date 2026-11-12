import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/opening/opening_painter.dart';
import 'package:shiori/features/opening/opening_timeline.dart';

/// Share of the screen width the opening drawing takes.
const _drawingWidth = 0.72;

/// Peak flash strength: bright on the light ground, softer on the dark one.
const _flashLight = 0.85;
const _flashDark = 0.45;

/// The cold-start opening: a page, the camera corners closing with a flash,
/// then the し stroke — drawn over [child] and lifted off within
/// [openingLength]. [child] is built underneath from the first frame, so the
/// opening never holds up 홈. A tap ends it at once; reduced motion leaves it
/// out; once over it does not come back for this app instance.
class Opening extends StatefulWidget {
  const Opening({super.key, required this.child});

  final Widget child;

  @override
  State<Opening> createState() => _OpeningState();
}

class _OpeningState extends State<Opening> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: openingLength,
  )..addListener(_onTick);
  bool _isOver = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isOver || _progress.isAnimating) return;
    if (Motion.reduced(context)) {
      _isOver = true;
    } else {
      _progress.forward();
    }
  }

  // Ends on the last frame itself: the controller only reports `completed`
  // on a tick after its full length, which would hold the layer a frame long.
  void _onTick() {
    if (_progress.value >= 1) _end();
  }

  void _end() {
    if (_isOver) return;
    _progress.stop();
    setState(() => _isOver = true);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_isOver)
          ExcludeSemantics(
            key: const ValueKey('opening'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _end,
              child: _OpeningLayer(progress: _progress),
            ),
          ),
      ],
    );
  }
}

class _OpeningLayer extends StatelessWidget {
  const _OpeningLayer({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flashPeak = isDark ? _flashDark : _flashLight;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, drawing) => Opacity(
        opacity: track(layerOpacity, progress.value),
        child: Transform.scale(
          scale: track(layerScale, progress.value),
          child: ColoredBox(
            color: t.bg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                drawing!,
                Opacity(
                  opacity: track(flashOpacity, progress.value) * flashPeak,
                  // A camera flash: light on either ground (the dark one
                  // flashes the light text tone, softer).
                  child: ColoredBox(color: isDark ? t.text : t.bg),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: _drawingWidth,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: OpeningPainter(progress: progress, tokens: t),
            ),
          ),
        ),
      ),
    );
  }
}
