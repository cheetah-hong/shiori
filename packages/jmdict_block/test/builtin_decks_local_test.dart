// B2 on the built-in deck asset with the real dictionaries (local only):
// per level, the share of words that get a Korean meaning when added, a
// card example and an accent stays at or above the floor measured when the
// decks were made (the measured value less half a point, rounded down).
// F4: every meaning the deck file brings (the supplement table) is on a word
// the dictionaries give none, so it never stands in for a dictionary meaning
// and a dictionary refresh that gives one shows the row up as stale.
// Prints numbers only.
// Skipped without the deck asset (built, not committed: app/assets/decks/
// jlpt.json of this checkout, else the one next to the private folder) or
// the dictionary files (SHIORI_JMDICT_DB, SHIORI_KO_GLOSSARY_DB,
// SHIORI_WIKT_GLOSSARY_DB, SHIORI_EXAMPLES_DB as SQLite, SHIORI_ACCENT_TSV;
// else the gzip assets of this checkout's app, else those next to the
// private folder).
import 'dart:io';

import 'package:example_block/example_block.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

String _privateDir() {
  final fromEnv = Platform.environment['SHIORI_PRIVATE_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return Directory.current.uri.resolve('../../.private').toFilePath();
}

/// [envName]'s file, else this checkout's app asset [folder]/[asset]
/// (gzip), else the one next to the private folder, unpacked to [temp].
String? _file(String envName, String folder, String asset, Directory temp) {
  final fromEnv = Platform.environment[envName];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  for (final gz in [
    File(
      Directory.current.uri
          .resolve('../../app/assets/$folder/$asset')
          .toFilePath(),
    ),
    File(
      Directory(
        _privateDir(),
      ).uri.resolve('../app/assets/$folder/$asset').toFilePath(),
    ),
  ]) {
    if (!gz.existsSync()) continue;
    final out = File('${temp.path}/${asset.replaceAll('.gz', '')}')
      ..writeAsBytesSync(gzip.decode(gz.readAsBytesSync()));
    return out.path;
  }
  return null;
}

/// This checkout's deck asset, else the one next to the private folder.
final File _deckAsset = [
  File(
    Directory.current.uri
        .resolve('../../app/assets/decks/jlpt.json')
        .toFilePath(),
  ),
  File(
    Directory(
      _privateDir(),
    ).uri.resolve('../app/assets/decks/jlpt.json').toFilePath(),
  ),
].firstWhere((f) => f.existsSync(), orElse: () => File(''));

/// Floors in percent: (meaning, example, accent) per level.
const Map<String, (double, double, double)> _floors = {
  'N5': (99.5, 98.2, 87.7),
  'N4': (99.5, 98.2, 87.7),
  'N3': (99.5, 97.6, 94.2),
  'N2': (99.3, 87.2, 90.2),
  'N1': (98.0, 79.4, 94.5),
};

/// The word's card as saved by a deck (meaning aside).
Word _word(DeckWord w) => Word(
  id: 'deck:${w.entryId}',
  headword: w.headword,
  readings: w.readings,
  meaning: '',
  createdAt: DateTime.utc(2026, 11, 13),
);

/// An accent for the word, asked the way its card asks (`wordSpeechFor`):
/// its readings (the headword for a kana word), else without a printed
/// ending.
bool _hasAccent(Word w, AccentTable table) {
  bool any(String headword, List<String> readings) =>
      (readings.isEmpty ? [headword] : readings).any(
        (r) => table.lookup(headword, r).isNotEmpty,
      );
  if (any(w.headword, w.readings)) return true;
  final bare = withoutPrintedEnding(w.headword, w.readings);
  return bare != null && any(bare.headword, bare.readings);
}

void main() {
  final temp = Directory.systemTemp.createTempSync('decks_local');
  tearDownAll(() => temp.deleteSync(recursive: true));
  final jmdictPath = _file(
    'SHIORI_JMDICT_DB',
    'dict',
    'jmdict-full-lean.sqlite.gz',
    temp,
  );
  final koPath = _file(
    'SHIORI_KO_GLOSSARY_DB',
    'dict',
    'ko-glossary.sqlite.gz',
    temp,
  );
  final wiktPath = _file(
    'SHIORI_WIKT_GLOSSARY_DB',
    'dict',
    'wikt-glossary.sqlite.gz',
    temp,
  );
  final examplesPath = _file(
    'SHIORI_EXAMPLES_DB',
    'dict',
    'examples.sqlite.gz',
    temp,
  );
  final accentPath = _file(
    'SHIORI_ACCENT_TSV',
    'accent',
    'kanjium-accents.tsv.gz',
    temp,
  );
  final skip =
      !_deckAsset.existsSync() ||
          jmdictPath == null ||
          koPath == null ||
          wiktPath == null ||
          examplesPath == null ||
          accentPath == null
      ? 'no deck asset or dictionary files'
      : null;

  test(
    'B2 every level fills meanings, examples and accents above its floor',
    () async {
      final set = parseBuiltinDecks(_deckAsset.readAsStringSync());
      final jmdict = JmdictDictionary.open(jmdictPath!);
      final ko = KrdictGlossary.open(koPath!);
      final wikt = KrdictGlossary.open(wiktPath!);
      final examples = TatoebaExamples.open(examplesPath!);
      final accents = AccentTable.parse(File(accentPath!).readAsStringSync());
      addTearDown(() {
        examples.close();
        wikt.close();
        ko.close();
        jmdict.close();
      });
      final lexicon = JmdictLexiconAdapter(jmdict);

      expect(
        [for (final d in set.decks) d.level],
        ['N5', 'N4', 'N3', 'N2', 'N1'],
      );
      expect(
        [for (final d in set.decks) d.name],
        [
          for (final level in ['N5', 'N4', 'N3', 'N2', 'N1']) 'JLPT $level 대비',
        ],
      );
      for (final deck in set.decks) {
        final draft = await deckDraft(
          deck,
          lexicon: lexicon,
          glossary: ko,
          fallback: wikt,
        );
        final total = deck.words.length;
        var withExample = 0;
        var withAccent = 0;
        for (final w in deck.words) {
          final word = _word(w);
          final example = await cardExampleOf(
            word,
            lexicon: lexicon,
            examples: examples,
          );
          if (example != null) withExample++;
          if (_hasAccent(word, accents)) withAccent++;
        }
        double pct(int n) => 100 * n / total;
        final meaning = pct(draft.draft.entries.length);
        final example = pct(withExample);
        final accent = pct(withAccent);
        // ignore: avoid_print
        print(
          '${deck.level}: $total words, meaning ${meaning.toStringAsFixed(1)}% '
          '(${draft.withoutMeaning.length} left out), '
          'example ${example.toStringAsFixed(1)}%, '
          'accent ${accent.toStringAsFixed(1)}%',
        );
        final (minMeaning, minExample, minAccent) = _floors[deck.level]!;
        expect(meaning, greaterThanOrEqualTo(minMeaning), reason: deck.level);
        expect(example, greaterThanOrEqualTo(minExample), reason: deck.level);
        expect(accent, greaterThanOrEqualTo(minAccent), reason: deck.level);
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'F4 the deck file\'s own meanings are only on words without one',
    () async {
      final set = parseBuiltinDecks(_deckAsset.readAsStringSync());
      final jmdict = JmdictDictionary.open(jmdictPath!);
      final ko = KrdictGlossary.open(koPath!);
      final wikt = KrdictGlossary.open(wiktPath!);
      addTearDown(() {
        wikt.close();
        ko.close();
        jmdict.close();
      });
      var rows = 0;
      for (final deck in set.decks) {
        final own = [
          for (final w in deck.words)
            if (w.meaning != null)
              DeckWord(
                headword: w.headword,
                reading: w.reading,
                entryId: w.entryId,
                lookupForm: w.lookupForm,
              ),
        ];
        if (own.isEmpty) continue;
        rows += own.length;
        final draft = await deckDraft(
          BuiltinDeck(
            id: deck.id,
            name: deck.name,
            level: deck.level,
            words: own,
          ),
          lexicon: JmdictLexiconAdapter(jmdict),
          glossary: ko,
          fallback: wikt,
        );
        expect(
          [for (final e in draft.draft.entries) e.headword],
          isEmpty,
          reason: '${deck.level}: the dictionaries give these a meaning',
        );
      }
      // ignore: avoid_print
      print('deck file meanings: $rows, all on words without one');
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
