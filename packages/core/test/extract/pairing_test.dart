// T11–T15: pairing headwords with readings and meanings by content first.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

/// Headwords 運動, 図書館, 食べる down the left column; the Korean column is
/// one row lower (운동 on 図書館's row, ...), as on a curled page.
OcrScan _shiftedList() => scan(
  ja: [line('運動', 0.2, 0.20), line('図書館', 0.2, 0.25), line('食べる', 0.2, 0.30)],
  ko: [line('운동', 0.5, 0.25), line('도서관', 0.5, 0.30), line('먹다', 0.5, 0.35)],
);

ExtractedWord _word(ExtractionResult r, String headword) =>
    r.words.singleWhere((w) => w.headword == headword);

void main() {
  test(
    'T11 a list shifted by a row pairs by Korean readings and glosses',
    () async {
      final r = await GeneralExtractor(
        lexicon: testLexicon(),
        koreanGlosses: testGlosses,
      ).extract(_shiftedList());

      expect(_word(r, '運動').meaning, '운동');
      expect(_word(r, '図書館').meaning, '도서관');
      expect(_word(r, '食べる').meaning, '먹다');
      expect(
        _word(r, '運動').meaningLink?.signals,
        contains(PairSignal.hanjaReading),
      );
      expect(
        _word(r, '図書館').meaningLink?.signals,
        contains(PairSignal.hanjaReading),
      );
      expect(
        _word(r, '食べる').meaningLink?.signals,
        contains(PairSignal.koreanGloss),
      );
    },
  );

  test(
    'T12 without a gloss lookup the position-only pair is low, never high',
    () async {
      final r = await GeneralExtractor(
        lexicon: testLexicon(),
      ).extract(_shiftedList());

      final taberu = _word(r, '食べる');
      expect(taberu.meaning, '먹다');
      expect(taberu.meaningLink?.confidence, PairConfidence.low);
      expect(taberu.meaningLink?.signals, {PairSignal.position});
      expect(
        _word(r, '運動').meaningLink?.confidence,
        anyOf(PairConfidence.high, PairConfidence.medium),
      );
      for (final w in r.words) {
        final link = w.meaningLink;
        if (link == null || link.confidence != PairConfidence.high) continue;
        expect(
          link.signals.difference({PairSignal.position}),
          hasLength(greaterThanOrEqualTo(2)),
          reason: '${w.headword}: high needs two content signals',
        );
      }
    },
  );

  test(
    'T13 a headword printed without a reading gets the dictionary reading',
    () async {
      final r = await GeneralExtractor(
        lexicon: testLexicon(),
      ).extract(scan(ja: [line('部屋', 0.2, 0.3)], ko: [line('방', 0.5, 0.3)]));

      final heya = _word(r, '部屋');
      expect(heya.readings, ['へや']);
      expect(heya.readingSource, FieldSource.dictionary);
      expect(heya.readingLink?.fragmentId, isNull);
      expect(heya.meaning, '방');
    },
  );

  test(
    'T14 a kana word that is no headword\'s reading stays a word of its own',
    () async {
      final r = await GeneralExtractor(lexicon: testLexicon()).extract(
        scan(
          ja: [line('走る', 0.2, 0.20), line('あまり', 0.2, 0.25)],
          ko: [line('달리다', 0.5, 0.20), line('그다지', 0.5, 0.25)],
        ),
      );

      final hashiru = _word(r, '走る');
      expect(hashiru.readings, ['はしる']);
      expect(hashiru.readingSource, FieldSource.dictionary);
      expect(hashiru.meaning, '달리다');
      final amari = _word(r, 'あまり');
      expect(amari.readings, isEmpty);
      expect(amari.meaning, '그다지');
    },
  );

  test('T15 fragments nothing pairs with are kept as unpaired', () async {
    final r = await GeneralExtractor(lexicon: testLexicon()).extract(
      scan(
        ja: [line('運動', 0.2, 0.20), line('顰蹙', 0.2, 0.60)],
        ko: [line('운동', 0.5, 0.20), line('메모장', 0.8, 0.90)],
      ),
    );

    expect(_word(r, '運動').meaning, '운동');
    final unpaired = {for (final f in r.unpaired) f.text: f.kind};
    expect(unpaired['메모장'], FragmentKind.hangul);
    expect(unpaired['顰蹙'], FragmentKind.kanjiWord);
    expect(r.words.map((w) => w.headword), isNot(contains('顰蹙')));
  });
}
