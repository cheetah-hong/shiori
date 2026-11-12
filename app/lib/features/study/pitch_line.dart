import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// What the pitch line draws: the reading's morae and the accent (null when
/// not known yet), and whether the accent is the engine's guess.
final class PitchInfo {
  const PitchInfo({
    required this.morae,
    required this.accent,
    required this.estimated,
  });

  final List<String> morae;
  final int? accent;
  final bool estimated;

  /// High/low per mora plus a particle slot; null without an accent.
  List<bool>? get highs => switch (accent) {
    final int a when morae.isNotEmpty && a >= 0 && a <= morae.length =>
      pitchPattern(morae: morae.length, accent: a),
    _ => null,
  };

  PitchInfo withAccent(int? accent) =>
      PitchInfo(morae: morae, accent: accent, estimated: estimated);
}

/// Width of one mora on the line.
const _moraWidth = 22.0;
const _lineHeight = 22.0;

/// The reading's pitch drawn as a line over its morae (a dotted step for the
/// particle after the word); 「추정」 when the accent is guessed.
class PitchLine extends StatelessWidget {
  const PitchLine({super.key, required this.info});

  final PitchInfo info;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final highs = info.highs;
    final label = [
      '음 높이',
      // Each mora with its pitch: 「は 낮음 な 높음」.
      if (highs != null)
        [
          for (final (i, h) in highs.take(info.morae.length).indexed)
            '${info.morae[i]} ${h ? '높음' : '낮음'}',
        ].join(' '),
      if (info.estimated) '추정',
    ].join(', ');
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (highs != null)
              CustomPaint(
                size: Size(_moraWidth * highs.length, _lineHeight),
                painter: _PitchPainter(
                  highs,
                  line: t.accent,
                  particle: t.text3,
                ),
              ),
            if (info.estimated) ...[
              if (highs != null) const SizedBox(width: Space.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.surfaceStrong,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(
                  '추정',
                  style: TextStyle(
                    color: t.text3,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.highs, {required this.line, required this.particle});

  final List<bool> highs;
  final Color line;
  final Color particle;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = line;
    final faint = Paint()
      ..color = particle
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Offset at(int i) =>
        Offset(_moraWidth * i + _moraWidth / 2, highs[i] ? 4 : size.height - 4);
    final last = highs.length - 1;
    for (var i = 0; i < last; i++) {
      // The step into the particle slot is lighter: the particle is not
      // part of the word.
      canvas.drawLine(at(i), at(i + 1), i + 1 == last ? faint : solid);
    }
    for (var i = 0; i < last; i++) {
      canvas.drawCircle(at(i), 3, dot);
    }
    canvas.drawCircle(at(last), 3, faint);
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.highs != highs || old.line != line || old.particle != particle;
}
