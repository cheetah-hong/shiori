import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/evidence_view.dart';
import 'package:shiori_core/shiori_core.dart';

/// What the learner does with an unpaired fragment.
sealed class FragmentUse {
  const FragmentUse();
}

/// Put the fragment on [field] of the entry at [index].
final class AttachFragment extends FragmentUse {
  const AttachFragment(this.index, this.field);

  final int index;
  final EntryField field;
}

/// Make a new entry from the fragment.
final class NewEntryFromFragment extends FragmentUse {
  const NewEntryFromFragment();
}

/// 짝 없는 조각: text on the page nothing paired with, for the learner to
/// put on an entry's cell or to make a new entry from.
class FragmentTray extends StatelessWidget {
  const FragmentTray({super.key, required this.fragments, required this.onTap});

  final List<Fragment> fragments;
  final ValueChanged<Fragment> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.paper2,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '짝 없는 조각 ${fragments.length}',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            '사진에서 읽었지만 어느 단어와도 짝짓지 못한 글이에요. 눌러서 단어의 칸에 붙이거나 새 단어로 만들 수 있어요.',
            style: context.text.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final f in fragments)
                ActionChip(
                  key: ValueKey('fragment-${f.id}'),
                  label: Text(
                    f.text,
                    style: f.isJapanese ? JpType.gothic(15, t.ink) : null,
                  ),
                  tooltip: '${f.text} 쓰기',
                  backgroundColor: t.sheet,
                  side: BorderSide(color: t.paper3),
                  onPressed: () => onTap(f),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks where [fragment] goes: a cell of one of [entries], or a new entry.
Future<FragmentUse?> showFragmentSheet(
  BuildContext context, {
  required Fragment fragment,
  required List<CapturedEntry> entries,
}) => showModalBottomSheet<FragmentUse>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FragmentSheet(fragment: fragment, entries: entries),
);

class _FragmentSheet extends StatefulWidget {
  const _FragmentSheet({required this.fragment, required this.entries});

  final Fragment fragment;
  final List<CapturedEntry> entries;

  @override
  State<_FragmentSheet> createState() => _FragmentSheetState();
}

class _FragmentSheetState extends State<_FragmentSheet> {
  late EntryField _field = widget.fragment.isKorean
      ? EntryField.meaning
      : widget.fragment.kind == FragmentKind.kana
      ? EntryField.readings
      : EntryField.headword;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = widget.fragment;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.xl,
        ),
        children: [
          Text('「${f.text}」 쓰기', style: context.text.titleLarge),
          const SizedBox(height: Space.md),
          FilledButton.tonalIcon(
            key: const ValueKey('new-entry-from-fragment'),
            onPressed: () =>
                Navigator.of(context).pop(const NewEntryFromFragment()),
            icon: const Icon(Icons.add),
            label: const Text('새 단어로 만들기'),
          ),
          const SizedBox(height: Space.lg),
          Text('단어의 칸에 붙이기', style: context.text.labelLarge),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final field in [
                EntryField.headword,
                EntryField.readings,
                EntryField.meaning,
              ])
                ChoiceChip(
                  key: ValueKey('attach-field-${field.name}'),
                  label: Text(fieldLabel(field)),
                  selected: _field == field,
                  onSelected: (_) => setState(() => _field = field),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (final (i, e) in widget.entries.indexed)
            ListTile(
              key: ValueKey('attach-entry-$i'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                e.headword.isEmpty ? '(표제어 없음)' : e.headword,
                style: JpType.gothic(16, t.ink),
              ),
              subtitle: Text(
                [
                  if (e.readings.isNotEmpty) e.readings.join('/'),
                  if (e.meaning.isNotEmpty) e.meaning,
                ].join(' · '),
              ),
              trailing: Text(
                '${fieldLabel(_field)}에 붙이기',
                style: context.text.bodySmall,
              ),
              onTap: () => Navigator.of(context).pop(AttachFragment(i, _field)),
            ),
        ],
      ),
    );
  }
}
