import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori_core/shiori_core.dart';

/// Opens the editor for one captured entry. Returns the edited entry, or null.
Future<CapturedEntry?> showEntryEditor(
  BuildContext context,
  CapturedEntry entry,
) => showModalBottomSheet<CapturedEntry>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => EntryEditorSheet(entry: entry),
);

final RegExp _readingSeparators = RegExp(r'[/／・,，、\s]+');

List<String> parseReadingInput(String text) => [
  for (final part in text.split(_readingSeparators))
    if (part.trim().isNotEmpty) part.trim(),
];

class EntryEditorSheet extends StatefulWidget {
  const EntryEditorSheet({super.key, required this.entry});

  final CapturedEntry entry;

  @override
  State<EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<EntryEditorSheet> {
  late final TextEditingController _headword;
  late final TextEditingController _readings;
  late final TextEditingController _meaning;
  late final TextEditingController _exampleJa;
  late final TextEditingController _exampleKo;
  late PartOfSpeech? _pos;

  CapturedEntry get _e => widget.entry;

  @override
  void initState() {
    super.initState();
    _headword = TextEditingController(text: _e.headword);
    _readings = TextEditingController(text: _e.readings.join(' / '));
    _meaning = TextEditingController(text: _e.meaning);
    _exampleJa = TextEditingController(text: _e.example?.ja ?? '');
    _exampleKo = TextEditingController(text: _e.example?.ko ?? '');
    _pos = _e.pos;
  }

  @override
  void dispose() {
    for (final c in [_headword, _readings, _meaning, _exampleJa, _exampleKo]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pressing 고치기: changed cells lose their flags, and looking at the entry
  /// confirms "의심" on every cell (see [applyLearnerEdits]).
  CapturedEntry _result() {
    final exJa = _exampleJa.text.trim();
    return applyLearnerEdits(
      _e,
      headword: _headword.text.trim(),
      readings: parseReadingInput(_readings.text),
      pos: _pos,
      meaning: _meaning.text.trim(),
      example: exJa.isEmpty
          ? null
          : Example(ja: exJa, ko: _exampleKo.text.trim()),
      checksExample: _showExample,
    );
  }

  bool get _showExample =>
      _e.example != null || _e.statusOf(EntryField.example) != FieldStatus.ok;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Actions sit at the top so the keyboard never covers them.
            Row(
              children: [
                Expanded(
                  child: Text('고치기', style: context.text.titleLarge),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: Space.xs),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                  ),
                  onPressed: () => Navigator.of(context).pop(_result()),
                  child: const Text('고치기'),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            if (_e.headwordCandidates.isNotEmpty) ...[
              Text(
                '사전에서 찾은 후보',
                style: context.text.labelLarge?.copyWith(color: t.ink3),
              ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final c in _e.headwordCandidates)
                    ActionChip(
                      label: Text(c, style: JpType.print(18, t.ink)),
                      onPressed: () => setState(() => _headword.text = c),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
            ],
            TextField(
              controller: _headword,
              style: JpType.print(22, t.ink),
              decoration: const InputDecoration(labelText: '표제어'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _readings,
              style: JpType.gothic(16, t.ink),
              decoration: const InputDecoration(
                labelText: '읽기',
                helperText: '여러 개면 / 로 나눠요. 가나 단어는 비워 두세요',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Space.md),
            Text('품사', style: context.text.labelLarge?.copyWith(color: t.ink3)),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final p in PartOfSpeech.values)
                  ChoiceChip(
                    label: Text(p.badge),
                    tooltip: p.label,
                    selected: _pos == p,
                    onSelected: (on) => setState(() => _pos = on ? p : null),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _meaning,
              decoration: const InputDecoration(labelText: '뜻'),
              textInputAction: TextInputAction.next,
            ),
            if (_showExample) ...[
              TextField(
                controller: _exampleJa,
                style: JpType.gothic(15, t.ink),
                decoration: const InputDecoration(labelText: '예문 (일본어)'),
                maxLines: null,
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _exampleKo,
                decoration: const InputDecoration(labelText: '예문 번역'),
                maxLines: null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
