import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// A page of the tear-off calendar (日めくり): an ink binding strip on top,
/// hairline sides, no corners or shadow, and a dashed tear line under it.
/// At most one per screen; everything else sits on the page as ruled rows.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      _sideInset,
      Space.md,
      _sideInset,
      Space.md,
    ),
    this.fill = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Takes all the height it is given (a study card), the tear line still
  /// at the bottom; [child] then gets a bounded height.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final side = BorderSide(color: t.line);
    final page = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          top: BorderSide(color: t.text, width: _bindingWidth),
          left: side,
          right: side,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fill) Expanded(child: page) else page,
          const TearLine(),
        ],
      ),
    );
  }
}

const double _bindingWidth = 4;
const double _sideInset = 14;

/// A dashed rule to tear along: the bottom edge of a sheet in ink, or, in
/// the hairline color, the end of a list.
class TearLine extends StatelessWidget {
  const TearLine({super.key, this.faint = false});

  /// Hairline color instead of ink (a list's end, not a sheet's edge).
  final bool faint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: _tearWidth,
      child: CustomPaint(painter: _DashPainter(faint ? t.line : t.text)),
    );
  }
}

const double _tearWidth = 1.5;

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      final end = x + _dash < size.width ? x + _dash : size.width;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Memo rows under an ink rule: a sheet's numbers, one per row.
class SheetMemoList extends StatelessWidget {
  const SheetMemoList({super.key, required this.rows});

  /// [SheetMemoRow]s; the last one should be `last: true`.
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.tokens.text)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    ),
  );
}

/// A memo row: the label left, the value right as a bold tabular number
/// with its small unit (「12개」), ruled under. Read as one line.
class SheetMemoRow extends StatelessWidget {
  const SheetMemoRow({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.valueColor,
    this.last = false,
    this.trailing,
  });

  final String label;

  /// The number (or a short measure such as 「3분 20초」).
  final String value;

  /// After the value, small: 「개」, 「번」, 「개 · 13개 중」.
  final String unit;

  /// Ink unless the row reports a problem.
  final Color? valueColor;

  /// No rule under the last row (the tear line or the next part closes it).
  final bool last;

  /// A quiet action after the value (a text button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unitStyle = TextStyle(
      color: t.text2,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                // The value goes under the label when both do not fit.
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.sm,
                  children: [
                    Text(label, style: TextStyle(color: t.text, fontSize: 17)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: TextStyle(
                              color: valueColor ?? t.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          TextSpan(text: unit, style: unitStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
