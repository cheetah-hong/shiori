import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';

/// One choice of an [showChoices] sheet.
@immutable
final class SheetChoice<T> {
  const SheetChoice({
    required this.label,
    required this.value,
    this.detail,
    this.selected = false,
    this.destructive = false,
  });

  final String label;
  final T value;

  /// A short line under the label (why it cannot be used now, say).
  final String? detail;

  /// The one in use: a check after it.
  final bool selected;

  /// Deletes or cannot be undone: in the risk color.
  final bool destructive;
}

/// An iOS action sheet of [choices] from the bottom, full width, with 취소;
/// the picked value, or null.
Future<T?> showChoices<T>(
  BuildContext context, {
  String? title,
  required List<SheetChoice<T>> choices,
}) => showCupertinoModalPopup<T>(
  context: context,
  builder: (sheet) => CupertinoActionSheet(
    title: title == null
        ? null
        : Text(title, style: _style(sheet, small: true)),
    actions: [
      for (final c in choices)
        CupertinoActionSheetAction(
          isDestructiveAction: c.destructive,
          onPressed: () => Navigator.of(sheet).pop(c.value),
          child: _ChoiceBody(choice: c),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      isDefaultAction: true,
      onPressed: () => Navigator.of(sheet).pop(),
      child: Text('취소', style: _style(sheet, strong: true)),
    ),
  ),
);

TextStyle _style(
  BuildContext context, {
  Color? color,
  bool small = false,
  bool strong = false,
}) {
  final t = context.tokens;
  return TextStyle(
    fontFamily: context.text.bodyMedium?.fontFamily,
    fontFamilyFallback: context.text.bodyMedium?.fontFamilyFallback,
    fontSize: small ? TypeScale.small : TypeScale.body,
    fontWeight: strong ? Weights.emphasis : Weights.text,
    color: color ?? (small ? t.text3 : t.accentText),
  );
}

class _ChoiceBody<T> extends StatelessWidget {
  const _ChoiceBody({required this.choice});

  final SheetChoice<T> choice;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final detail = choice.detail;
    final color = choice.destructive
        ? t.risk
        : detail != null
        ? t.text3
        : t.accentText;
    return Semantics(
      selected: choice.selected,
      hint: detail,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: choice.label),
                if (choice.selected)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.sm),
                      child: Icon(
                        CupertinoIcons.checkmark,
                        size: 18,
                        color: t.accentText,
                      ),
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
            style: _style(context, color: color, strong: choice.selected),
          ),
          if (detail != null)
            ExcludeSemantics(
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: _style(context, small: true),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 「···」 button of a row or a screen: opens [choices] as an action
/// sheet and hands the pick to [onSelected].
class MoreButton<T> extends StatelessWidget {
  const MoreButton({
    super.key,
    required this.tooltip,
    required this.choices,
    required this.onSelected,
    this.color,
  });

  final String tooltip;
  final List<SheetChoice<T>> Function() choices;
  final Future<void> Function(T value) onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    color: color,
    icon: const Icon(CupertinoIcons.ellipsis),
    onPressed: () async {
      final picked = await showChoices<T>(context, choices: choices());
      if (picked != null) await onSelected(picked);
    },
  );
}
