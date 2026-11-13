import 'package:flutter/cupertino.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/ruled.dart';

/// 전체 n | 확인 필요 n: which words the review list shows. An iOS segmented
/// control; at large text sizes two ruled rows with a check, so neither
/// label is squeezed. 확인 필요 is off while nothing needs a look.
class ReviewFilter extends StatelessWidget {
  const ReviewFilter({
    super.key,
    required this.all,
    required this.flagged,
    required this.onlyFlagged,
    required this.onChanged,
  });

  final int all;
  final int flagged;
  final bool onlyFlagged;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = {false: '전체 $all', true: '확인 필요 $flagged'};
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final MapEntry(key: only, value: label) in labels.entries)
            _FilterRow(
              label: label,
              selected: only == onlyFlagged,
              first: !only,
              onTap: only && flagged == 0 ? null : () => onChanged(only),
            ),
        ],
      );
    }
    final t = context.tokens;
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: onlyFlagged,
      backgroundColor: t.surfaceStrong,
      thumbColor: t.bg,
      disabledChildren: {if (flagged == 0) true},
      onValueChanged: (only) {
        if (only != null) onChanged(only);
      },
      children: {
        for (final MapEntry(key: only, value: label) in labels.entries)
          only: Semantics(
            // The control keeps a tap on a disabled segment; say it is off.
            enabled: !(only && flagged == 0),
            child: _Segment(label: label, selected: only == onlyFlagged),
          ),
      },
    );
  }
}

/// A segment's words, tall enough to press (44 pt).
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: _segmentHeight),
    child: Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.tokens.text,
          fontSize: TypeScale.body2,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

const double _segmentHeight = 44;

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.selected,
    required this.first,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: RuledRow(
        ruleAbove: first,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap == null ? t.text3 : t.text,
                  fontSize: TypeScale.body,
                ),
              ),
            ),
            if (selected) Icon(CupertinoIcons.checkmark, color: t.accentText),
          ],
        ),
      ),
    );
  }
}
