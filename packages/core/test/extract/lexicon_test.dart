// The Lexicon port's memory block.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';

void main() {
  test('kanji and kana forms are both looked up, in one call', () async {
    final found = await testLexicon().lookup(['食べる', 'たべる', 'ない', 'タベル']);

    expect(found.keys.toSet(), {'食べる', 'たべる', 'タベル'});
    final kanji = found['食べる']!.single;
    expect(kanji.isKanaForm, isFalse);
    expect(kanji.readings, ['たべる']);
    expect(kanji.partsOfSpeech, contains('v1'));
    expect(found['たべる']!.single.isKanaForm, isTrue);
  });

  test('usually-kana and kanji-less entries are written in kana', () async {
    final found = await testLexicon().lookup(['とても', 'に']);

    expect(found['とても']!.single.writtenInKana, isTrue);
    final ni = found['に']!;
    expect(
      ni.firstWhere((e) => e.partsOfSpeech.contains('prt')).writtenInKana,
      isTrue,
    );
    expect(
      ni.firstWhere((e) => e.partsOfSpeech.contains('num')).writtenInKana,
      isFalse,
    );
  });

  test('the empty block knows nothing', () async {
    expect(await const EmptyLexicon().lookup(['食べる']), isEmpty);
  });

  test('JSON entries load; a malformed one fails loudly', () {
    final lexicon = InMemoryLexicon.fromJson({
      'entries': [
        {
          'id': 1,
          'kanji': ['料理'],
          'readings': ['りょうり'],
          'pos': ['n', 'vs'],
          'pri': 5,
          'nf': 3,
          'uk': false,
        },
      ],
    });
    expect(lexicon, isA<Lexicon>());
    expect(
      () => InMemoryLexicon.fromJson({'entries': 'x'}),
      throwsFormatException,
    );
    expect(
      () => InMemoryLexicon.fromJson({
        'entries': [
          {
            'id': 'one',
            'readings': ['a'],
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
