import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/widgets.dart';

/// A button of the bottom bar: what it says, its icon, what it does.
@immutable
final class BarAction {
  const BarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Null: shown off.
  final VoidCallback? onPressed;
}

/// A screen's main action in thumb reach, fixed at the bottom over a
/// hairline: the [primary] (filled accent) on the right and a [secondary]
/// (accent wash) on the left; stacked, primary first, at large text sizes.
/// A secondary alone takes the primary's shape. [top] sits above them (a
/// hint, a page indicator).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, this.secondary, this.primary, this.top});

  final BarAction? secondary;

  /// Usually a [BarPrimaryButton]; a plain message when there is nothing
  /// to press.
  final Widget? primary;

  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = _content(context);
    final head = top;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            _barInset,
            Space.gutter,
            _barInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?head,
              if (head != null && content != null)
                const SizedBox(height: Space.sm),
              ?content,
            ],
          ),
        ),
      ),
    );
  }

  Widget? _content(BuildContext context) {
    final s = secondary;
    final p = primary;
    if (s == null) return p;
    if (p == null) {
      return BarPrimaryButton(
        label: s.label,
        icon: s.icon,
        onPressed: s.onPressed,
      );
    }
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          p,
          const SizedBox(height: Space.sm),
          _SecondaryButton(action: s, wide: true),
        ],
      );
    }
    return Row(
      children: [
        _SecondaryButton(action: s, wide: false),
        const SizedBox(width: _barGap),
        Expanded(child: p),
      ],
    );
  }
}

const double _barInset = 10;
const double _barGap = 10;
const double _barButtonHeight = 54;
const double _secondaryWidth = 112;

final _barShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(Radii.button),
);

/// The bar's main button: filled accent, 54 pt, the label centered.
class BarPrimaryButton extends StatelessWidget {
  const BarPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(_barButtonHeight),
      shape: _barShape,
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
    final text = Text(label, textAlign: TextAlign.center);
    final glyph = icon;
    return PressScale(
      enabled: onPressed != null,
      child: glyph == null
          ? FilledButton(onPressed: onPressed, style: style, child: text)
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(glyph),
              label: text,
            ),
    );
  }
}

/// The accent-wash button beside the main one: its icon over the words
/// in a narrow slot, before them when it has the width.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.action, required this.wide});

  final BarAction action;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = Icon(action.icon, size: 22);
    final label = Text(action.label, textAlign: TextAlign.center);
    return FilledButton(
      onPressed: action.onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: t.accentTint,
        foregroundColor: t.accentText,
        minimumSize: const Size(_secondaryWidth, _barButtonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xs,
        ),
        shape: _barShape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: wide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: Space.sm),
                Flexible(child: label),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [icon, const SizedBox(height: 2), label],
            ),
    );
  }
}
