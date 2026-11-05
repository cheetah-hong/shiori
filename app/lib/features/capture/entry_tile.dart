import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/shared/format.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// One captured word on the review screen.
///
/// Each flagged cell carries a small mark: the red pen for "사전에 없음" (and
/// the missing-cell highlight), amber "의심" for a cell that looks cut, green
/// "고침" for a fixed cell (or one the learner picked), and a quiet grey
/// "추정" for a guess. The left
/// margin follows the strongest of them; a guess alone leaves it clear.
/// An unread headword offers the dictionary's candidates as chips.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggle,
    this.onPickCandidate,
  });

  final CapturedEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// The learner chose a dictionary candidate for the empty headword.
  final ValueChanged<String>? onPickCandidate;

  Color _margin(ShioriTokens t) {
    final kinds = {for (final i in entry.issues) i.kind};
    if (kinds.contains(IssueKind.missing) ||
        kinds.contains(IssueKind.unverified)) {
      return t.risk;
    }
    if (kinds.contains(IssueKind.suspect)) return t.warn;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = entry;
    final needsReview = e.needsReview;
    final headStatus = e.statusOf(EntryField.headword);
    final picked = e.issues
        .where((i) => i.kind == IssueKind.picked)
        .firstOrNull;
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
              border: Border(left: BorderSide(color: _margin(t), width: 4)),
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
                            const Spacer(),
                            if (needsReview)
                              Pill(
                                '확인 필요',
                                background: t.riskBg,
                                foreground: t.risk,
                              )
                            else if (picked != null || corrections.isNotEmpty)
                              // The learner's pick names the badge; the tooltip
                              // still lists every automatic fix on the entry.
                              Tooltip(
                                message: [
                                  ?picked,
                                  ...corrections,
                                ].map((c) => c.note ?? '').join('\n'),
                                child: Pill(
                                  picked != null
                                      ? picked.note ?? '직접 고름'
                                      : '자동 보정 ${corrections.first.note ?? ''}',
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
                            ?FieldMark.of(e, EntryField.headword),
                            if (e.statusOf(EntryField.readings) ==
                                FieldStatus.needsReview)
                              const _MissingCell(text: '읽기 없음')
                            else
                              Text(
                                readingsLabel(e.readings),
                                style: JpType.gothic(14, t.ink3, height: 1.3),
                              ),
                            ?FieldMark.of(e, EntryField.readings),
                          ],
                        ),
                        if (e.headword.trim().isEmpty &&
                            e.headwordCandidates.isNotEmpty &&
                            onPickCandidate != null)
                          _Candidates(
                            candidates: e.headwordCandidates,
                            onPick: onPickCandidate!,
                          ),
                        const SizedBox(height: Space.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PosBadge(e.pos, missing: e.pos == null),
                            if (FieldMark.of(e, EntryField.pos)
                                case final mark?) ...[
                              const SizedBox(width: Space.xs),
                              mark,
                            ],
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Wrap(
                                spacing: Space.sm,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (e.statusOf(EntryField.meaning) ==
                                      FieldStatus.needsReview)
                                    const _MissingCell(text: '뜻 없음')
                                  else
                                    Text(
                                      e.meaning,
                                      style: context.text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ?FieldMark.of(e, EntryField.meaning),
                                ],
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

/// The mark next to a cell, by its status. None for ok and missing cells
/// (missing ones show [_MissingCell] instead of their text).
class FieldMark extends StatelessWidget {
  const FieldMark._({super.key, required this.status});

  static FieldMark? of(CapturedEntry entry, EntryField field) {
    final status = entry.statusOf(field);
    if (status == FieldStatus.ok || status == FieldStatus.needsReview) {
      return null;
    }
    return FieldMark._(
      key: ValueKey('mark-${field.name}-${status.name}'),
      status: status,
    );
  }

  final FieldStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, fg, bg) = switch (status) {
      FieldStatus.unverified => ('사전에 없음', t.risk, t.riskBg),
      FieldStatus.suspect => ('의심', t.warn, t.warnBg),
      FieldStatus.corrected => ('고침', t.ok, t.okBg),
      // A guess is usually right: grey text, no fill.
      _ => ('추정', t.ink3, Colors.transparent),
    };
    final guess = status == FieldStatus.inferred;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: guess ? Border.all(color: t.paper3) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: guess ? FontWeight.w500 : FontWeight.w800,
        ),
      ),
    );
  }
}

/// Dictionary words for an unread headword; a tap fills it in.
class _Candidates extends StatelessWidget {
  const _Candidates({required this.candidates, required this.onPick});

  final List<String> candidates;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('사전 후보', style: context.text.bodySmall),
          for (final c in candidates)
            ActionChip(
              label: Text(c, style: JpType.print(17, t.ink)),
              tooltip: '표제어를 $c(으)로',
              backgroundColor: t.paper,
              side: BorderSide(color: t.paper3),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: () => onPick(c),
            ),
        ],
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
