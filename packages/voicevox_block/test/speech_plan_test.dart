import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

const _chopsticks = WordSpeech(headword: '箸', reading: 'はし', accents: [1]);
const _bridge = WordSpeech(headword: '橋', reading: 'はし', accents: [2, 1]);
const _edge = WordSpeech(headword: '端', reading: 'はし', accents: [0]);

void main() {
  group('a word with accent data', () {
    test('becomes VOICEVOX kana with the first accent', () {
      expect(planSpeech(_chopsticks), isA<KanaPlan>());
      expect((planSpeech(_chopsticks) as KanaPlan).kana, "ハ'シ");
      expect((planSpeech(_bridge) as KanaPlan).kana, "ハシ'");
      expect((planSpeech(_edge) as KanaPlan).kana, "ハシ'");
    });

    test('uses the pronunciation of the reading', () {
      const today = WordSpeech(headword: '今日', reading: 'きょう', accents: [1]);
      expect((planSpeech(today) as KanaPlan).kana, "キョ'オ");
      const think = WordSpeech(
        headword: '思う',
        reading: 'おもう',
        accents: [2],
        pos: PartOfSpeech.verb,
      );
      expect((planSpeech(think) as KanaPlan).kana, "オモ'ウ");
    });

    test('an accent past the reading falls back to the estimate', () {
      const odd = WordSpeech(headword: '箸', reading: 'はし', accents: [5]);
      expect(planSpeech(odd), isA<EstimatePlan>());
    });
  });

  group('a word without accent data', () {
    test('lets the engine read the form, then the reading', () {
      const word = WordSpeech(headword: '雲', reading: 'くも');
      final plan = planSpeech(word) as EstimatePlan;
      expect(plan.texts, ['雲', 'くも']);
      expect(plan.expectedMorae, ['ク', 'モ']);
    });

    test('a kana word is read once', () {
      const word = WordSpeech(headword: 'ふわり', reading: 'ふわり');
      expect((planSpeech(word) as EstimatePlan).texts, ['ふわり']);
    });

    test('a reading that is not kana leaves only the form', () {
      const word = WordSpeech(headword: '雲', reading: '雲', accents: [1]);
      final plan = planSpeech(word) as EstimatePlan;
      expect(plan.texts, ['雲']);
      expect(plan.expectedMorae, isEmpty);
    });
  });

  group('an example sentence', () {
    test('fixes the word when the sentence has it before kana', () {
      final plan =
          planSpeech(const SentenceSpeech(text: '箸で食べます。', word: _chopsticks))
              as SentencePlan;
      expect(plan.text, '箸で食べます。');
      expect(plan.fixMorae, ['ハ', 'シ']);
      expect(plan.fixAccent, 1);
    });

    test('fixes the word at the end or before punctuation', () {
      for (final text in ['あれは橋', 'あれは橋。', '橋、川、山']) {
        final plan =
            planSpeech(SentenceSpeech(text: text, word: _bridge))
                as SentencePlan;
        expect(plan.fixAccent, 2, reason: text);
      }
    });

    test('does not fix the word inside a longer word', () {
      for (final text in ['橋脚を見た。', '端末を買った。', '歩道橋パネル']) {
        final word = text.contains('端') ? _edge : _bridge;
        final plan =
            planSpeech(SentenceSpeech(text: text, word: word)) as SentencePlan;
        expect(plan.fixMorae, isNull, reason: text);
        expect(plan.fixAccent, isNull, reason: text);
      }
    });

    test('does not fix a word without accent data or not in the sentence', () {
      const cloud = WordSpeech(headword: '雲', reading: 'くも');
      final a =
          planSpeech(const SentenceSpeech(text: '雲が白い。', word: cloud))
              as SentencePlan;
      expect(a.fixAccent, isNull);
      final b =
          planSpeech(const SentenceSpeech(text: '雨が降る。', word: _chopsticks))
              as SentencePlan;
      expect(b.fixAccent, isNull);
    });
  });

  test('plans that sound different have different keys', () {
    final keys = {
      planSpeech(_chopsticks).key,
      planSpeech(_bridge).key,
      planSpeech(const WordSpeech(headword: '雲', reading: 'くも')).key,
      planSpeech(const SentenceSpeech(text: '箸で食べます。', word: _chopsticks)).key,
      planSpeech(const SentenceSpeech(text: '箸で食べます。', word: _edge)).key,
    };
    expect(keys, hasLength(5));
    // Same sound, same key: a flat and a tail-accented two-mora word said alone.
    expect(planSpeech(_edge).key, planSpeech(_bridge).key);
  });
}
