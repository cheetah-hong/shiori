import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// A list row on the page itself: at least 56 pt, ruled under with a
/// hairline, no box around it. Pressable when [onTap] is given.
class RuledRow extends StatelessWidget {
  const RuledRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: Space.sm),
    this.ruleAbove = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Also a hairline on top (the first row under a heading).
  final bool ruleAbove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rule = BorderSide(color: t.line);
    final row = Container(
      constraints: const BoxConstraints(minHeight: ruledRowHeight),
      padding: padding,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        border: Border(top: ruleAbove ? rule : BorderSide.none, bottom: rule),
      ),
      child: child,
    );
    final tap = onTap;
    if (tap == null) return row;
    return InkWell(onTap: tap, child: row);
  }
}

/// The height of a list row.
const double ruledRowHeight = 56;
