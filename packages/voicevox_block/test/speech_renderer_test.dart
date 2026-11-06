import 'dart:io';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

import 'support/fake_ops.dart';

const _chopsticks = WordSpeech(headword: '箸', reading: 'はし', accents: [1]);
const _cloud = WordSpeech(headword: '雲', reading: 'くも');

void main() {
  late Directory dir;
  late SpeechCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('speech_renderer_test');
    cache = SpeechCache(dir: dir, maxBytes: 1 << 20);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('a word with accent data', () {
    test('is made from VOICEVOX kana and stored', () async {
      final ops = FakeOps(
        kana: {
          "ハ'シ": [
            phrase(['ハ', 'シ'], 1),
          ],
        },
      );
      final renderer = SpeechRenderer(ops: ops, cache: cache);
      final file = await renderer.render(_chopsticks);
      expect(ops.calls, ["kana ハ'シ", 'synth ハシ:1']);
      expect(SpeechCache.isWholeWav(await file.readAsBytes()), isTrue);
      expect(file.path, startsWith(dir.path));
    });

    test('the second time comes from the cache, with no engine call', () async {
      final ops = FakeOps(
        kana: {
          "ハ'シ": [
            phrase(['ハ', 'シ'], 1),
          ],
        },
      );
      final renderer = SpeechRenderer(ops: ops, cache: cache);
      final first = await renderer.render(_chopsticks);
      ops.calls.clear();
      final second = await renderer.render(_chopsticks);
      expect(ops.calls, isEmpty);
      expect(second.path, first.path);
    });

    test('a damaged cached sound is made again', () async {
      final ops = FakeOps(
        kana: {
          "ハ'シ": [
            phrase(['ハ', 'シ'], 1),
          ],
        },
      );
      final renderer = SpeechRenderer(ops: ops, cache: cache);
      final file = await renderer.render(_chopsticks);
      await file.writeAsBytes([1, 2, 3]);
      ops.calls.clear();
      final again = await renderer.render(_chopsticks);
      expect(ops.calls, ["kana ハ'シ", 'synth ハシ:1']);
      expect(SpeechCache.isWholeWav(await again.readAsBytes()), isTrue);
    });

    test('an engine failure is passed on and nothing is stored', () async {
      final ops = FakeOps(
        kana: {
          "ハ'シ": [
            phrase(['ハ', 'シ'], 1),
          ],
        },
      )..failSynthesis = StateError('engine down');
      final renderer = SpeechRenderer(ops: ops, cache: cache);
      await expectLater(renderer.render(_chopsticks), throwsStateError);
      expect(await cache.lookup(renderer.keyOf(_chopsticks)), isNull);
    });
  });

  group('a word without accent data', () {
    test(
      'uses the written form when the engine reads it as expected',
      () async {
        final ops = FakeOps(
          text: {
            '雲': [
              phrase(['ク', 'モ'], 1),
            ],
          },
        );
        await SpeechRenderer(ops: ops, cache: cache).render(_cloud);
        expect(ops.calls, ['text 雲', 'synth クモ:1']);
      },
    );

    test('falls back to the reading when the form is read otherwise', () async {
      final ops = FakeOps(
        text: {
          '雲': [
            phrase(['ウ', 'ン'], 1),
          ],
          'くも': [
            phrase(['ク', 'モ'], 2),
          ],
        },
      );
      await SpeechRenderer(ops: ops, cache: cache).render(_cloud);
      expect(ops.calls, ['text 雲', 'text くも', 'synth クモ:2']);
    });

    test(
      'estimateAccent reads the word with が, so flat and tail differ',
      () async {
        final ops = FakeOps(
          text: {
            '雲が': [
              phrase(['ク', 'モ', 'ガ'], 1),
            ],
            '空が': [
              phrase(['ソ', 'ラ', 'ガ'], 3),
            ],
            '山が': [
              phrase(['ヤ', 'マ', 'ガ'], 2),
            ],
            '道が': [
              phrase(['ミ', 'チ'], 1),
              phrase(['ガ'], 1),
            ],
          },
        );
        final renderer = SpeechRenderer(ops: ops, cache: cache);
        expect(await renderer.estimateAccent(_cloud), 1);
        expect(ops.calls, ['text 雲が']);
        expect(
          await renderer.estimateAccent(
            const WordSpeech(headword: '空', reading: 'そら'),
          ),
          0,
        );
        expect(
          await renderer.estimateAccent(
            const WordSpeech(headword: '山', reading: 'やま'),
          ),
          2,
        );
        // Two phrases: no single accent to show.
        expect(
          await renderer.estimateAccent(
            const WordSpeech(headword: '道', reading: 'みち'),
          ),
          isNull,
        );
      },
    );

    test('estimateAccent falls back to the reading, then gives up', () async {
      final renderer = SpeechRenderer(
        ops: FakeOps(
          text: {
            '雲が': [
              phrase(['ウ', 'ン', 'ガ'], 1),
            ],
            'くもが': [
              phrase(['ク', 'モ', 'ガ'], 2),
            ],
            '霧が': [
              phrase(['ム', 'ガ'], 1),
            ],
            'きりが': [
              phrase(['キ', 'ル', 'ガ'], 1),
            ],
          },
        ),
        cache: cache,
      );
      expect(await renderer.estimateAccent(_cloud), 2);
      expect(
        await renderer.estimateAccent(
          const WordSpeech(headword: '霧', reading: 'きり'),
        ),
        isNull,
      );
    });
  });

  group('an example sentence', () {
    test('keeps the word accent from the data and remakes the pitch', () async {
      final ops = FakeOps(
        text: {
          '箸で食べます。': [
            phrase(['ハ', 'シ', 'デ'], 2),
            phrase(['タ', 'ベ', 'マ', 'ス'], 3),
          ],
        },
      );
      await SpeechRenderer(
        ops: ops,
        cache: cache,
      ).render(const SentenceSpeech(text: '箸で食べます。', word: _chopsticks));
      expect(ops.calls, [
        'text 箸で食べます。',
        'pitch ハシデ:1 タベマス:3',
        'synth ハシデ:1 タベマス:3',
      ]);
    });

    test('a flat word gets the phrase length as the engine accent', () async {
      const edge = WordSpeech(headword: '端', reading: 'はし', accents: [0]);
      final ops = FakeOps(
        text: {
          '端に置く。': [
            phrase(['ハ', 'シ', 'ニ'], 1),
            phrase(['オ', 'ク'], 1),
          ],
        },
      );
      await SpeechRenderer(
        ops: ops,
        cache: cache,
      ).render(const SentenceSpeech(text: '端に置く。', word: edge));
      expect(ops.calls[1], 'pitch ハシニ:3 オク:1');
    });

    test('is read as the engine reads it when the word is not fixed', () async {
      final ops = FakeOps(
        text: {
          '雲が白い。': [
            phrase(['ク', 'モ', 'ガ'], 1),
            phrase(['シ', 'ロ', 'イ'], 2),
          ],
        },
      );
      await SpeechRenderer(
        ops: ops,
        cache: cache,
      ).render(const SentenceSpeech(text: '雲が白い。', word: _cloud));
      expect(ops.calls, ['text 雲が白い。', 'synth クモガ:1 シロイ:2']);
    });

    test('is read as is when no phrase starts with the word', () async {
      final ops = FakeOps(
        text: {
          '箸で食べます。': [
            phrase(['チョ', 'デ'], 1),
            phrase(['タ', 'ベ', 'マ', 'ス'], 3),
          ],
        },
      );
      await SpeechRenderer(
        ops: ops,
        cache: cache,
      ).render(const SentenceSpeech(text: '箸で食べます。', word: _chopsticks));
      expect(ops.calls, ['text 箸で食べます。', 'synth チョデ:1 タベマス:3']);
    });
  });

  test('the cache key depends on the voice and the plan', () {
    final a = SpeechRenderer(ops: FakeOps(), cache: cache);
    expect(a.keyOf(_chopsticks), matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a.keyOf(_chopsticks), isNot(a.keyOf(_cloud)));
    expect(a.keyOf(_chopsticks), a.keyOf(_chopsticks));
  });
}
