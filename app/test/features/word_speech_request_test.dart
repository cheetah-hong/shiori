import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/study/word_speech.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

Word _word(String headword, List<String> readings, {Example? example}) => Word(
  id: headword,
  headword: headword,
  readings: readings,
  meaning: '뜻',
  createdAt: DateTime(2026, 11, 6),
  pos: PartOfSpeech.noun,
  example: example,
);

void main() {
  final table = AccentTable.parse('橋\tはし\t2,1\n端\tはし\t0\nふわり\t\t2\n');

  test('a word takes its accents from the table, with its part of speech', () {
    final speech = wordSpeechFor(_word('橋', ['はし']), table);
    expect(
      speech,
      const WordSpeech(
        headword: '橋',
        reading: 'はし',
        accents: [2, 1],
        pos: PartOfSpeech.noun,
      ),
    );
  });

  test('the first reading the table knows is used', () {
    final speech = wordSpeechFor(_word('端', ['はた', 'はし']), table);
    expect(speech.reading, 'はし');
    expect(speech.accents, [0]);
  });

  test('without data: the first reading, estimated', () {
    final speech = wordSpeechFor(_word('雲', ['くも']), table);
    expect(speech.reading, 'くも');
    expect(speech.isEstimated, isTrue);
  });

  test('a word with no reading is read by its written form', () {
    final speech = wordSpeechFor(_word('ふわり', []), table);
    expect(speech.reading, 'ふわり');
    expect(speech.accents, [2]);
  });

  test('an example becomes a sentence request with the word', () {
    final word = _word('橋', [
      'はし',
    ], example: const Example(ja: '橋を渡る。', ko: '다리를 건너다.'));
    expect(
      exampleSpeechFor(word, table),
      SentenceSpeech(text: '橋を渡る。', word: wordSpeechFor(word, table)),
    );
    expect(exampleSpeechFor(_word('橋', ['はし']), table), isNull);
  });

  test('pitch info follows the request', () {
    final known = pitchInfoFor(wordSpeechFor(_word('橋', ['はし']), table));
    expect(known?.morae, ['は', 'し']);
    expect(known?.accent, 2);
    expect(known?.estimated, isFalse);
    final guessed = pitchInfoFor(wordSpeechFor(_word('雲', ['くも']), table));
    expect(guessed?.accent, isNull);
    expect(guessed?.estimated, isTrue);
    // A reading that is not kana has no line.
    expect(pitchInfoFor(const WordSpeech(headword: '雲', reading: '雲')), isNull);
  });
}
