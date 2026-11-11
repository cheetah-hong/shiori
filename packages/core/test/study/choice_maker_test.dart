// Multiple choice (객관식): the wrong options come from the learner's other
// words, never with the same or an overlapping meaning, the same part of
// speech first, reproducible from a seed. Made-up words.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 11, 11, 21);
  const maker = ChoiceMaker();

  Word w(String id, String meaning, {PartOfSpeech? pos}) => Word(
    id: id,
    headword: '語$id',
    readings: const ['ご'],
    meaning: meaning,
    pos: pos,
    createdAt: at,
  );

  final answer = w('a', '비', pos: PartOfSpeech.noun);

  /// Twelve words with meanings that do not overlap: six nouns, six verbs.
  final pool = [
    answer,
    for (var i = 0; i < 6; i++) w('n$i', '명사 뜻 $i', pos: PartOfSpeech.noun),
    for (var i = 0; i < 6; i++) w('v$i', '동사 뜻 $i', pos: PartOfSpeech.verb),
  ];

  group('meaningGlosses', () {
    test('splits on list marks and trims', () {
      expect(meaningGlosses(' 비 ,  강수 '), {'비', '강수'});
      expect(meaningGlosses('가다/오다'), {'가다', '오다'});
      expect(meaningGlosses('말하다; 이야기하다'), {'말하다', '이야기하다'});
      expect(meaningGlosses('하늘·공중'), {'하늘', '공중'});
      expect(meaningGlosses('넓다、크다；많다，길다'), {'넓다', '크다', '많다', '길다'});
    });

    test('leaves out notes in brackets', () {
      expect(meaningGlosses('말(언어)'), {'말'});
      expect(meaningGlosses('강수（降水）, 비'), {'강수', '비'});
      expect(meaningGlosses('[문어] 하늘'), {'하늘'});
    });

    test('collapses inner spaces', () {
      expect(meaningGlosses('표를   사다'), {'표를 사다'});
    });

    test('an empty meaning, or only a note, has no gloss', () {
      expect(meaningGlosses(''), isEmpty);
      expect(meaningGlosses('   '), isEmpty);
      expect(meaningGlosses('(설명만)'), isEmpty);
      expect(meaningGlosses(' , ; '), isEmpty);
    });
  });

  group('make', () {
    test('four options, the answer once, no word twice', () {
      final q = maker.make(answer: answer, pool: pool, seed: 7)!;
      expect(q.answer, answer);
      expect(q.options, hasLength(ChoiceMaker.optionCount));
      expect(q.options.where((o) => o.id == answer.id), hasLength(1));
      expect(q.options.map((o) => o.id).toSet(), hasLength(4));
      expect(q.options[q.answerIndex], answer);
    });

    test('no option shares or overlaps a meaning with another', () {
      final tricky = [
        answer,
        w('same', '비', pos: PartOfSpeech.noun),
        w('part', '강수, 비', pos: PartOfSpeech.noun),
        w('note', '비(내리는 것)', pos: PartOfSpeech.noun),
        w('x1', '눈', pos: PartOfSpeech.noun),
        w('x2', '눈, 시력', pos: PartOfSpeech.noun),
        w('x3', '바람', pos: PartOfSpeech.noun),
        w('x4', '구름', pos: PartOfSpeech.noun),
      ];
      for (var seed = 0; seed < 50; seed++) {
        final q = maker.make(answer: answer, pool: tricky, seed: seed)!;
        final ids = q.options.map((o) => o.id).toSet();
        expect(ids.intersection({'same', 'part', 'note'}), isEmpty);
        expect(ids.containsAll(['x1', 'x2']), isFalse, reason: 'seed $seed');
        final glosses = [
          for (final o in q.options) ...meaningGlosses(o.meaning),
        ];
        expect(glosses.toSet(), hasLength(glosses.length));
      }
    });

    test('words without a meaning are never options', () {
      final withEmpty = [
        answer,
        w('e1', ''),
        w('e2', '  '),
        w('e3', '(메모)'),
        w('k1', '하나'),
        w('k2', '둘'),
        w('k3', '셋'),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final q = maker.make(answer: answer, pool: withEmpty, seed: seed)!;
        expect(q.options.map((o) => o.id).toSet(), {'a', 'k1', 'k2', 'k3'});
      }
    });

    test('the same part of speech comes first', () {
      final mixed = [
        answer,
        w('n0', '산', pos: PartOfSpeech.noun),
        w('n1', '강', pos: PartOfSpeech.noun),
        w('n2', '바다', pos: PartOfSpeech.noun),
        for (var i = 0; i < 8; i++) w('v$i', '동사 $i', pos: PartOfSpeech.verb),
        w('u0', '모름'),
      ];
      for (var seed = 0; seed < 30; seed++) {
        final q = maker.make(answer: answer, pool: mixed, seed: seed)!;
        expect(q.options.map((o) => o.id).toSet(), {'a', 'n0', 'n1', 'n2'});
      }
    });

    test('too few of the same part of speech: the rest from others', () {
      final mixed = [
        answer,
        w('n0', '산', pos: PartOfSpeech.noun),
        for (var i = 0; i < 5; i++) w('v$i', '동사 $i', pos: PartOfSpeech.verb),
      ];
      final seen = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final ids = maker
            .make(answer: answer, pool: mixed, seed: seed)!
            .options
            .map((o) => o.id)
            .toSet();
        expect(ids, containsAll(['a', 'n0']));
        seen.addAll(ids);
      }
      expect(seen, containsAll(['v0', 'v1', 'v2', 'v3', 'v4']));
    });

    test('an answer without a part of speech takes any word', () {
      final plain = w('p', '빛');
      final q = maker.make(answer: plain, pool: [plain, ...pool], seed: 3)!;
      expect(q.options, hasLength(4));
    });

    test('fewer than three possible wrong options: no question', () {
      final small = [answer, w('k1', '하나'), w('k2', '둘'), w('k3', '비, 물')];
      expect(maker.make(answer: answer, pool: small, seed: 1), isNull);
      expect(maker.make(answer: answer, pool: [answer], seed: 1), isNull);
      expect(maker.make(answer: answer, pool: const [], seed: 1), isNull);
    });

    test('an answer without a meaning: no question', () {
      final blank = w('b', '');
      expect(
        maker.make(answer: blank, pool: [blank, ...pool], seed: 1),
        isNull,
      );
    });

    test('the pool order does not matter, the seed does', () {
      final q1 = maker.make(answer: answer, pool: pool, seed: 11)!;
      final q2 = maker.make(
        answer: answer,
        pool: pool.reversed.toList(),
        seed: 11,
      )!;
      expect(q2.options.map((o) => o.id), q1.options.map((o) => o.id));
    });

    test('the same seed gives the same question', () {
      final q1 = maker.make(answer: answer, pool: pool, seed: 42)!;
      final q2 = maker.make(answer: answer, pool: pool, seed: 42)!;
      expect(q2.options.map((o) => o.id), q1.options.map((o) => o.id));
    });

    test('seeds move the answer around and change the wrong options', () {
      final positions = <int>{};
      final sets = <String>{};
      for (var seed = 0; seed < 60; seed++) {
        final q = maker.make(answer: answer, pool: pool, seed: seed)!;
        positions.add(q.answerIndex);
        sets.add((q.options.map((o) => o.id).toList()..sort()).join(','));
      }
      expect(positions, {0, 1, 2, 3});
      expect(sets.length, greaterThan(1));
    });

    test('the pool is not changed', () {
      final copy = List.of(pool);
      maker.make(answer: answer, pool: copy, seed: 5);
      expect(copy, pool);
    });
  });

  group('canAsk', () {
    test('four words with meanings apart: yes', () {
      expect(
        maker.canAsk([w('1', '하나'), w('2', '둘'), w('3', '셋'), w('4', '넷')]),
        isTrue,
      );
      expect(maker.canAsk(pool), isTrue);
    });

    test('fewer than four words: no', () {
      expect(maker.canAsk(const []), isFalse);
      expect(maker.canAsk([w('1', '하나'), w('2', '둘'), w('3', '셋')]), isFalse);
    });

    test('words that share a meaning or have none count once or not '
        'at all', () {
      expect(
        maker.canAsk([w('1', '하나'), w('2', '하나'), w('3', '셋'), w('4', '넷')]),
        isFalse,
      );
      expect(
        maker.canAsk([w('1', '하나'), w('2', '하나, 일'), w('3', '셋'), w('4', '넷')]),
        isFalse,
      );
      expect(
        maker.canAsk([w('1', '하나'), w('2', ''), w('3', '셋'), w('4', '넷')]),
        isFalse,
      );
      expect(
        maker.canAsk([
          w('1', '하나'),
          w('2', '하나'),
          w('3', '셋'),
          w('4', '넷'),
          w('5', '다섯'),
        ]),
        isTrue,
      );
    });
  });

  group('choiceSeed', () {
    final session = DateTime.fromMicrosecondsSinceEpoch(
      1794481200000000,
      isUtc: true,
    );

    test('FNV-1a (32 bit) of "<session micros>|<word id>|<retries>"', () {
      expect(
        choiceSeed(sessionStart: session, wordId: 'w-語', retries: 0),
        3744533907,
      );
      expect(
        choiceSeed(sessionStart: session, wordId: 'w-語', retries: 1),
        3727756288,
      );
    });

    test('the same presentation gives the same seed; another retry, '
        'word or session another', () {
      final s = choiceSeed(sessionStart: session, wordId: 'a', retries: 0);
      expect(choiceSeed(sessionStart: session, wordId: 'a', retries: 0), s);
      expect(
        choiceSeed(sessionStart: session, wordId: 'b', retries: 0),
        isNot(s),
      );
      expect(
        choiceSeed(sessionStart: session, wordId: 'a', retries: 2),
        isNot(s),
      );
      expect(
        choiceSeed(
          sessionStart: session.add(const Duration(microseconds: 1)),
          wordId: 'a',
          retries: 0,
        ),
        isNot(s),
      );
    });

    test('fits in 32 bits, never negative', () {
      for (var i = 0; i < 100; i++) {
        final s = choiceSeed(sessionStart: session, wordId: 'w$i', retries: i);
        expect(s, inInclusiveRange(0, 0xffffffff));
      }
    });
  });
}
