import 'package:flutter/material.dart';
import 'package:shiori/app/fonts.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/widgets.dart';

/// A button of the bottom bar: what it says and what it does.
@immutable
final class BarAction {
  const BarAction({required this.label, required this.onPressed});

  final String label;

  /// Null: shown off.
  final VoidCallback? onPressed;
}

/// A screen's main action in thumb reach, fixed at the bottom over a
/// hairline: the [primary] (filled accent) on the right and a [secondary]
/// (accent wash) on the left, words only. At large text sizes the bar's
/// text stops growing at [TextCaps.chrome] (iOS bars do the same) and the
/// two share the width, so the bar stays a strip and the page keeps the
/// screen. A secondary alone takes the primary's shape. [top] sits above
/// them (a hint, a page indicator).
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
        child: CappedText(
          max: TextCaps.chrome,
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
      ),
    );
  }

  Widget? _content(BuildContext context) {
    final s = secondary;
    final p = primary;
    if (s == null) return p;
    if (p == null) {
      return BarPrimaryButton(label: s.label, onPressed: s.onPressed);
    }
    // Both buttons as tall as the taller one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLargeText(context))
            Expanded(flex: 2, child: _SecondaryButton(action: s))
          else
            _SecondaryButton(action: s),
          const SizedBox(width: _barGap),
          Expanded(flex: 3, child: p),
        ],
      ),
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

/// The bar's main button: words only, filled accent.
class BarPrimaryButton extends StatelessWidget {
  const BarPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(_barButtonHeight),
      shape: _barShape,
      textStyle: const TextStyle(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: TypeScale.body,
        fontWeight: Weights.emphasis,
      ),
    );
    return PressScale(
      enabled: onPressed != null,
      child: FilledButton(
        onPressed: onPressed,
        style: style,
        child: KeepWordsText(label, textAlign: TextAlign.center),
      ),
    );
  }
}

ButtonStyle _secondaryStyle(BuildContext context, Size minimumSize) {
  final t = context.tokens;
  return FilledButton.styleFrom(
    backgroundColor: t.accentTint,
    foregroundColor: t.accentText,
    minimumSize: minimumSize,
    padding: const EdgeInsets.symmetric(
      horizontal: Space.md,
      vertical: Space.xs,
    ),
    shape: _barShape,
    textStyle: const TextStyle(
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: TypeScale.body2,
      fontWeight: Weights.emphasis,
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.action});

  final BarAction action;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: action.onPressed,
    style: _secondaryStyle(
      context,
      const Size(_secondaryWidth, _barButtonHeight),
    ),
    child: KeepWordsText(action.label, textAlign: TextAlign.center),
  );
}
