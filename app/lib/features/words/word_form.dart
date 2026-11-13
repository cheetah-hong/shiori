import 'package:flutter/material.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/capture/entry_editor_sheet.dart'
    show parseReadingInput;
import 'package:shiori/features/words/word_labels.dart';
import 'package:shiori/shared/keep_words.dart';
import 'package:shiori/shared/large_text.dart';
import 'package:shiori/shared/widgets.dart';
import 'package:shiori_core/shiori_core.dart';

/// The fields of a word being written (단어 고치기, 단어 추가) and what the
/// dictionary filled or suggests. The dictionary only fills an empty field;
/// a value the learner wrote stays and gets a suggestion chip.
final class WordFormController extends ChangeNotifier {
  WordFormController(WordEdit initial)
    : headword = TextEditingController(text: initial.headword),
      readings = TextEditingController(text: initial.readings.join(' / ')),
      meaning = TextEditingController(text: initial.meaning),
      exampleJa = TextEditingController(text: initial.example?.ja ?? ''),
      exampleKo = TextEditingController(text: initial.example?.ko ?? ''),
      _firstHeadword = initial.headword,
      _pos = initial.pos,
      _hasExample = initial.example != null {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
    headword.addListener(_touchHeadword);
  }

  final TextEditingController headword;
  final TextEditingController readings;
  final TextEditingController meaning;
  final TextEditingController exampleJa;
  final TextEditingController exampleKo;

  List<TextEditingController> get _controllers => [
    headword,
    readings,
    meaning,
    exampleJa,
    exampleKo,
  ];

  final String _firstHeadword;
  bool _headwordTouched = false;

  void _touchHeadword() {
    if (headword.text != _firstHeadword) _headwordTouched = true;
  }

  PartOfSpeech? _pos;
  PartOfSpeech? get pos => _pos;
  set pos(PartOfSpeech? value) {
    _pos = value;
    notifyListeners();
  }

  bool _hasExample;

  /// The word keeps the example read from its page.
  bool get hasExample => _hasExample;

  /// 예문 지우기: the card looks an example up in the dictionary instead.
  void dropExample() {
    _hasExample = false;
    exampleJa.clear();
    exampleKo.clear();
    notifyListeners();
  }

  /// What the dictionary put in each field, while the field still says it.
  Map<EntryField, String> _filled = const {};
  List<String>? _readingSuggestion;
  PartOfSpeech? _posSuggestion;
  List<String> _meaningSuggestions = const [];

  List<String>? get readingSuggestion => _readingSuggestion;
  PartOfSpeech? get posSuggestion => _posSuggestion;
  List<String> get meaningSuggestions => _meaningSuggestions;

  /// The field still holds what the dictionary filled.
  bool isFilled(EntryField field) => switch (field) {
    EntryField.readings => _filled[field] == readings.text,
    EntryField.meaning => _filled[field] == meaning.text,
    EntryField.pos => _filled[field] != null && _filled[field] == _pos?.name,
    _ => false,
  };

  /// The form as a word (fields trimmed by the use case).
  WordEdit get value => WordEdit(
    headword: headword.text,
    readings: parseReadingInput(readings.text),
    pos: _pos,
    meaning: meaning.text,
    example: _hasExample && exampleJa.text.trim().isNotEmpty
        ? Example(ja: exampleJa.text.trim(), ko: exampleKo.text.trim())
        : null,
  );

  /// Takes back what the dictionary filled for an earlier headword (a field
  /// the learner changed since stays), and the suggestions.
  void clearFill() {
    if (isFilled(EntryField.readings)) readings.clear();
    if (isFilled(EntryField.meaning)) meaning.clear();
    if (isFilled(EntryField.pos)) _pos = null;
    _filled = const {};
    _readingSuggestion = null;
    _posSuggestion = null;
    _meaningSuggestions = const [];
    notifyListeners();
  }

  /// Fills the empty fields from [fill] and keeps the rest as suggestions.
  void applyFill(WordFill fill) {
    final merged = mergeFill(value, fill);
    final filled = <EntryField, String>{};
    if (merged.filled.contains(EntryField.readings)) {
      readings.text = merged.edit.readings.join(' / ');
      filled[EntryField.readings] = readings.text;
    }
    if (merged.filled.contains(EntryField.meaning)) {
      meaning.text = merged.edit.meaning;
      filled[EntryField.meaning] = meaning.text;
    }
    if (merged.filled.contains(EntryField.pos)) {
      _pos = merged.edit.pos;
      filled[EntryField.pos] = _pos?.name ?? '';
    }
    _filled = Map.unmodifiable(filled);
    _readingSuggestion = merged.readingSuggestion;
    _posSuggestion = merged.posSuggestion;
    _meaningSuggestions = merged.meaningSuggestions;
    notifyListeners();
  }

  /// A kanji spelling picked for a headword typed in kana: the headword,
  /// its reading and, where the dictionary or nobody wrote them, its class
  /// and meaning.
  void useChoice(KanjiChoice choice) {
    final filled = Map.of(_filled);
    if (readings.text.trim().isEmpty || isFilled(EntryField.readings)) {
      readings.text = choice.reading;
      filled[EntryField.readings] = readings.text;
    }
    final m = choice.meaning;
    if (m != null &&
        (meaning.text.trim().isEmpty || isFilled(EntryField.meaning))) {
      meaning.text = m;
      filled[EntryField.meaning] = m;
    }
    if (choice.pos != null && (_pos == null || isFilled(EntryField.pos))) {
      _pos = choice.pos;
      filled[EntryField.pos] = choice.pos!.name;
    }
    _filled = Map.unmodifiable(filled);
    headword.text = choice.headword;
  }

  void useReadings(List<String> value) {
    readings.text = value.join(' / ');
    _readingSuggestion = null;
    notifyListeners();
  }

  void usePos(PartOfSpeech value) {
    _pos = value;
    _posSuggestion = null;
    notifyListeners();
  }

  void useMeaning(String value) {
    final old = meaning.text.trim();
    meaning.text = value;
    _meaningSuggestions = List.unmodifiable([
      if (old.isNotEmpty) old,
      for (final m in _meaningSuggestions)
        if (m != value && m != old) m,
    ]);
    notifyListeners();
  }

  /// What is wrong with the headword, once the learner wrote one.
  String? get headwordProblemShown {
    final problem = headwordProblem(headword.text);
    if (problem == null) return null;
    return _headwordTouched || headword.text.trim().isNotEmpty ? problem : null;
  }

  /// What is wrong with the meaning, once the headword is right.
  String? get meaningProblemShown => headwordProblem(headword.text) == null
      ? meaningProblem(meaning.text)
      : null;

  bool get canSave =>
      headwordProblem(headword.text) == null &&
      meaningProblem(meaning.text) == null;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// The word's fields: headword, then (unless [showDetails] is off) reading,
/// class, meaning and the page's example. [belowHeadword] goes right under
/// the headword (kanji choices, the note on a changed key, a stored word).
class WordFormFields extends StatelessWidget {
  const WordFormFields({
    super.key,
    required this.form,
    this.headwordHelp,
    this.belowHeadword,
    this.showDetails = true,
  });

  final WordFormController form;

  /// A line under the headword when nothing is wrong with it.
  final String? headwordHelp;
  final Widget? belowHeadword;
  final bool showDetails;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: form,
    builder: (context, _) => _fields(context),
  );

  Widget _fields(BuildContext context) {
    final t = context.tokens;
    final headwordProblem = form.headwordProblemShown;
    final meaningProblem = form.meaningProblemShown;
    final readingSuggestion = form.readingSuggestion;
    final posSuggestion = form.posSuggestion;
    final warn = TextStyle(color: t.warn, fontWeight: Weights.emphasis);
    final filledStyle = TextStyle(color: t.text3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('word-headword'),
          controller: form.headword,
          style: JpType.headword(TypeScale.title, t.text),
          decoration: InputDecoration(
            labelText: WordLabels.headword,
            helperText: headwordProblem ?? headwordHelp,
            helperStyle: headwordProblem == null ? null : warn,
            helperMaxLines: 3,
          ),
          textInputAction: TextInputAction.next,
        ),
        ?belowHeadword,
        if (showDetails) ...[
          const SizedBox(height: Space.md),
          TextField(
            key: const ValueKey('word-readings'),
            controller: form.readings,
            style: JpType.body(TypeScale.body, t.text),
            decoration: InputDecoration(
              labelText: WordLabels.readings,
              helperText: form.isFilled(EntryField.readings)
                  ? WordLabels.filled
                  : WordLabels.readingsHelp,
              helperStyle: form.isFilled(EntryField.readings)
                  ? filledStyle
                  : null,
              helperMaxLines: 3,
            ),
            textInputAction: TextInputAction.next,
          ),
          if (readingSuggestion != null)
            _Suggestions(
              label: WordLabels.suggestion,
              children: [
                ActionChip(
                  label: JpText(readingSuggestion.join(' / ')),
                  onPressed: () => form.useReadings(readingSuggestion),
                ),
              ],
            ),
          const SizedBox(height: Space.md),
          Text(
            WordLabels.pos,
            style: context.text.labelLarge?.copyWith(color: t.text3),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final p in PartOfSpeech.values)
                ChoiceChip(
                  label: Text(p.badge),
                  tooltip: p.label,
                  selected: form.pos == p,
                  onSelected: (on) => form.pos = on ? p : null,
                ),
            ],
          ),
          if (posSuggestion != null)
            _Suggestions(
              label: WordLabels.suggestion,
              children: [
                ActionChip(
                  label: Text(posSuggestion.label),
                  onPressed: () => form.usePos(posSuggestion),
                ),
              ],
            ),
          const SizedBox(height: Space.md),
          TextField(
            key: const ValueKey('word-meaning'),
            controller: form.meaning,
            decoration: InputDecoration(
              labelText: WordLabels.meaning,
              helperText:
                  meaningProblem ??
                  (form.isFilled(EntryField.meaning)
                      ? WordLabels.filled
                      : null),
              helperStyle: meaningProblem == null ? filledStyle : warn,
            ),
            textInputAction: TextInputAction.next,
          ),
          if (form.meaningSuggestions.isNotEmpty)
            _Suggestions(
              label: form.isFilled(EntryField.meaning)
                  ? WordLabels.otherMeanings
                  : WordLabels.suggestion,
              children: [
                for (final m in form.meaningSuggestions)
                  ActionChip(
                    label: Text(m),
                    onPressed: () => form.useMeaning(m),
                  ),
              ],
            ),
          if (form.hasExample) ...[
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('word-example-ja'),
              controller: form.exampleJa,
              style: JpType.body(TypeScale.body2, t.text),
              decoration: const InputDecoration(
                labelText: WordLabels.exampleJa,
              ),
              maxLines: null,
            ),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('word-example-ko'),
              controller: form.exampleKo,
              decoration: const InputDecoration(
                labelText: WordLabels.exampleKo,
              ),
              maxLines: null,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: form.dropExample,
                child: const Text(WordLabels.dropExample),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// A short label and the chips that put a dictionary value in a field.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Wrap(
      spacing: Space.sm,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(color: context.tokens.text3),
        ),
        ...children,
      ],
    ),
  );
}

/// The head of a word sheet: its title, 취소 and the main button, on one
/// row at the top so the keyboard never covers them.
class WordSheetHead extends StatelessWidget {
  const WordSheetHead({super.key, required this.title, this.primary});

  final String title;

  /// The main button (none when there is nothing to do).
  final Widget? primary;

  @override
  Widget build(BuildContext context) => CappedText(
    max: TextCaps.chrome,
    child: Row(
      children: [
        Expanded(child: KeepWordsText(title, style: context.text.titleLarge)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(WordLabels.cancel),
        ),
        if (primary case final p?) ...[const SizedBox(width: Space.xs), p],
      ],
    ),
  );
}
