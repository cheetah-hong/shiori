// Q4: the notes the word extractor gives a pair (shown on the review
// screen's evidence) are Korean: a dictionary meaning, several dictionary
// readings, a printed reading the dictionary does not have. No Latin letter
// is left in any note of the synthetic pages. Made-up words only.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/connect_fixtures.dart';
import 'support/extract_fixtures.dart';
import 'support/small_quality_fixtures.dart';
import 'support/stem_fixtures.dart';

final RegExp _latin = RegExp('[A-Za-z]');

const List<LexiconWord> _twoReadings = [
  LexiconWord(id: 9300201, kanji: ['霧森'], readings: ['むもり'], pos: ['n']),
  LexiconWord(id: 9300202, kanji: ['霧森'], readings: ['きりもり'], pos: ['n']),
];

void main() {
  group('Q4 the notes in Korean', () {
    test('a meaning filled from the glossary: 사전 뜻', () async {
      final r = await GeneralExtractor(
        lexicon: smallQualityLexicon(),
        koreanGlossary: MemoryKoreanGlossary({
          '霧話': [
            ['안개말'],
          ],
        }),
      ).extract(sentencePage(['霧話を走る。']));
      final w = r.words.singleWhere((w) => w.headword == '霧話');
      expect(w.meaningSource, FieldSource.dictionary);
      expect(w.meaningLink?.note, '사전 뜻');
    });

    test('a printed reading the dictionary does not have: '
        '사전에는 다른 읽기', () async {
      final r = await GeneralExtractor(lexicon: smallQualityLexicon()).extract(
        scan(ja: [line('霧話（むは）', 0.10, 0.30)], ko: [line('안개말', 0.50, 0.30)]),
      );
      final w = r.words.singleWhere((w) => w.headword == '霧話');
      expect(w.readings, ['むは']);
      expect(w.readingLink?.note, '사전에는 다른 읽기');
    });

    test('several dictionary readings: 사전 읽기가 여럿', () async {
      final r =
          await GeneralExtractor(
            lexicon: InMemoryLexicon([..._twoReadings, ...testWords]),
          ).extract(
            scan(ja: [line('霧森', 0.10, 0.30)], ko: [line('안개숲', 0.50, 0.30)]),
          );
      final w = r.words.singleWhere((w) => w.headword == '霧森');
      expect(w.readingSource, FieldSource.dictionary);
      expect(w.readingLink?.note, '사전 읽기가 여럿');
    });

    test('no Latin letter in any note of the synthetic pages', () async {
      final extractor = syntheticExtractor(glossary: generalGlossary());
      final notes = <String>[];
      for (final file in [
        'ground_truth.json',
        'ground_truth_android.json',
        'ground_truth_traps.json',
      ]) {
        final truth = ExtractTruth.fromJson(readGeneralJson(file));
        for (final page in truth.pages) {
          final scan = await loadGeneralScan(page.fixture);
          for (final w in (await extractor.extract(scan)).words) {
            notes.addAll([
              ?w.readingLink?.note,
              ?w.meaningLink?.note,
              ?w.headwordNote,
            ]);
          }
          for (final e in (await pageDraft(extractor, scan)).entries) {
            for (final field in EntryField.values) {
              notes.addAll([?e.evidence?.of(field)?.note]);
            }
          }
        }
      }
      expect(notes, isNotEmpty);
      expect(notes.where(_latin.hasMatch), isEmpty);
    });
  });
}
