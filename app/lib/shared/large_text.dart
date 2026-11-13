import 'package:flutter/widgets.dart';

/// From about the iOS AX1 text size every screen stacks what sits side by
/// side at the default size (bar buttons, reveal buttons, a value beside
/// its label). One threshold for the whole app.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_probe) >= _probe * _largeFactor;

const double _probe = 16;
const double _largeFactor = 1.6;

/// How far text in fixed places grows with the text size. Running text has
/// no cap; bars, sheet and dialog heads stop at [chrome] (as iOS bars do),
/// and the marks already shown large (the day numeral, a card's headword)
/// at [display].
abstract final class TextCaps {
  static const double chrome = 2.0;
  static const double label = 2.0;
  static const double display = 1.4;
}

/// [child] with its text growing at most [max] times.
class CappedText extends StatelessWidget {
  const CappedText({super.key, required this.max, required this.child});

  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: max, child: child);
}
