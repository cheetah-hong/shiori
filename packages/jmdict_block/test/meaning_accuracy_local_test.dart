// M4 on the built-in deck asset with the real dictionaries (local only): in
// the accuracy sample (30 words a level, their meanings judged), the meaning
// a deck word gets when added is one judged right at least as often as
// before the meaning overrides (122 of 150), and every word the sample has a
// reviewed override for gets it. Prints numbers only.
// Skipped without the sample ($SHIORI_PRIVATE_DIR/meaning/accuracy150.tsv:
// level, headword, entry, accept — the right meanings, ` | ` between them —
// and override, 1 when one of them is the overrides file's), the deck asset
// or the dictionary files (as in builtin_decks_local_test.dart). The
// overrides file (app/assets/dict/meaning-overrides.json) is used when it is
// there.
import 'dart:io';

import 'package:jmdict_block/jmdict_block.dart';
import 'package:krdict_block/krdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// Words of the sample whose meaning was judged right before the overrides.
const int _rightBefore = 122;

String _privateDir() {
  final fromEnv = Platform.environment['SHIORI_PRIVATE_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return Directory.current.uri.resolve('../../.private').toFilePath();
}

/// This checkout's app asset [folder]/[name], else the one next to the
/// private folder.
File _asset(String folder, String name) => [
  File(
    Directory.current.uri
        .resolve('../../app/assets/$folder/$name')
        .toFilePath(),
  ),
  File(
    Directory(
      _privateDir(),
    ).uri.resolve('../app/assets/$folder/$name').toFilePath(),
  ),
].firstWhere((f) => f.existsSync(), orElse: () => File(''));

/// [envName]'s SQLite file, else the gzip asset unpacked to [temp].
String? _db(String envName, String asset, Directory temp) {
  final fromEnv = Platform.environment[envName];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;
  final gz = _asset('dict', asset);
  if (!gz.existsSync()) return null;
  final out = File('${temp.path}/${asset.replaceAll('.gz', '')}')
    ..writeAsBytesSync(gzip.decode(gz.readAsBytesSync()));
  return out.path;
}

typedef _Sample = ({
  String level,
  String headword,
  int entry,
  Set<String> accept,
  bool override,
});

List<_Sample> _readSample(File file) {
  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final head = lines.first.split('\t');
  int col(String name) => head.indexOf(name);
  return [
    for (final line in lines.skip(1))
      if (line.split('\t') case final cells)
        (
          level: cells[col('level')],
          headword: cells[col('headword')],
          entry: int.parse(cells[col('entry')]),
          accept: {for (final m in cells[col('accept')].split(' | ')) m.trim()},
          override: cells[col('override')].trim() == '1',
        ),
  ];
}

void main() {
  final temp = Directory.systemTemp.createTempSync('meaning_accuracy');
  tearDownAll(() => temp.deleteSync(recursive: true));
  final sampleFile = File('${_privateDir()}/meaning/accuracy150.tsv');
  final deckFile = _asset('decks', 'jlpt.json');
  final overridesFile = _asset('dict', 'meaning-overrides.json');
  final jmdictPath = _db(
    'SHIORI_JMDICT_DB',
    'jmdict-full-lean.sqlite.gz',
    temp,
  );
  final koPath = _db('SHIORI_KO_GLOSSARY_DB', 'ko-glossary.sqlite.gz', temp);
  final wiktPath = _db(
    'SHIORI_WIKT_GLOSSARY_DB',
    'wikt-glossary.sqlite.gz',
    temp,
  );
  final skip =
      !sampleFile.existsSync() ||
          !deckFile.existsSync() ||
          jmdictPath == null ||
          koPath == null ||
          wiktPath == null
      ? 'no accuracy sample, deck asset or dictionary files'
      : null;

  test('M4 the sample\'s right meanings, at or above the floor', () async {
    final sample = _readSample(sampleFile);
    expect(sample, hasLength(150));
    final set = parseBuiltinDecks(deckFile.readAsStringSync());
    final jmdict = JmdictDictionary.open(jmdictPath!);
    final ko = KrdictGlossary.open(koPath!);
    final wikt = KrdictGlossary.open(wiktPath!);
    addTearDown(() {
      wikt.close();
      ko.close();
      jmdict.close();
    });
    final hasOverrides = overridesFile.existsSync();
    final KoreanGlossary glossary = hasOverrides
        ? OverriddenKoreanGlossary(
            ko,
            parseMeaningOverrides(overridesFile.readAsStringSync()),
          )
        : ko;
    final lexicon = JmdictLexiconAdapter(jmdict);

    var right = 0;
    var overridden = 0;
    final wrong = <String>[];
    for (final level in ['N5', 'N4', 'N3', 'N2', 'N1']) {
      final rows = [
        for (final s in sample)
          if (s.level == level) s,
      ];
      final deck = set.decks.singleWhere((d) => d.level == level);
      final words = [
        for (final s in rows)
          deck.words.singleWhere(
            (w) => w.headword == s.headword && w.entryId == s.entry,
          ),
      ];
      final draft = await deckDraft(
        BuiltinDeck(id: deck.id, name: deck.name, level: level, words: words),
        lexicon: lexicon,
        glossary: glossary,
        fallback: wikt,
      );
      final meanings = {
        for (final e in draft.draft.entries) e.headword: e.meaning,
      };
      for (final s in rows) {
        if (s.override && hasOverrides) overridden++;
        if (s.accept.contains(meanings[s.headword])) {
          right++;
        } else {
          wrong.add('${s.level} ${s.entry}');
        }
      }
    }
    // ignore: avoid_print
    print(
      'accuracy sample: $right/150 right '
      '(${hasOverrides ? 'with' : 'without'} overrides, $overridden overridden); '
      'not right: ${wrong.join(', ')}',
    );
    expect(right, greaterThanOrEqualTo(_rightBefore + overridden));
  }, skip: skip);
}
