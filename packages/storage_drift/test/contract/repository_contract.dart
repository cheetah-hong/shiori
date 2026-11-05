// One set of behaviour tests for every storage block. Each block runs it from
// its own test file (see contract_test.dart), so the in-memory block and the
// SQLite block are held to the same meaning of the repository ports.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// A fresh pair of repositories for one test.
abstract interface class StorageUnderTest {
  LibraryRepository get library;
  ReviewRepository get reviews;
  Future<void> close();
}

void repositoryContract(
  String name,
  FutureOr<StorageUnderTest> Function() open,
) {
  group('$name storage', () {
    late StorageUnderTest storage;
    LibraryRepository lib() => storage.library;
    ReviewRepository rev() => storage.reviews;

    setUp(() async => storage = await open());
    tearDown(() => storage.close());

    _libraryContract(lib);
    _textbookStatsContract(lib);
    _reviewContract(rev);
    _useCaseContract(lib, rev);
  });
}

// Local times with microseconds, the shape the app's clock gives.
final _t0 = DateTime(2026, 11, 5, 9, 30, 15, 123, 456);

Textbook _book(String id, {DateTime? at, String title = '단어장'}) =>
    Textbook(id: id, title: title, createdAt: at ?? _t0);

Word _word(
  String id, {
  String tb = 'tb',
  int? day,
  String? no,
  DateTime? at,
  List<String> readings = const [],
}) => Word(
  id: id,
  textbookId: tb,
  day: day,
  no: no,
  headword: id,
  readings: readings,
  meaning: '',
  createdAt: at ?? _t0,
);

ReviewCard _card(String id, {int level = 1}) => ReviewCard(
  wordId: id,
  level: level,
  dueAt: _t0.add(const Duration(minutes: 30)),
  lastReviewedAt: _t0,
);

ReviewLog _log(String id, DateTime at, {Answer answer = Answer.known}) =>
    ReviewLog(
      wordId: id,
      answer: answer,
      at: at,
      levelBefore: 0,
      levelAfter: 4,
      retriesInSession: 0,
    );

Object _logFields(ReviewLog l) =>
    (l.wordId, l.answer, l.at, l.levelBefore, l.levelAfter, l.retriesInSession);

void _libraryContract(LibraryRepository Function() lib) {
  group('library', () {
    setUp(() => lib().saveTextbook(_book('tb')));

    test('lists textbooks oldest first and replaces by id', () async {
      final repo = lib();
      await repo.saveTextbook(
        _book('b', at: _t0.add(const Duration(days: 1)), title: 'B'),
      );
      await repo.saveTextbook(
        _book('a', at: _t0.subtract(const Duration(days: 1))),
      );
      await repo.saveTextbook(
        _book('a', at: _t0.subtract(const Duration(days: 1)), title: 'A2'),
      );
      expect((await repo.textbooks()).map((t) => t.id), ['a', 'tb', 'b']);
      expect((await repo.textbook('a'))?.title, 'A2');
      expect(await repo.textbook('zz'), isNull);
    });

    test('a textbook reads back equal, with and without a template', () async {
      final repo = lib();
      final withTemplate = Textbook(
        id: 'tpl',
        title: '목록형',
        createdAt: _t0,
        templateId: 'vocab.list',
      );
      await repo.saveTextbook(withTemplate);
      expect(await repo.textbook('tpl'), withTemplate);
      expect(await repo.textbook('tb'), _book('tb'));
    });

    test('orders words by textbook, day and number, and filters', () async {
      final repo = lib();
      await repo.saveTextbook(
        _book('tb2', at: _t0.add(const Duration(days: 1))),
      );
      await repo.saveWords([
        _word('tb2:1', tb: 'tb2', day: 1, no: '0001'),
        _word('c', day: 2, no: '0031'),
        _word('b', day: 1, no: '0016'),
        _word('a', day: 1, no: '0001'),
        _word('y', day: 1),
        _word('x'),
        _word('w', at: _t0.subtract(const Duration(seconds: 1))),
      ]);
      expect((await repo.words()).map((w) => w.id), [
        'a',
        'b',
        'y',
        'c',
        'w',
        'x',
        'tb2:1',
      ]);
      expect((await repo.words(textbookId: 'tb', day: 1)).map((w) => w.id), [
        'a',
        'b',
        'y',
      ]);
      expect((await repo.words(day: 1)).map((w) => w.id), [
        'a',
        'b',
        'y',
        'tb2:1',
      ]);
      expect((await repo.word('c'))?.day, 2);
      expect(await repo.word('zz'), isNull);
    });

    test('a word reads back equal with every field filled', () async {
      final repo = lib();
      final full = Word(
        id: 'tb:0016',
        textbookId: 'tb',
        day: 20,
        no: '0016',
        headword: '旅行',
        readings: const ['りょこう', 'たび'],
        pos: PartOfSpeech.noun,
        meaning: '여행',
        example: const Example(ja: '旅行に行く。', ko: '여행을 간다.'),
        page: 140,
        createdAt: _t0,
      );
      await repo.saveWords([full, _word('bare')]);
      expect(await repo.word('tb:0016'), full);
      expect(await repo.word('bare'), _word('bare'));
      expect((await repo.word('tb:0016'))?.readings, ['りょこう', 'たび']);
    });

    test('saveWords replaces by id and keeps one row', () async {
      final repo = lib();
      await repo.saveWords([
        _word('a', no: '0001', readings: const ['あ']),
      ]);
      await repo.saveWords([
        _word('a', no: '0002', readings: const ['い']),
      ]);
      final words = await repo.words();
      expect(words.single.no, '0002');
      expect(words.single.readings, ['い']);
      await repo.saveWords(const []);
      expect((await repo.words()).length, 1);
    });

    test('days are ordered by number and replaced by number', () async {
      final repo = lib();
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 2, title: '둘'),
      );
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 1, title: '하나'),
      );
      await repo.saveDay(
        const TextbookDay(textbookId: 'tb', number: 1, title: '자연, 몸'),
      );
      expect((await repo.days('tb')).map((d) => (d.number, d.title)), [
        (1, '자연, 몸'),
        (2, '둘'),
      ]);
      expect(await repo.days('other'), isEmpty);
    });

    test('returned lists cannot be changed by callers', () async {
      final repo = lib();
      await repo.saveWords([_word('a')]);
      final words = await repo.words();
      expect(() => words.add(_word('b')), throwsUnsupportedError);
      expect(() => words.single.readings.add('x'), throwsUnsupportedError);
      final books = await repo.textbooks();
      expect(() => books.clear(), throwsUnsupportedError);
      final days = await repo.days('tb');
      expect(() => days.clear(), throwsUnsupportedError);
    });

    test('a time reads back as the same instant', () async {
      final repo = lib();
      final utc = DateTime.utc(2026, 11, 4, 19, 0, 0, 0, 1);
      await repo.saveWords([_word('local'), _word('utc', at: utc)]);
      expect((await repo.word('local'))?.createdAt, _t0);
      expect((await repo.word('utc'))!.createdAt.isAtSameMomentAs(utc), isTrue);
    });

    group('transaction', () {
      test('a failure leaves the library as it was', () async {
        final repo = lib();
        await repo.saveWords([_word('a', no: '0001')]);
        await expectLater(
          repo.transaction(() async {
            await repo.saveDay(
              const TextbookDay(textbookId: 'tb', number: 1, title: '하나'),
            );
            await repo.saveWords([_word('a', no: '0002'), _word('b')]);
            expect((await repo.words()).length, 2, reason: 'sees its writes');
            throw StateError('disk full');
          }),
          throwsStateError,
        );
        expect(await repo.days('tb'), isEmpty);
        expect((await repo.words()).single.no, '0001');
      });

      test('returns the value of the action and keeps its writes', () async {
        final repo = lib();
        final n = await repo.transaction(() async {
          await repo.saveWords([_word('a'), _word('b')]);
          return (await repo.words()).length;
        });
        expect(n, 2);
        expect((await repo.words()).length, 2);
      });

      test('a nested failure undoes only the nested writes', () async {
        final repo = lib();
        await repo.transaction(() async {
          await repo.saveWords([_word('a')]);
          try {
            await repo.transaction(() async {
              await repo.saveWords([_word('b')]);
              throw StateError('inner');
            });
          } on StateError {
            // The outer action goes on.
          }
        });
        expect((await repo.words()).map((w) => w.id), ['a']);
      });

      test('calls from outside wait and are not rolled back', () async {
        final repo = lib();
        final gate = Completer<void>();
        final tx = repo.transaction(() async {
          await repo.saveWords([_word('a')]);
          await gate.future;
          throw StateError('rolled back');
        });
        // Let the transaction start before the outside calls.
        await Future<void>.delayed(Duration.zero);
        final outsideWrite = repo.saveWords([_word('b')]);
        final outsideRead = repo.words();
        gate.complete();
        await expectLater(tx, throwsStateError);
        await outsideWrite;
        expect((await outsideRead).map((w) => w.id), isNot(contains('a')));
        expect((await repo.words()).map((w) => w.id), ['b']);
      });
    });
  });
}

void _textbookStatsContract(LibraryRepository Function() lib) {
  group('textbook stats', () {
    test('no textbooks: no stats', () async {
      expect(await lib().textbookStats(), isEmpty);
    });

    group('three textbooks, the second without words', () {
      setUp(() async {
        final repo = lib();
        // Saved out of order; two share a creation time (then by id).
        await repo.saveTextbook(
          _book('c', at: _t0.add(const Duration(days: 1))),
        );
        await repo.saveTextbook(_book('b', at: _t0));
        await repo.saveTextbook(_book('a', at: _t0));
        await repo.saveWords([
          _word('a1', tb: 'a', day: 2, no: '0001'),
          _word('a2', tb: 'a', day: 1, no: '0002'),
          _word('a3', tb: 'a', day: 2, no: '0003'),
          _word('c1', tb: 'c', day: 3, no: '0001'),
          _word('c2', tb: 'c'),
        ]);
      });

      test('one row per textbook, in the order of textbooks()', () async {
        final stats = await lib().textbookStats();
        expect(stats.map((s) => s.textbook), await lib().textbooks());
        expect(stats.map((s) => s.textbook.id), ['a', 'b', 'c']);
      });

      test('word counts include a textbook with none', () async {
        final stats = await lib().textbookStats();
        expect(stats.map((s) => s.wordCount), [3, 0, 2]);
      });

      test('days come once each, ascending; a word without a day counts but '
          'adds no day', () async {
        final stats = await lib().textbookStats();
        expect(stats.map((s) => s.days), [
          [1, 2],
          isEmpty,
          [3],
        ]);
      });

      test('agrees with words()', () async {
        final repo = lib();
        for (final s in await repo.textbookStats()) {
          final words = await repo.words(textbookId: s.textbook.id);
          expect(s.wordCount, words.length, reason: s.textbook.id);
          expect(
            s.days,
            ({for (final w in words) ?w.day}.toList()..sort()),
            reason: s.textbook.id,
          );
        }
      });

      test('returned lists cannot be changed by callers', () async {
        final stats = await lib().textbookStats();
        expect(() => stats.clear(), throwsUnsupportedError);
        expect(() => stats.first.days.add(9), throwsUnsupportedError);
      });

      test('a transaction sees its own writes', () async {
        final repo = lib();
        await repo.transaction(() async {
          await repo.saveWords([_word('b1', tb: 'b', day: 5)]);
          final stats = await repo.textbookStats();
          expect(stats[1].wordCount, 1);
          expect(stats[1].days, [5]);
        });
      });
    });
  });
}

void _reviewContract(ReviewRepository Function() rev) {
  group('reviews', () {
    test('stores cards by word id', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await repo.saveCard(_card('b'));
      await repo.saveCard(_card('a', level: 3));
      expect((await repo.card('a'))?.level, 3);
      expect(await repo.card('zz'), isNull);
      expect((await repo.cards()).keys, unorderedEquals(['a', 'b']));
      expect((await repo.cards(wordIds: ['b', 'zz'])).keys, ['b']);
      expect(await repo.cards(wordIds: const []), isEmpty);
    });

    test('a card reads back equal', () async {
      final repo = rev();
      final card = ReviewCard(
        wordId: 'tb:0001',
        level: 4,
        dueAt: _t0.add(const Duration(days: 21)),
        lastReviewedAt: _t0,
        reviewCount: 3,
        lapseCount: 2,
      );
      await repo.saveCard(card);
      expect(await repo.card('tb:0001'), card);
      expect((await repo.cards())['tb:0001'], card);
    });

    test('looks up many cards at once', () async {
      final repo = rev();
      await repo.transaction(() async {
        for (var i = 0; i < 1200; i++) {
          await repo.saveCard(_card('w$i'));
        }
      });
      final ids = [for (var i = 0; i < 1300; i++) 'w$i'];
      expect((await repo.cards(wordIds: ids)).length, 1200);
    });

    test('returned maps and lists cannot be changed by callers', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await repo.addLog(_log('a', _t0));
      final cards = await repo.cards();
      expect(() => cards.clear(), throwsUnsupportedError);
      final logs = await repo.logs();
      expect(() => logs.clear(), throwsUnsupportedError);
    });

    test('logs keep their order and fields, and filter by time', () async {
      final repo = rev();
      final logs = [
        for (final h in [1, 5, 9])
          _log(
            'w$h',
            _t0.add(Duration(hours: h)),
            answer: h == 5 ? Answer.retry : Answer.known,
          ),
      ];
      for (final l in logs) {
        await repo.addLog(l);
      }
      expect((await repo.logs()).map(_logFields), logs.map(_logFields));
      final since = await repo.logs(since: _t0.add(const Duration(hours: 5)));
      expect(since.map((l) => l.wordId), ['w5', 'w9']);
    });

    test('logs come oldest first even when added out of order', () async {
      final repo = rev();
      await repo.addLog(_log('late', _t0.add(const Duration(hours: 2))));
      await repo.addLog(_log('early', _t0));
      await repo.addLog(_log('tie', _t0));
      expect((await repo.logs()).map((l) => l.wordId), [
        'early',
        'tie',
        'late',
      ]);
    });

    test('a failed transaction keeps neither the card nor the log', () async {
      final repo = rev();
      await repo.saveCard(_card('a'));
      await expectLater(
        repo.transaction(() async {
          await repo.saveCard(_card('a', level: 4));
          await repo.saveCard(_card('b'));
          await repo.addLog(_log('a', _t0));
          throw StateError('disk full');
        }),
        throwsStateError,
      );
      expect((await repo.cards()).values, [_card('a')]);
      expect(await repo.logs(), isEmpty);
    });
  });
}

void _useCaseContract(
  LibraryRepository Function() lib,
  ReviewRepository Function() rev,
) {
  group('use cases', () {
    final now = DateTime(2026, 11, 5, 21);

    CaptureDraft page(String meaning) => CaptureDraft(
      templateId: 'vocab.list',
      meta: const PageMeta(day: 1, title: '자연, 몸', page: 10),
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

    StudyService study(DateTime at) => StudyService(
      library: lib(),
      reviews: rev(),
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(at),
    );

    test('capturing a page again keeps the learning state', () async {
      final library = LibraryService(library: lib(), clock: FixedClock(now));
      final tb = await library.createTextbook('단어장');
      await library.saveDraft(page('비'), textbookId: tb.id);

      final service = study(now);
      var session = await service.startSession();
      session = await service.answer(session, Answer.retry);
      session = await service.answer(session, Answer.known);
      final before = await rev().cards();
      expect(before.keys, unorderedEquals(['${tb.id}:0001', '${tb.id}:0002']));

      final again = await library.saveDraft(page('비 (고침)'), textbookId: tb.id);
      expect((again.added, again.updated), (0, 2));
      expect((await lib().word('${tb.id}:0001'))?.meaning, '비 (고침)');
      expect(await rev().cards(), before);
      expect((await rev().logs()).length, 2);
    });

    test('two textbooks created at once keep different ids', () async {
      final library = LibraryService(library: lib(), clock: FixedClock(now));
      final books = await Future.wait([
        library.createTextbook('A'),
        library.createTextbook('B'),
      ]);
      expect(books[0].id, isNot(books[1].id));
      expect((await lib().textbooks()).map((t) => t.title), ['A', 'B']);
    });

    test('known today follows the study day boundary (04:00)', () async {
      final library = LibraryService(library: lib(), clock: FixedClock(now));
      final tb = await library.createTextbook('단어장');
      await library.saveDraft(page('비'), textbookId: tb.id);
      final ids = ['${tb.id}:0001', '${tb.id}:0002'];
      await rev().addLog(_log(ids[0], DateTime(2026, 11, 6, 3, 59, 59)));
      await rev().addLog(_log(ids[1], DateTime(2026, 11, 6, 4)));

      final summary = await study(DateTime(2026, 11, 6, 12)).summary();
      expect(summary.knownToday, 1);
      // Before 04:00 the study day is still the previous one.
      final lateNight = await study(DateTime(2026, 11, 6, 3, 59, 59)).summary();
      expect(lateNight.knownToday, 2);
    });
  });
}
