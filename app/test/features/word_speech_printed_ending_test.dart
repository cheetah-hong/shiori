// E4, E5, E6: a な-adjective saved as a word list prints it (`X だ` read
// `xだ`) sounds as the dictionary word X: its accents come from the table's
// `X / x`, the request (and the pitch line) is the one of the word saved as
// X, also for the example sentence and the sound 듣고 맞히기 plays by itself.
// A word the table has with its ending, or one printed without it, sounds as
// before. Made-up words.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/features/study/word_speech.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:voicevox_block/voicevox_block.dart';

import '../support/harness.dart';
import '../support/study_modes.dart';

Word _word(String headword, List<String> readings, {Example? example}) => Word(
  id: headword,
  headword: headword,
  readings: readings,
  meaning: '뜻',
  createdAt: DateTime(2026, 11, 12),
  pos: PartOfSpeech.naAdjective,
  example: example,
);

final AccentTable _table = AccentTable.parse(
  '雪森\tゆきもり\t2\n霧森な\tきりもりな\t1\n霧森\tきりもり\t0\n',
);

const WordSpeech _yukimori = WordSpeech(
  headword: '雪森',
  reading: 'ゆきもり',
  accents: [2],
  pos: PartOfSpeech.naAdjective,
);

void main() {
  group('E4 the word without its printed ending', () {
    test('`X だ` / `xだ` and `X な` sound as X, with its accents', () {
      expect(wordSpeechFor(_word('雪森', ['ゆきもり']), _table), _yukimori);
      for (final word in [
        _word('雪森だ', ['ゆきもりだ']),
        _word('雪森な', ['ゆきもりな']),
        _word('雪森だ', ['ゆきもり']),
      ]) {
        expect(
          wordSpeechFor(word, _table),
          _yukimori,
          reason: '${word.headword} ${word.readings}',
        );
      }
    });

    test('the pitch line has the accent the table gives', () {
      final pitch = pitchInfoFor(
        wordSpeechFor(_word('雪森だ', ['ゆきもりだ']), _table),
      );
      expect(pitch?.morae, ['ゆ', 'き', 'も', 'り']);
      expect(pitch?.accent, 2);
      expect(pitch?.estimated, isFalse);
    });

    test('the example sentence carries the same word request', () {
      final word = _word('雪森だ', [
        'ゆきもりだ',
      ], example: const Example(ja: '雪森な町です。', ko: '눈숲한 마을입니다.'));
      expect(
        exampleSpeechFor(word, _table),
        const SentenceSpeech(text: '雪森な町です。', word: _yukimori),
      );
    });
  });

  group('E5 as before', () {
    test('a word the table has with its ending keeps it', () {
      expect(
        wordSpeechFor(_word('霧森な', ['きりもりな']), _table),
        const WordSpeech(
          headword: '霧森な',
          reading: 'きりもりな',
          accents: [1],
          pos: PartOfSpeech.naAdjective,
        ),
      );
    });

    test(
      'no data with or without the ending: the word as saved, estimated',
      () {
        final speech = wordSpeechFor(_word('雲森だ', ['くももりだ']), _table);
        expect(speech.headword, '雲森だ');
        expect(speech.reading, 'くももりだ');
        expect(speech.isEstimated, isTrue);
      },
    );
  });

  group('E6 듣고 맞히기', () {
    testWidgets('the sound it plays by itself is the word without its ending', (
      tester,
    ) async {
      usePhoneSize(tester);
      final speech = RecordingSpeech();
      final blocks = TestBlocks();
      final service = LibraryService(
        library: blocks.library,
        clock: blocks.clock,
      );
      await service.addDraft(
        const CaptureDraft(
          entries: [
            CapturedEntry(
              headword: '雪森だ',
              readings: ['ゆきもりだ'],
              pos: PartOfSpeech.naAdjective,
              meaning: '눈숲하다',
            ),
            CapturedEntry(
              headword: '語二',
              readings: ['ごに'],
              pos: PartOfSpeech.noun,
              meaning: '말 둘',
            ),
            CapturedEntry(
              headword: '語三',
              readings: ['ごさん'],
              pos: PartOfSpeech.noun,
              meaning: '말 셋',
            ),
            CapturedEntry(
              headword: '語四',
              readings: ['ごよん'],
              pos: PartOfSpeech.verb,
              meaning: '말 넷',
            ),
          ],
        ),
        to: const NewPlaylist('모음'),
      );
      await blocks.preferences.save(
        const StudyPreferences(mode: StudyMode.listening),
      );
      final List<Override> extra = [
        speechProvider.overrideWithValue(speech),
        accentTableProvider.overrideWith((ref) async => _table),
      ];
      await tester.pumpWidget(app(blocks, extra: extra));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('오늘 학습 시작'));
      await tester.pumpAndSettle();

      expect(speech.requests, [_yukimori]);
      expect(find.text('雪森だ'), findsNothing);
      await tester.tap(find.byTooltip('다시 듣기'));
      await tester.pumpAndSettle();
      expect(speech.requests, [_yukimori, _yukimori]);
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
