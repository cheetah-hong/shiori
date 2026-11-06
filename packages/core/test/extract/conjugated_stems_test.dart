// C1–C3: a stem the dictionary also has as a noun, before the ending of a
// conjugation that a grammar expression swallows (霧け + なければなりません),
// is the verb or adjective in its dictionary form; a noun with no
// conjugation's ending after it stays a noun; on one page a stem left over
// next to its dictionary form goes into it. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/lattice.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';
import 'support/stem_fixtures.dart';

void main() {
  final segmenter = SentenceSegmenter(stemLexicon());

  Future<List<String>> bases(String sentence) async => [
    for (final t in await segmenter.contentWords(sentence)) t.base,
  ];

  group('C1 a conjugated form is its dictionary form', () {
    const cases = {
      // 一段: negative conditional, negative て, past, polite past.
      '霧けなければなりません。': ['霧ける'],
      '霧けなければならない。': ['霧ける'],
      '霧けなくてもいい。': ['霧ける'],
      '霧けなくてはいけない。': ['霧ける'],
      '霧けた。': ['霧ける'],
      '霧けました。': ['霧ける'],
      // 五段: negative conditional, polite imperative after the masu stem.
      '霧かなければならない。': ['霧く'],
      '霧きなさい。': ['霧く'],
      // する: the noun, then する.
      '霧話しなければならない。': ['霧話', 'する'],
      // い-adjective: negative て, negative conditional.
      '遠霧くなくてもいい。': ['遠霧い'],
      '遠霧くなければなりません。': ['遠霧い'],
    };
    for (final MapEntry(key: sentence, value: words) in cases.entries) {
      test(sentence, () async {
        expect(await bases(sentence), words);
      });
    }

    test('the word takes the dictionary form\'s reading and class', () async {
      final t = (await segmenter.contentWords('霧けなければなりません。')).single;

      expect(t.base, '霧ける');
      expect(t.surface, '霧け');
      expect(t.readings, ['きりける']);
      expect(t.partsOfSpeech, contains('v1'));
      expect(t.steps, isNotEmpty);
    });

    test('the adjective takes its own class', () async {
      final t = (await segmenter.contentWords('遠霧くなくてもいい。')).single;

      expect(t.readings, ['とおぎりい']);
      expect(t.partsOfSpeech, contains('adj-i'));
    });
  });

  group('C2 a noun with no conjugation\'s ending after it stays a noun', () {
    const cases = {
      '霧けを読みます。': ['霧け', '読む'],
      '霧けなら行きます。': ['霧け', '行く'],
      '霧きなので、行きます。': ['霧き', '行く'],
      '霧けなので、行きます。': ['霧け', '行く'],
      '遠霧くに行きます。': ['遠霧く', '行く'],
      '霧け。': ['霧け'],
    };
    for (final MapEntry(key: sentence, value: words) in cases.entries) {
      test(sentence, () async {
        expect(await bases(sentence), words);
      });
    }

    test('the noun keeps its reading and class', () async {
      final t = (await segmenter.contentWords('霧けを読みます。')).first;

      expect(t.readings, ['きりけ']);
      expect(t.partsOfSpeech, ['n']);
      expect(t.steps, isEmpty);
    });
  });

  group('C3 a stem left next to its dictionary form on one page', () {
    final extractor = GeneralExtractor(lexicon: stemLexicon());

    Future<List<ExtractedWord>> words(List<String> sentences) async =>
        (await extractor.extract(sentencePage(sentences))).words;

    List<String> heads(List<ExtractedWord> ws) => [
      for (final w in ws) w.headword,
    ];

    test('both sentences give the one dictionary form', () async {
      final ws = await words(['霧けなければなりません。', '霧けます。']);

      expect(heads(ws).where((h) => h == '霧ける'), hasLength(1));
      expect(heads(ws), isNot(contains('霧け')));
    });

    test('a stem with nothing after it goes into the dictionary form, which '
        'keeps its own example', () async {
      final ws = await words(['霧けます。', '霧け。']);

      expect(heads(ws), ['霧ける']);
      expect(ws.single.example?.ja, '霧けます。');
    });

    test('the stem\'s example goes to a printed dictionary form that has '
        'none', () async {
      final r = await extractor.extract(
        scan(
          ja: [
            line('霧ける', 0.1, 0.1),
            line('きりける', 0.25, 0.1),
            line('霧け。', 0.1, 0.4),
          ],
        ),
      );

      expect(heads(r.words), ['霧ける']);
      expect(r.words.single.origin, WordOrigin.wordList);
      expect(r.words.single.example?.ja, '霧け。');
    });

    test('a stem used as a noun (a particle after it) stays next to the '
        'dictionary form', () async {
      final ws = await words(['霧けが高い。', '霧けます。']);

      expect(heads(ws), containsAll(['霧け', '霧ける', '高い']));
    });

    test('a stem with no dictionary form on the page stays', () async {
      final ws = await words(['霧け。']);

      expect(heads(ws), ['霧け']);
    });
  });
}
