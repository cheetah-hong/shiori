import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/evidence_view.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// The mark on an entry whose word is in the library already.
const String inLibraryLabel = '이미 라이브러리에 있음 · 저장된 뜻 유지';

/// One word on the review screen.
///
/// Every cell names where it came from (사진 / 사전 / 번역) and, for the
/// reading and the meaning, how sure the pairing with the headword is in
/// three steps (높음 / 중간 / 낮음, in words and colour, read out to screen
/// readers). Tapping a cell opens the piece of the page it came from; cells
/// below high offer their candidates as chips (a headword OCR lost, its
/// dictionary spellings). A word from a sentence shows
/// the sentence and its translation.
class EvidenceEntryTile extends StatelessWidget {
  const EvidenceEntryTile({
    super.key,
    required this.index,
    required this.entry,
    required this.onEdit,
    required this.onToggle,
    required this.onShowEvidence,
    required this.onPickCandidate,
    this.inLibrary = false,
  });

  /// The word is in the learner's library already: adding it links the
  /// stored word, whose meaning and readings stay as they are.
  final bool inLibrary;

  /// Position on the review screen (in the keys tests and tools find).
  final int index;
  final CapturedEntry entry;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final ValueChanged<EntryField> onShowEvidence;
  final void Function(EntryField field, String value) onPickCandidate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = entry;
    final evidence = e.evidence;
    final confirmed = evidence?.confirmed ?? false;
    final fromSentence = evidence?.origin == WordOrigin.sentence;
    return AnimatedOpacity(
      key: ValueKey('entry-$index'),
      opacity: e.included ? 1 : 0.45,
      duration: Motion.of(context, Motion.ui),
      child: Material(
        color: t.sheet,
        borderRadius: BorderRadius.circular(Radii.tile),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: e.needsReview
                    ? t.risk
                    : confirmed
                    ? t.ok
                    : Colors.transparent,
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
                label: e.headword.isEmpty ? '표제어 없는 단어' : e.headword,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    Space.sm,
                    Space.xs,
                    Space.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (fromSentence)
                            Pill(
                              '문장에서',
                              background: t.paper2,
                              foreground: t.ink2,
                            ),
                          const Spacer(),
                          // A flag beats an earlier approval.
                          if (e.needsReview)
                            Pill(
                              '확인 필요',
                              background: t.riskBg,
                              foreground: t.risk,
                            )
                          else if (confirmed)
                            Pill('확인됨', background: t.okBg, foreground: t.ok),
                          IconButton(
                            tooltip: '고치기',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: t.ink3,
                            ),
                            onPressed: onEdit,
                          ),
                        ],
                      ),
                      if (inLibrary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.xs),
                          child: Row(
                            children: [
                              Icon(
                                Icons.library_add_check_outlined,
                                size: 16,
                                color: t.ink2,
                              ),
                              const SizedBox(width: Space.xs),
                              Flexible(
                                child: Text(
                                  inLibraryLabel,
                                  style: context.text.bodySmall?.copyWith(
                                    color: t.ink2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _Cell(
                        index: index,
                        entry: e,
                        field: EntryField.headword,
                        onTap: onShowEvidence,
                        child: e.headword.isEmpty
                            ? const _Missing('표제어 없음')
                            : Text(e.headword, style: JpType.print(24, t.ink)),
                      ),
                      _Candidates(
                        index: index,
                        entry: e,
                        field: EntryField.headword,
                        onPick: onPickCandidate,
                      ),
                      if (e.readings.isNotEmpty ||
                          e.statusOf(EntryField.readings) ==
                              FieldStatus.needsReview)
                        _Cell(
                          index: index,
                          entry: e,
                          field: EntryField.readings,
                          onTap: onShowEvidence,
                          child: e.readings.isEmpty
                              ? const _Missing('읽기 없음')
                              : Text(
                                  e.readings.join(' / '),
                                  style: JpType.gothic(14, t.ink2, height: 1.3),
                                ),
                        ),
                      _Candidates(
                        index: index,
                        entry: e,
                        field: EntryField.readings,
                        onPick: onPickCandidate,
                      ),
                      const SizedBox(height: Space.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: PosBadge(e.pos, missing: e.pos == null),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: _Cell(
                              index: index,
                              entry: e,
                              field: EntryField.meaning,
                              onTap: onShowEvidence,
                              child: e.meaning.trim().isEmpty
                                  ? const _Missing('뜻 없음')
                                  : Text(
                                      e.meaning,
                                      style: context.text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      _Candidates(
                        index: index,
                        entry: e,
                        field: EntryField.meaning,
                        onPick: onPickCandidate,
                      ),
                      if (e.example case final ex?) ...[
                        const SizedBox(height: Space.sm),
                        Text(
                          ex.ja,
                          style: JpType.gothic(13, t.ink2, height: 1.5),
                        ),
                        if (ex.ko.isNotEmpty)
                          Text(
                            ex.ko,
                            style: context.text.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cell: its value, where it came from, how sure its pairing is, and its
/// review mark. Tapping it shows its piece of the page.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.index,
    required this.entry,
    required this.field,
    required this.onTap,
    required this.child,
  });

  final int index;
  final CapturedEntry entry;
  final EntryField field;
  final ValueChanged<EntryField> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cell = entry.evidence?.of(field);
    final name = fieldLabel(field);
    return Semantics(
      button: true,
      hint: '$name 근거 조각 보기',
      child: InkWell(
        key: ValueKey('cell-$index-${field.name}'),
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: () => onTap(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              child,
              if (cell != null)
                SourceBadge(
                  key: ValueKey('source-$index-${field.name}'),
                  source: cell.source,
                  field: field,
                ),
              if (cell?.confidence case final level?)
                ConfidenceChip(
                  key: ValueKey('confidence-$index-${field.name}'),
                  level: level,
                  field: field,
                ),
              ?FieldMark.of(entry, field),
            ],
          ),
        ),
      ),
    );
  }
}

/// 사진 / 사전 / 번역: where a cell's value came from.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, required this.field});

  final FieldSource source;
  final EntryField field;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photo = source == FieldSource.photo;
    return Semantics(
      container: true,
      label: '${fieldLabel(field)} 출처 ${source.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: photo ? Colors.transparent : t.paper2,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: t.paper3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (source) {
                FieldSource.photo => Icons.photo_camera_outlined,
                FieldSource.dictionary => Icons.menu_book_outlined,
                FieldSource.translation => Icons.translate,
              },
              size: 11,
              color: t.ink3,
            ),
            const SizedBox(width: 3),
            Text(
              source.label,
              style: TextStyle(
                color: t.ink2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 높음 / 중간 / 낮음: how sure a cell's pairing with the headword is, in
/// words and colour (green, amber, red), with a label for screen readers.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.level, required this.field});

  final PairConfidence level;
  final EntryField field;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (fg, bg, icon) = switch (level) {
      PairConfidence.high => (t.ok, t.okBg, Icons.check_circle_outline),
      PairConfidence.medium => (t.warn, t.warnBg, Icons.remove_circle_outline),
      PairConfidence.low => (t.risk, t.riskBg, Icons.help_outline),
    };
    return Semantics(
      container: true,
      label: '${fieldLabel(field)} 짝 신뢰도 ${level.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
            Text(
              level.label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Other values for a cell paired below high (dictionary senses, the value a
/// pick replaced); a tap puts one in the cell.
class _Candidates extends StatelessWidget {
  const _Candidates({
    required this.index,
    required this.entry,
    required this.field,
    required this.onPick,
  });

  final int index;
  final CapturedEntry entry;
  final EntryField field;
  final void Function(EntryField field, String value) onPick;

  @override
  Widget build(BuildContext context) {
    final cell = entry.evidence?.of(field);
    if (cell == null ||
        cell.candidates.isEmpty ||
        cell.confidence == PairConfidence.high) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Wrap(
        spacing: Space.xs,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${fieldLabel(field)} 후보', style: context.text.bodySmall),
          for (final c in cell.candidates)
            ActionChip(
              key: ValueKey('candidate-$index-${field.name}-$c'),
              label: Text(c),
              tooltip: '${fieldLabel(field)}을(를) $c(으)로',
              backgroundColor: t.paper,
              side: BorderSide(color: t.paper3),
              visualDensity: VisualDensity.compact,
              onPressed: () => onPick(field, c),
            ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.marker.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.risk,
          fontWeight: FontWeight.w800,
          fontSize: 13,
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
          width: 48,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
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

/// The mark next to a cell, by its status. None for ok and missing cells
/// (missing ones show their placeholder instead of their text).
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
