// D7, D8 and the draft order: what the word extractor needed to read the
// word-book pages (tools/synthetic/make_pages.py) as well as the row
// templates did, and the review draft in the photo's order. Made-up pages.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/real_dictionary.dart';
import 'support/confidence_fixtures.dart';
import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';

const _shine = LexiconWord(
  id: 1272820,
  kanji: ['光る'],
  readings: ['ひかる'],
  pos: ['v5r', 'vi'],
  priority: 6,
);

const _light = LexiconWord(
  id: 1272770,
  kanji: ['光'],
  readings: ['ひかり'],
  pos: ['n'],
  priority: 6,
);

/// The kanji 一 as JMdict has it, with its reading ひ (entry 2821500): a
/// flat dash beside the unread 日's ひ would pair as a word.
const _one = [
  LexiconWord(
    id: 1160790,
    kanji: ['一'],
    readings: ['いち'],
    pos: ['num'],
    priority: 6,
  ),
  LexiconWord(id: 2821500, kanji: ['一'], readings: ['ひと', 'ひ', 'ひい']),
];

const _tv = LexiconWord(
  id: 1078950,
  readings: ['テレビ'],
  pos: ['n'],
  priority: 6,
);

/// One word-list row: headword, reading, meaning.
OcrScan _row(String headword, String reading, String meaning) => scan(
  ja: [line(headword, 0.10, 0.10), line(reading, 0.30, 0.10)],
  ko: [line(meaning, 0.50, 0.10)],
);

Future<List<String>> _headwords(OcrScan page, List<LexiconWord> words) async =>
    [
      for (final w in (await GeneralExtractor(
        lexicon: InMemoryLexicon(words),
      ).extract(page)).words)
        w.headword,
    ];

void main() {
  group('D7 okurigana read as katakana', () {
    test('光ル beside ひかる is 光る, said so on the headword cell', () async {
      final draft = await pageDraft(
        confidenceExtractor(rowLexicon(), glossary: realGlossary()),
        await synthetic.loadScan('s011'),
      );
      final shine = entryOf(draft, '光る');
      expect(shine.readings, ['ひかる']);
      expect(shine.evidence!.of(EntryField.headword)!.note, contains('글자 보정'));
      expect(shine.wasCorrected, isTrue);
      final headwords = draft.entries.map((e) => e.headword);
      expect(headwords, isNot(contains('光ル')));
      expect(headwords, isNot(contains('ひかる')));
    });

    test('the same on a hand-made row', () async {
      expect(await _headwords(_row('光ル', 'ひかる', '빛나다'), [_shine, _light]), [
        '光る',
      ]);
    });

    test('left as read when the dictionary lacks the fixed spelling', () async {
      expect(
        await _headwords(_row('光ル', 'ひかる', '빛나다'), [_light]),
        isNot(contains('光る')),
      );
    });

    test('left as read when the kana beside it is another reading', () async {
      expect(
        await _headwords(_row('光ル', 'ひかり', '빛'), [_shine, _light]),
        isNot(contains('光る')),
      );
    });

    test('a katakana word stays katakana', () async {
      expect(await _headwords(_row('テレビ', '', '텔레비전'), [_tv]), ['テレビ']);
    });
  });

  group('D8 the dash of an empty reading cell', () {
    test('a flat 一 in the reading column of a word-book page is no word, '
        'though the page\'s small number and box lines are many', () async {
      final draft = await pageDraft(
        confidenceExtractor(
          InMemoryLexicon([...rowPageWords, ..._one]),
          glossary: realGlossary(),
        ),
        await synthetic.loadScan('s010'),
      );
      expect(draft.entries.map((e) => e.headword), isNot(contains('一')));
      expect(draft.entries.map((e) => e.headword), contains('ちょっと'));
    });
  });

  group('the review draft', () {
    test('lists the words in the photo\'s order', () async {
      final extractor = syntheticExtractor(glossary: generalGlossary());
      var reordered = 0;
      for (final fixture in ['g01', 'g03', 'g05', 'g10', 'g11']) {
        final page = await loadGeneralScan(fixture);
        final words = (await extractor.extract(page)).words;
        final inPhotoOrder = [...words]
          ..sort(
            (a, b) => (a.headwordFragmentId ?? 1 << 30).compareTo(
              b.headwordFragmentId ?? 1 << 30,
            ),
          );
        final want = [for (final w in inPhotoOrder) w.headword];
        if (!_same(want, [for (final w in words) w.headword])) reordered++;
        final draft = await pageDraft(extractor, page);
        expect(
          draft.entries.map((e) => e.headword).toList(),
          want,
          reason: fixture,
        );
      }
      // At least one page lists its kana words after its kanji words.
      expect(reordered, greaterThan(0));
    });

    test('keeps the skipped words and the tray', () async {
      final page = await loadGeneralScan('g01');
      final extractor = syntheticExtractor();
      final r = await extractor.extract(page, knownHeadwords: {'走る'});
      final draft = await pageDraft(extractor, page, knownHeadwords: {'走る'});
      expect(draft.skippedKnown, ['走る']);
      expect(draft.unpaired.map((f) => f.id), r.unpaired.map((f) => f.id));
      expect(draft.recognitionTime, page.elapsed);
    });
  });
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
