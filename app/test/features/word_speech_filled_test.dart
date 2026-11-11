// X5: a filled example is spoken through the same request as a page example
// (the engine reads it, the card word's accent phrase is fixed).
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/word_speech.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

Word _word({Example? example}) => Word(
  id: 'w1',
  headword: '箸',
  readings: const ['はし'],
  meaning: '젓가락',
  createdAt: DateTime(2026, 11, 12),
  pos: PartOfSpeech.noun,
  example: example,
);

const _filled = CardExample(
  ja: '箸を置きました。',
  en: 'I put the chopsticks down.',
  origin: ExampleOrigin.tatoeba,
);

void main() {
  final table = AccentTable.parse('箸\tはし\t1\n');

  test('the filled sentence with the card word, as a page example', () {
    final got = exampleSpeechFor(_word(), table, filled: _filled);
    final page = exampleSpeechFor(
      _word(
        example: const Example(ja: '箸を置きました。', ko: ''),
      ),
      table,
    );
    expect(got, isA<SentenceSpeech>());
    expect(got!.text, '箸を置きました。');
    expect(got.word.headword, '箸');
    expect(got.word.accents, [1]);
    expect(got, page);
  });

  test('the page example wins over a filled one', () {
    final got = exampleSpeechFor(
      _word(
        example: const Example(ja: '箸で食べます。', ko: '젓가락으로 먹습니다.'),
      ),
      table,
      filled: _filled,
    );
    expect(got?.text, '箸で食べます。');
  });

  test('no example at all: no request', () {
    expect(exampleSpeechFor(_word(), table), isNull);
  });
}
