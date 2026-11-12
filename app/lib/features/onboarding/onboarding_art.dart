import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// Pictures of the first-run guide, drawn with widgets so they follow the
/// palette and dark mode. Decoration only: the screen keeps them out of
/// VoiceOver, and their few words do not grow with the text size.

/// A page in a camera frame, one line highlighted.
class PageArt extends StatelessWidget {
  const PageArt({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget bar(double width, Color color, {double height = 10}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    );
    return SizedBox(
      width: 200,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: _Corners()),
          Container(
            width: 132,
            height: 168,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: t.bg,
              border: Border.all(color: t.line, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.md,
              children: [
                bar(70, t.text, height: 14),
                bar(50, t.line),
                Container(
                  padding: const EdgeInsets.all(Space.xs),
                  decoration: BoxDecoration(
                    color: t.accentTint,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: t.accent, width: 1.5),
                  ),
                  child: bar(80, t.accent),
                ),
                bar(90, t.line),
                bar(64, t.line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CornerPainter(context.tokens.accent));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 30.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * arm, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * arm),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

/// Three playlists stacked.
class PlaylistArt extends StatelessWidget {
  const PlaylistArt({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: 220,
        child: Column(
          spacing: Space.sm,
          children: [
            for (final (name, count) in [
              ('자연', 32),
              ('여행 표현', 18),
              ('시험 전날', 12),
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(color: t.surface),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 34,
                      decoration: BoxDecoration(
                        color: t.accentTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '단어 $count개',
                          style: TextStyle(color: t.text3, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The four ways of studying above a word card.
class ModesArt extends StatelessWidget {
  const ModesArt({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: 240,
        child: Column(
          spacing: Space.lg,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, name) in [
                  '뜻 맞히기',
                  '일본어 떠올리기',
                  '듣고 맞히기',
                  '객관식',
                ].indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: i == 0 ? t.accentTint : t.bg,
                      borderRadius: BorderRadius.circular(Radii.chip),
                      border: Border.all(color: i == 0 ? t.accent : t.line),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: i == 0 ? t.accentText : t.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            Container(
              width: 150,
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              decoration: BoxDecoration(
                color: t.bg,
                border: Border.all(color: t.line),
              ),
              child: Column(
                children: [
                  Text('花', style: JpType.print(48, t.text)),
                  Text('はな', style: JpType.gothic(13, t.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
