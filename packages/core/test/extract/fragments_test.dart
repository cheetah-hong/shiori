// T1–T5: collecting and classifying fragments from both OCR passes.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/fragment_collector.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

List<(FragmentKind, String)> _content(List<Fragment> fragments) => [
  for (final f in fragments)
    if (f.isContent) (f.kind, f.text),
];

void main() {
  test(
    'T1 a checkbox is noise; the bracket reading is its headword\'s pair (high, inline)',
    () async {
      final s = scan(ja: [line('□ 運動(うんどう)', 0.2, 0.3)]);

      final fragments = collectFragments(s);

      expect(_content(fragments), [
        (FragmentKind.kanjiWord, '運動'),
        (FragmentKind.kana, 'うんどう'),
      ]);
      final content = fragments.where((f) => f.isContent).toList();
      expect(content[1].inlineReadingOf, content[0].id);
      expect(
        fragments.any((f) => f.isContent && f.text.contains('□')),
        isFalse,
      );

      final word = (await GeneralExtractor().extract(s)).words.single;
      expect(word.headword, '運動');
      expect(word.readings, ['うんどう']);
      expect(word.readingSource, FieldSource.photo);
      expect(word.readingLink?.confidence, PairConfidence.high);
      expect(word.readingLink?.signals, contains(PairSignal.inlineNotation));
    },
  );

  test('T2 headword[reading] Korean: three fragments, one word', () async {
    final s = sameInBoth([line('図書館[としょかん] 도서관', 0.1, 0.2)]);

    expect(_content(collectFragments(s)), [
      (FragmentKind.kanjiWord, '図書館'),
      (FragmentKind.kana, 'としょかん'),
      (FragmentKind.hangul, '도서관'),
    ]);

    final word = (await GeneralExtractor().extract(s)).words.single;
    expect(word.headword, '図書館');
    expect(word.readings, ['としょかん']);
    expect(word.meaning, '도서관');
    expect(word.meaningSource, FieldSource.photo);
    expect(word.meaningLink?.signals, contains(PairSignal.hanjaReading));
  });

  test('T3 a line ending in 。 is a Japanese sentence, not kanji headwords', () {
    final fragments = collectFragments(scan(ja: [line('学校に行きました。', 0.1, 0.4)]));

    expect(_content(fragments), [(FragmentKind.japaneseSentence, '学校に行きました。')]);
    expect(fragments.where((f) => f.kind == FragmentKind.kanjiWord), isEmpty);
  });

  group('T4 one fragment per place', () {
    test('both passes read the same mixed line: collected once', () {
      final fragments = collectFragments(sameInBoth([line('運動 운동', 0.1, 0.2)]));

      expect(_content(fragments), [
        (FragmentKind.kanjiWord, '運動'),
        (FragmentKind.hangul, '운동'),
      ]);
    });

    test(
      'the Korean pass garbling a Japanese line loses to the Japanese pass',
      () {
        final s = scan(
          ja: [line('学校に行きました。', 0.1, 0.4, w: 0.18, c: 1.0)],
          ko: [line('ㅎ校니 行ㅁ', 0.1, 0.4, w: 0.18, c: 0.3)],
        );

        expect(_content(collectFragments(s)), [
          (FragmentKind.japaneseSentence, '学校に行きました。'),
        ]);
      },
    );

    test(
      'the Japanese pass garbling a Korean line loses to the Korean pass',
      () {
        final s = scan(
          ja: [line('買刀', 0.5, 0.4, w: 0.04, c: 0.3)],
          ko: [line('운동', 0.5, 0.4, w: 0.04, c: 0.5)],
        );

        expect(_content(collectFragments(s)), [(FragmentKind.hangul, '운동')]);
      },
    );
  });

  test(
    'T5 numbers, lone symbols and page numbers are never word candidates',
    () async {
      final s = scan(
        ja: [
          line('0231', 0.05, 0.10),
          line('★', 0.05, 0.15),
          line('□', 0.05, 0.20),
          line('|', 0.05, 0.25),
          line('運動', 0.2, 0.30),
          line('127', 0.8, 0.95),
        ],
      );

      final fragments = collectFragments(s);
      final kinds = {for (final f in fragments) f.text: f.kind};
      expect(kinds['0231'], FragmentKind.number);
      expect(kinds['127'], FragmentKind.number);
      for (final symbol in ['★', '□', '|']) {
        expect(
          kinds[symbol] ?? FragmentKind.noise,
          FragmentKind.noise,
          reason: symbol,
        );
      }

      final result = await GeneralExtractor().extract(s);
      expect(result.words.map((w) => w.headword), ['運動']);
      expect(result.unpaired.where((f) => !f.isContent), isEmpty);
    },
  );
}
