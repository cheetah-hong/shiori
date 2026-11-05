// Behaviour tests for hiding words the learner already knows (이미 알아요),
// run against every storage block from hidden_words_contract_test.dart, so
// the in-memory block and the SQLite block mean the same thing.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import 'repository_contract.dart';

/// A storage block whose library can also hide words.
abstract interface class HidingStorageUnderTest implements StorageUnderTest {
  HiddenWordRepository get hidden;
}

void hiddenWordsContract(
  String name,
  FutureOr<HidingStorageUnderTest> Function() open,
) {
  group('$name hidden words', () {
    late HidingStorageUnderTest storage;
    LibraryRepository lib() => storage.library;
    ReviewRepository rev() => storage.reviews;
    HiddenWordRepository hid() => storage.hidden;

    setUp(() async {
      storage = await open();
      await lib().saveTextbook(_book('tb'));
      await lib().saveTextbook(
        _book('tb2', at: _t0.add(const Duration(days: 1))),
      );
      await lib().saveWords([
        _word('a', day: 1, no: '0001'),
        _word('b', day: 1, no: '0002'),
        _word('c', day: 2, no: '0003'),
        _word('d'),
        _word('e', tb: 'tb2', day: 1, no: '0001'),
      ]);
    });
    tearDown(() => storage.close());

    _hideAndShow(lib, hid);
    _reads(lib, hid);
    _stats(lib, hid);
    _study(lib, rev, hid);
    _allOrNone(lib, rev, hid);
  });
}

// Local times with microseconds, the shape the app's clock gives.
final _t0 = DateTime(2026, 11, 5, 9, 30, 15, 123, 456);
final _hideAt = DateTime(2026, 11, 5, 22, 10, 0, 0, 7);

Textbook _book(String id, {DateTime? at}) =>
    Textbook(id: id, title: '단어장', createdAt: at ?? _t0);

Word _word(String id, {String tb = 'tb', int? day, String? no}) => Word(
  id: id,
  textbookId: tb,
  day: day,
  no: no,
  headword: '語$id',
  readings: const ['ご'],
  meaning: '말 $id',
  createdAt: _t0,
);

ReviewCard _card(String id, {required int level, required DateTime dueAt}) =>
    ReviewCard(
      wordId: id,
      level: level,
      dueAt: dueAt,
      lastReviewedAt: _t0,
      reviewCount: 2,
      lapseCount: 1,
    );

ReviewLog _log(String id) => ReviewLog(
  wordId: id,
  answer: Answer.known,
  at: _t0,
  levelBefore: 1,
  levelAfter: 2,
  retriesInSession: 0,
);

Future<List<String>> _ids(Future<List<Word>> words) async => [
  for (final w in await words) w.id,
];

// ---------------------------------------------------------------- H2

void _hideAndShow(
  LibraryRepository Function() lib,
  HiddenWordRepository Function() hid,
) {
  group('hide and show', () {
    test('hiding a word stores the state and the time', () async {
      await hid().hideWords(['b'], at: _hideAt);
      final b = await lib().word('b');
      expect(b?.isHidden, isTrue);
      expect(b?.hiddenAt, _hideAt);
      expect((await lib().word('a'))?.isHidden, isFalse);
      expect((await lib().word('a'))?.hiddenAt, isNull);
    });

    test('showing it again clears the state', () async {
      await hid().hideWords(['b'], at: _hideAt);
      await hid().unhideWords(['b']);
      final b = await lib().word('b');
      expect(b?.isHidden, isFalse);
      expect(b?.hiddenAt, isNull);
      expect(b, _word('b', day: 1, no: '0002'));
    });

    test('hiding twice is the same as hiding once', () async {
      await hid().hideWords(['b'], at: _hideAt);
      await hid().hideWords(['b'], at: _hideAt.add(const Duration(hours: 1)));
      await hid().hideWords([
        'b',
        'b',
      ], at: _hideAt.add(const Duration(days: 1)));
      expect((await lib().word('b'))?.hiddenAt, _hideAt);
      expect(await _ids(hid().hiddenWords()), ['b']);
    });

    test('showing a word that is not hidden changes nothing', () async {
      await hid().unhideWords(['a']);
      expect(await lib().word('a'), _word('a', day: 1, no: '0001'));
    });

    test('no ids: nothing happens', () async {
      await hid().hideWords(const [], at: _hideAt);
      await hid().unhideWords(const []);
      expect(await hid().hiddenWords(), isEmpty);
    });

    test('an unknown id is an error that names it', () async {
      await expectLater(
        hid().hideWords(['zz'], at: _hideAt),
        throwsA(
          isA<WordNotFoundException>().having((e) => e.wordIds, 'wordIds', [
            'zz',
          ]),
        ),
      );
      await expectLater(
        hid().unhideWords(['yy']),
        throwsA(
          isA<WordNotFoundException>().having((e) => e.wordIds, 'wordIds', [
            'yy',
          ]),
        ),
      );
    });

    test('many words at once', () async {
      final ids = [for (var i = 0; i < 1200; i++) 'm$i'];
      await lib().saveWords([for (final id in ids) _word(id)]);
      await hid().hideWords(ids, at: _hideAt);
      expect((await hid().hiddenWords()).length, 1200);
      await hid().unhideWords(ids);
      expect(await hid().hiddenWords(), isEmpty);
    });
  });
}

// ---------------------------------------------------------------- H3

void _reads(
  LibraryRepository Function() lib,
  HiddenWordRepository Function() hid,
) {
  group('reads', () {
    test(
      'words() still returns hidden words, told apart by the field',
      () async {
        await hid().hideWords(['b', 'e'], at: _hideAt);
        final words = await lib().words();
        expect(words.map((w) => w.id), ['a', 'b', 'c', 'd', 'e']);
        expect(
          {for (final w in words) w.id: w.isHidden},
          {'a': false, 'b': true, 'c': false, 'd': false, 'e': true},
        );
        expect(
          (await lib().words(textbookId: 'tb', day: 1)).map((w) => w.isHidden),
          [false, true],
        );
      },
    );

    test('hiddenWords() returns only hidden words, in words() order', () async {
      await hid().hideWords(['e', 'd', 'a'], at: _hideAt);
      expect(await _ids(hid().hiddenWords()), ['a', 'd', 'e']);
      expect(await _ids(hid().hiddenWords(textbookId: 'tb')), ['a', 'd']);
      expect(await _ids(hid().hiddenWords(textbookId: 'tb2')), ['e']);
      expect(await hid().hiddenWords(textbookId: 'none'), isEmpty);
      final hidden = await hid().hiddenWords();
      expect(hidden.every((w) => w.hiddenAt == _hideAt), isTrue);
      expect(() => hidden.clear(), throwsUnsupportedError);
    });

    test('saving a hidden word again keeps it hidden', () async {
      await hid().hideWords(['b'], at: _hideAt);
      final edited = Word(
        id: 'b',
        textbookId: 'tb',
        day: 1,
        no: '0002',
        headword: '語b',
        readings: const ['ご'],
        meaning: '말 b (고침)',
        createdAt: _t0,
      );
      await lib().saveWords([edited]);
      final b = await lib().word('b');
      expect(b?.meaning, '말 b (고침)');
      expect(b?.hiddenAt, _hideAt);
    });

    test('saveWords never hides: a new word is stored shown', () async {
      await lib().saveWords([_word('n').withHiddenAt(_hideAt)]);
      expect((await lib().word('n'))?.isHidden, isFalse);
      await lib().saveWords([_word('a').withHiddenAt(_hideAt)]);
      expect((await lib().word('a'))?.isHidden, isFalse);
    });

    test('a hide inside a failed transaction is undone', () async {
      await expectLater(
        lib().transaction(() async {
          await hid().hideWords(['a'], at: _hideAt);
          expect((await lib().word('a'))?.isHidden, isTrue);
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect((await lib().word('a'))?.isHidden, isFalse);
    });
  });
}

// ---------------------------------------------------------------- H5

void _stats(
  LibraryRepository Function() lib,
  HiddenWordRepository Function() hid,
) {
  group('textbook stats', () {
    test('counts every word and says how many are hidden', () async {
      await hid().hideWords(['a', 'c', 'd'], at: _hideAt);
      final stats = await lib().textbookStats();
      expect(stats.map((s) => s.textbook.id), ['tb', 'tb2']);
      expect(stats.map((s) => s.wordCount), [4, 1]);
      expect(stats.map((s) => s.hiddenCount), [3, 0]);
      expect(stats.map((s) => s.shownCount), [1, 1]);
      expect(stats.first.days, [1, 2], reason: 'day 2 holds only hidden words');
    });

    test('agrees with words() and hiddenWords()', () async {
      await hid().hideWords(['b', 'e'], at: _hideAt);
      for (final s in await lib().textbookStats()) {
        final id = s.textbook.id;
        expect(s.wordCount, (await lib().words(textbookId: id)).length);
        expect(s.hiddenCount, (await hid().hiddenWords(textbookId: id)).length);
      }
    });

    test('showing again brings the count back', () async {
      await hid().hideWords(['a'], at: _hideAt);
      await hid().unhideWords(['a']);
      expect((await lib().textbookStats()).map((s) => s.hiddenCount), [0, 0]);
    });
  });
}

// ---------------------------------------------------------------- H4, H5 through the use cases

void _study(
  LibraryRepository Function() lib,
  ReviewRepository Function() rev,
  HiddenWordRepository Function() hid,
) {
  group('study', () {
    final now = DateTime(2026, 11, 5, 21);

    StudyService study({int goal = 10}) => StudyService(
      library: lib(),
      reviews: rev(),
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(now),
      settings: StudySettings(dailyGoal: goal),
      hidden: hid(),
    );

    // a: due review, b: review not due yet, c: due review, d and e: new.
    Future<Map<String, ReviewCard>> seedCards() async {
      final cards = {
        'a': _card(
          'a',
          level: 2,
          dueAt: now.subtract(const Duration(hours: 2)),
        ),
        'b': _card('b', level: 3, dueAt: now.add(const Duration(days: 5))),
        'c': _card(
          'c',
          level: 1,
          dueAt: now.subtract(const Duration(hours: 1)),
        ),
      };
      for (final c in cards.values) {
        await rev().saveCard(c);
      }
      await rev().addLog(_log('a'));
      await rev().addLog(_log('c'));
      return cards;
    }

    test('hidden due and new words stay out of the session', () async {
      await seedCards();
      await hid().hideWords(['a', 'd'], at: _hideAt);
      final session = await study().startSession();
      expect(session.queue.map((i) => i.word.id), ['c', 'e']);
      expect(session.total, 2);
    });

    test(
      'hiding keeps the card and the log; showing brings them back',
      () async {
        final cards = await seedCards();
        final logs = (await rev().logs()).length;
        await hid().hideWords(['a', 'c'], at: _hideAt);
        expect(await rev().cards(), cards);
        expect((await rev().logs()).length, logs);

        await hid().unhideWords(['a', 'c']);
        final session = await study().startSession();
        expect(session.queue.map((i) => i.word.id).take(2), ['a', 'c']);
        expect(session.queue.first.before, cards['a']);
        expect(session.queue[1].before, cards['c']);
      },
    );

    test('the summary leaves hidden words out of what to study', () async {
      await seedCards();
      await hid().hideWords(['a', 'e'], at: _hideAt);
      final summary = await study().summary();
      expect(
        (summary.dueCount, summary.newCount, summary.wordCount),
        (1, 1, 5),
      );
      expect(summary.hiddenCount, 2);
      final tb = await study().summary(textbookId: 'tb');
      expect((tb.dueCount, tb.newCount, tb.hiddenCount), (1, 1, 1));
    });

    test('이미 알아요 in a session hides the word and moves on', () async {
      final cards = await seedCards();
      final service = study();
      final session = await service.startSession();
      expect(session.current?.word.id, 'a');

      final next = await service.hide(session);
      expect(next.current?.word.id, 'c');
      expect(next.total, session.total - 1);
      expect((await lib().word('a'))?.hiddenAt, now);
      expect(await rev().cards(), cards);
      expect((await rev().logs()).length, 2);

      final back = await service.unhide(next, session.current!);
      expect(back.current?.word.id, 'a');
      expect(back.total, session.total);
      expect((await lib().word('a'))?.isHidden, isFalse);
      expect(await rev().cards(), cards);
    });

    test('capturing the page again keeps a word hidden', () async {
      final library = LibraryService(
        library: lib(),
        clock: FixedClock(now),
        hidden: hid(),
      );
      final tb = await library.createTextbook('단어장');
      CaptureDraft page(String meaning) => CaptureDraft(
        templateId: 'vocab.list',
        meta: const PageMeta(day: 1, title: '자연', page: 10),
        entries: [
          for (final (no, head) in [('0001', '雨'), ('0002', '雪')])
            CapturedEntry(
              no: no,
              headword: head,
              readings: const ['よみ'],
              pos: PartOfSpeech.noun,
              meaning: meaning,
            ),
        ],
      );
      await library.saveDraft(page('비'), textbookId: tb.id);
      await library.hideWords(['${tb.id}:0001']);
      final again = await library.saveDraft(page('비 (고침)'), textbookId: tb.id);
      expect((again.added, again.updated), (0, 2));
      final rain = await lib().word('${tb.id}:0001');
      expect(rain?.meaning, '비 (고침)');
      expect(rain?.hiddenAt, now);
      expect((await lib().word('${tb.id}:0002'))?.isHidden, isFalse);
    });
  });
}

// ---------------------------------------------------------------- H7

void _allOrNone(
  LibraryRepository Function() lib,
  ReviewRepository Function() rev,
  HiddenWordRepository Function() hid,
) {
  group('a failed hide', () {
    test('hides none of the words and leaves cards and logs alone', () async {
      final card = _card('a', level: 2, dueAt: _t0);
      await rev().saveCard(card);
      await rev().addLog(_log('a'));
      await expectLater(
        hid().hideWords(['a', 'b', 'zz'], at: _hideAt),
        throwsA(isA<WordNotFoundException>()),
      );
      expect(await hid().hiddenWords(), isEmpty);
      expect(await rev().cards(), {'a': card});
      expect((await rev().logs()).length, 1);
    });

    test('shows none of the words when an id is unknown', () async {
      await hid().hideWords(['a', 'b'], at: _hideAt);
      await expectLater(
        hid().unhideWords(['a', 'zz']),
        throwsA(isA<WordNotFoundException>()),
      );
      expect(await _ids(hid().hiddenWords()), ['a', 'b']);
    });
  });
}
