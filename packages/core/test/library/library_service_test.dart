import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository repo;
  late LibraryService service;

  CapturedEntry entry(String no, String head, {bool included = true}) =>
      CapturedEntry(
        no: no,
        headword: head,
        readings: const ['よみ'],
        pos: PartOfSpeech.noun,
        meaning: '뜻',
        important: false,
        included: included,
      );

  CaptureDraft draft(
    List<CapturedEntry> entries, {
    PageMeta meta = const PageMeta(day: 1, title: '자연, 몸', page: 10),
  }) => CaptureDraft(templateId: 'vocab.list', meta: meta, entries: entries);

  setUp(() {
    repo = InMemoryLibraryRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
  });

  test('creates a textbook with a trimmed title', () async {
    final tb = await service.createTextbook(
      '  JLPT 단어장 ',
      templateId: 'vocab.list',
    );
    expect(tb.title, 'JLPT 단어장');
    expect(tb.createdAt, now);
    expect(await repo.textbook(tb.id), tb);
  });

  test('refuses an empty textbook title', () async {
    expect(
      () => service.createTextbook('   '),
      throwsA(isA<LibraryException>()),
    );
  });

  test('two textbooks created at the same instant get different ids', () async {
    final a = await service.createTextbook('A');
    final b = await service.createTextbook('B');
    expect(a.id, isNot(b.id));
  });

  test('saves the DAY and the included words with their page', () async {
    final tb = await service.createTextbook('단어장');
    final result = await service.saveDraft(
      draft([
        entry('0001', '雨'),
        entry('0002', '雪', included: false),
        entry('0003', '空'),
      ]),
      textbookId: tb.id,
    );
    expect((result.added, result.updated, result.skipped), (2, 0, 1));
    expect((await repo.days(tb.id)).single.title, '자연, 몸');
    final words = await repo.words(textbookId: tb.id);
    expect(words.map((w) => (w.id, w.day, w.page)), [
      ('${tb.id}:0001', 1, 10),
      ('${tb.id}:0003', 1, 10),
    ]);
  });

  test(
    'saving the same page again updates words and keeps when they were added',
    () async {
      final tb = await service.createTextbook('단어장');
      await service.saveDraft(draft([entry('0001', 'ー')]), textbookId: tb.id);
      final later = LibraryService(
        library: repo,
        clock: FixedClock(now.add(const Duration(days: 1))),
      );
      final result = await later.saveDraft(
        draft([entry('0001', '雨')]),
        textbookId: tb.id,
      );
      expect((result.added, result.updated), (0, 1));
      final w = (await repo.words()).single;
      expect((w.headword, w.createdAt), ('雨', now));
    },
  );

  test('entries without a number still get distinct ids', () async {
    final tb = await service.createTextbook('단어장');
    final noNumber = entry('x', '何').copyWith(no: null);
    await service.saveDraft(
      draft([noNumber, noNumber.copyWith(headword: '誰')], meta: PageMeta.empty),
      textbookId: tb.id,
    );
    final words = await repo.words();
    expect(words.map((w) => w.id).toSet().length, 2);
    expect(words.every((w) => w.day == null), isTrue);
    expect(await repo.days(tb.id), isEmpty);
  });

  test('an entry whose headword is still empty is not saved', () async {
    final tb = await service.createTextbook('단어장');
    final result = await service.saveDraft(
      draft([entry('0002', ''), entry('0003', '空')]),
      textbookId: tb.id,
    );
    expect((result.added, result.skipped, result.saved), (1, 1, 1));
  });

  test(
    'a later page without a DAY title keeps the title read earlier',
    () async {
      final tb = await service.createTextbook('단어장');
      await service.saveDraft(draft([entry('0001', '雨')]), textbookId: tb.id);
      await service.saveDraft(
        draft([entry('0013', '海')], meta: const PageMeta(day: 1, page: 11)),
        textbookId: tb.id,
      );
      expect((await repo.days(tb.id)).single.title, '자연, 몸');
    },
  );

  test('saving into an unknown textbook fails', () async {
    expect(
      () => service.saveDraft(draft([entry('0001', '雨')]), textbookId: 'nope'),
      throwsA(isA<LibraryException>()),
    );
  });

  test('two rows with the same number in one page are both kept', () async {
    final tb = await service.createTextbook('단어장');
    final result = await service.saveDraft(
      draft([entry('0009', '九'), entry('0009', '十')]),
      textbookId: tb.id,
    );
    expect((result.added, result.saved), (2, 2));
    expect(
      (await repo.words()).map((w) => w.headword),
      unorderedEquals(['九', '十']),
    );
  });

  test('a DAY whose words moved to another DAY is not listed', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(draft([entry('0001', '雨')]), textbookId: tb.id);
    await service.saveDraft(
      draft([
        entry('0001', '雨'),
      ], meta: const PageMeta(day: 2, title: '둘', page: 12)),
      textbookId: tb.id,
    );
    final overview = await service.overview(tb.id);
    expect(overview.days.map((d) => d.day.number), [2]);
  });

  test('overview of an unknown textbook is a library error', () async {
    expect(() => service.overview('nope'), throwsA(isA<LibraryException>()));
    expect(const LibraryException('x').toString(), contains('x'));
  });

  test('textbook overview counts words per day', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(
      draft([entry('0001', '雨'), entry('0002', '雪')]),
      textbookId: tb.id,
    );
    await service.saveDraft(
      draft([
        entry('0031', '朝'),
      ], meta: const PageMeta(day: 2, title: '시간', page: 14)),
      textbookId: tb.id,
    );
    final overview = await service.overview(tb.id);
    expect(overview.wordCount, 3);
    expect(overview.days.map((d) => (d.day.number, d.words.length)), [
      (1, 2),
      (2, 1),
    ]);
  });

  test('a failed word write keeps neither the DAY nor any word', () async {
    final failing = _FailingWords();
    final service = LibraryService(library: failing, clock: FixedClock(now));
    final tb = await service.createTextbook('단어장');
    await expectLater(
      service.saveDraft(draft([entry('0001', '雨')]), textbookId: tb.id),
      throwsA(isA<StateError>()),
    );
    expect(await failing.days(tb.id), isEmpty);
    expect(await failing.words(), isEmpty);
  });
}

/// Fails on writing words after the DAY was written (a full disk, say).
final class _FailingWords extends _Delegating {
  @override
  Future<void> saveWords(List<Word> words) async {
    await super.saveWords(words);
    throw StateError('disk full');
  }
}

base class _Delegating implements LibraryRepository {
  final _inner = InMemoryLibraryRepository();

  @override
  Future<List<Textbook>> textbooks() => _inner.textbooks();

  @override
  Future<Textbook?> textbook(String id) => _inner.textbook(id);

  @override
  Future<void> saveTextbook(Textbook textbook) => _inner.saveTextbook(textbook);

  @override
  Future<List<TextbookDay>> days(String textbookId) => _inner.days(textbookId);

  @override
  Future<void> saveDay(TextbookDay day) => _inner.saveDay(day);

  @override
  Future<List<Word>> words({String? textbookId, int? day}) =>
      _inner.words(textbookId: textbookId, day: day);

  @override
  Future<Word?> word(String id) => _inner.word(id);

  @override
  Future<List<TextbookStats>> textbookStats() => _inner.textbookStats();

  @override
  Future<void> saveWords(List<Word> words) => _inner.saveWords(words);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      _inner.transaction(action);
}
