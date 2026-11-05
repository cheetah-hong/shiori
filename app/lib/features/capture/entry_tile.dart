import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// One captured word on the review screen. Cells to check are marked with the
/// red pen; auto-corrected cells get a quiet green note.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggle,
  });

  final CapturedEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = entry;
    final needsReview = e.needsReview;
    final headStatus = e.statusOf(EntryField.headword);
    final corrections = e.issues
        .where((i) => i.kind == IssueKind.corrected)
        .toList();

    return AnimatedOpacity(
      opacity: e.included ? 1 : 0.45,
      duration: Motion.of(context, Motion.ui),
      child: Material(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            // Red-pen margin for entries that need a look.
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: needsReview ? t.risk : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IncludeBox(
                  included: e.included,
                  onChanged: onToggle,
                  label: e.headword.isEmpty ? '번호 ${e.no}' : e.headword,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      Space.md,
                      Space.lg,
                      Space.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              e.no ?? '----',
                              style: context.text.labelMedium?.copyWith(
                                color: t.ink3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (e.important) ...[
                              const SizedBox(width: 6),
                              Semantics(
                                label: '기출 중요 단어',
                                child: Text(
                                  '★',
                                  style: TextStyle(color: t.pen, fontSize: 13),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (needsReview)
                              Pill(
                                '확인 필요',
                                background: t.riskBg,
                                foreground: t.risk,
                              )
                            else if (corrections.isNotEmpty)
                              Tooltip(
                                message: corrections
                                    .map((c) => c.note ?? '')
                                    .join('\n'),
                                child: Pill(
                                  '자동 보정 ${corrections.first.note ?? ''}',
                                  background: t.okBg,
                                  foreground: t.ok,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.xs),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: Space.md,
                          runSpacing: Space.xs,
                          children: [
                            if (headStatus == FieldStatus.needsReview)
                              _MissingCell(text: '표제어 없음 · 눌러서 입력', large: true)
                            else
                              Text(e.headword, style: JpType.print(26, t.ink)),
                            if (e.statusOf(EntryField.readings) ==
                                FieldStatus.needsReview)
                              const _MissingCell(text: '읽기 없음')
                            else
                              Text(
                                readingsLabel(e.readings),
                                style: JpType.gothic(14, t.ink3, height: 1.3),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PosBadge(e.pos, missing: e.pos == null),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child:
                                  e.statusOf(EntryField.meaning) ==
                                      FieldStatus.needsReview
                                  ? const _MissingCell(text: '뜻 없음')
                                  : Text(
                                      e.meaning,
                                      style: context.text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (e.example case final ex?) ...[
                          const SizedBox(height: Space.sm),
                          Text(
                            ex.ja,
                            style: JpType.gothic(13, t.ink2, height: 1.5),
                          ),
                          Text(
                            ex.ko,
                            style: context.text.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ] else if (e.statusOf(EntryField.example) ==
                            FieldStatus.needsReview) ...[
                          const SizedBox(height: Space.sm),
                          const _MissingCell(text: '예문 없음'),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingCell extends StatelessWidget {
  const _MissingCell({required this.text, this.large = false});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: large ? 5 : 2),
      decoration: BoxDecoration(
        color: t.marker.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.risk,
          fontWeight: FontWeight.w800,
          fontSize: large ? 15 : 13,
        ),
      ),
    );
  }
}

class _IncludeBox extends StatelessWidget {
  const _IncludeBox({
    required this.included,
    required this.onChanged,
    required this.label,
  });

  final bool included;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      checked: included,
      label: '$label 저장',
      child: InkWell(
        onTap: () => onChanged(!included),
        child: SizedBox(
          width: 52,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.press),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: included ? t.ink : Colors.transparent,
                  border: Border.all(
                    color: included ? t.ink : t.paper3,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: included
                    ? Icon(Icons.check, size: 16, color: t.sheet)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
