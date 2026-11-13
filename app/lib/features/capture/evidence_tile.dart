import 'package:flutter/cupertino.dart';
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
      opacity: e.included ? 1 : 0.6,
      duration: Motion.of(context, Motion.ui),
      // A ruled row on the page; its state is said in words at the top,
      // not by a colored edge.
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
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
                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: Space.sm,
                              runSpacing: Space.xs,
                              children: [
                                if (fromSentence)
                                  _StateText('문장에서', color: t.text2)
                                else
                                  const SizedBox.shrink(),
                                // A flag beats an earlier approval.
                                if (e.needsReview)
                                  _StateText('확인 필요', color: t.warn, dot: true)
                                else if (confirmed)
                                  _StateText('확인됨', color: t.ok),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '고치기',
                            icon: Icon(
                              CupertinoIcons.pencil,
                              size: 18,
                              color: t.text3,
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
                                CupertinoIcons.checkmark_circle,
                                size: 16,
                                color: t.text2,
                              ),
                              const SizedBox(width: Space.xs),
                              Flexible(
                                child: Text(
                                  inLibraryLabel,
                                  style: context.text.bodySmall?.copyWith(
                                    color: t.text2,
                                    fontWeight: FontWeight.w600,
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
                            : JpText(
                                e.headword,
                                style: JpType.headword(
                                  TypeScale.display,
                                  t.text,
                                ),
                              ),
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
                              : JpText(
                                  e.readings.join(' / '),
                                  style: JpType.body(
                                    TypeScale.body2,
                                    t.text2,
                                    height: 1.3,
                                  ),
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
                        JpText(
                          ex.ja,
                          style: JpType.body(
                            TypeScale.small,
                            t.text2,
                            height: 1.5,
                          ),
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
        // 44 pt to press, however short the value.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _cellTarget,
            minWidth: _cellTarget,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
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
        ),
      ),
    );
  }
}

/// 사진 / 사전 / 번역: where a cell's value came from. A value read from the
/// photo is the usual case and shows nothing (VoiceOver still hears it);
/// a dictionary or translation value is named in small words.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, required this.field});

  final FieldSource source;
  final EntryField field;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      label: '${fieldLabel(field)} 출처 ${source.label}',
      excludeSemantics: true,
      child: source == FieldSource.photo
          ? const SizedBox(width: 1, height: 1)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                source.label,
                style: TextStyle(color: t.text2, fontSize: TypeScale.caption),
              ),
            ),
    );
  }
}

/// 높음 / 중간 / 낮음: how sure a cell's pairing with the headword is. 높음
/// needs nothing and shows nothing (VoiceOver still hears it); the two that
/// ask for a look are named in the check color.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.level, required this.field});

  final PairConfidence level;
  final EntryField field;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      label: '${fieldLabel(field)} 짝 신뢰도 ${level.label}',
      excludeSemantics: true,
      child: level == PairConfidence.high
          ? const SizedBox(width: 1, height: 1)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                level.label,
                style: TextStyle(
                  color: t.warn,
                  fontSize: TypeScale.caption,
                  fontWeight: Weights.emphasis,
                ),
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
              backgroundColor: t.bg,
              side: BorderSide(color: t.outline),
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
        color: t.warnBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.warn,
          fontWeight: FontWeight.w600,
          fontSize: TypeScale.small,
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
                  color: included ? t.accent : Colors.transparent,
                  border: Border.all(
                    color: included ? t.accent : t.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: included
                    ? Icon(
                        CupertinoIcons.checkmark,
                        size: 16,
                        color: t.onAccent,
                      )
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
    final (label, fg) = switch (status) {
      FieldStatus.suspect => ('의심', t.warn),
      FieldStatus.corrected => ('고침', t.ok),
      // A guess is usually right: grey and light.
      _ => ('추정', t.text3),
    };
    final guess = status == FieldStatus.inferred;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: TypeScale.caption,
          fontWeight: guess ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
    );
  }
}

/// A word's state in small words at the end of its top line (문장에서,
/// 확인 필요, 확인됨), in the color of what it says; [dot] puts a small dot
/// of that color before it (확인 필요, so a long list is quick to scan).
class _StateText extends StatelessWidget {
  const _StateText(this.text, {required this.color, this.dot = false});

  final String text;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final words = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: TypeScale.small,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!dot) return words;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs),
        Flexible(child: words),
      ],
    );
  }
}

const double _dotSize = 6;

/// The least size of a cell to press, in points.
const double _cellTarget = 44;
