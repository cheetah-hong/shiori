import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository repo;
  late LibraryService service;

  CapturedEntry entry(String head, {bool included = true}) => CapturedEntry(
    headword: head,
    readings: const ['よみ'],
    pos: PartOfSpeech.noun,
    meaning: '뜻',
    included: included,
  );

  CaptureDraft draft(List<CapturedEntry> entries) =>
      CaptureDraft(entries: entries);

  /// Twelve made-up words, in the order the photo shows them.
  const twelve = [
    '雨', '雪', '空', '海', '山', '川', '朝', '昼', '夜', '春', '夏', '秋', //
  ];

  setUp(() {
    repo = InMemoryLibraryRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
  });

  test('creates a textbook with a trimmed title and no layout', () async {
    final tb = await service.createTextbook('  내 단어장 ');
    expect(tb.title, '내 단어장');
    expect(tb.createdAt, now);
    expect(tb.templateId, isNull);
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

  test('saves the included words, with no number, DAY or page', () async {
    final tb = await service.createTextbook('단어장');
    final result = await service.saveDraft(
      draft([entry('雨'), entry('雪', included: false), entry('空')]),
      textbookId: tb.id,
    );
    expect((result.saved, result.skipped), (2, 1));
    expect(await repo.days(tb.id), isEmpty);
    final words = await repo.words(textbookId: tb.id);
    expect(words.map((w) => (w.headword, w.no, w.day, w.page)), [
      ('雨', null, null, null),
      ('空', null, null, null),
    ]);
    expect(words.map((w) => w.id).toSet(), hasLength(2));
    expect(words.every((w) => w.id.startsWith('${tb.id}:')), isTrue);
  });

  test('D10 a page of twelve words reads back in the photo\'s order', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(
      draft([for (final h in twelve) entry(h)]),
      textbookId: tb.id,
    );
    final words = await repo.words(textbookId: tb.id);
    expect(words.map((w) => w.headword), twelve);
    // The order is in the ids themselves, so any store sorting by id keeps it.
    final byId = [...words]..sort((a, b) => a.id.compareTo(b.id));
    expect(byId.map((w) => w.headword), twelve);
  });

  test('D10 new words are studied in the photo\'s order', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(
      draft([for (final h in twelve) entry(h)]),
      textbookId: tb.id,
    );
    final study = StudyService(
      library: repo,
      reviews: InMemoryReviewRepository(),
      scheduler: const LeitnerFourStepScheduler(),
      clock: FixedClock(now),
      settings: const StudySettings(dailyGoal: 12),
    );
    final session = await study.startSession(textbookId: tb.id);
    expect(session.queue.map((i) => i.word.headword), twelve);
  });

  test('D10 a later page comes after an earlier one', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(
      draft([for (final h in twelve.take(6)) entry(h)]),
      textbookId: tb.id,
    );
    final later = LibraryService(
      library: repo,
      clock: FixedClock(now.add(const Duration(minutes: 1))),
    );
    await later.saveDraft(
      draft([for (final h in twelve.skip(6)) entry(h)]),
      textbookId: tb.id,
    );
    expect((await repo.words()).map((w) => w.headword), twelve);
  });

  test('two pages saved at the same instant keep every word', () async {
    final tb = await service.createTextbook('단어장');
    await service.saveDraft(draft([entry('雨')]), textbookId: tb.id);
    final again = await service.saveDraft(
      draft([entry('雪')]),
      textbookId: tb.id,
    );
    expect(again.saved, 1);
    expect((await repo.words()).map((w) => w.headword), ['雨', '雪']);
  });

  test('an entry whose headword is still empty is not saved', () async {
    final tb = await service.createTextbook('단어장');
    final result = await service.saveDraft(
      draft([entry(''), entry('空')]),
      textbookId: tb.id,
    );
    expect((result.saved, result.skipped), (1, 1));
  });

  test('saving into an unknown textbook fails', () async {
    expect(
      () => service.saveDraft(draft([entry('雨')]), textbookId: 'nope'),
      throwsA(isA<LibraryException>()),
    );
  });

  test('words saved before keep their DAY and number', () async {
    final tb = await service.createTextbook('단어장');
    await repo.saveDay(
      TextbookDay(textbookId: tb.id, number: 1, title: '자연, 몸'),
    );
    await repo.saveWords([
      Word(
        id: '${tb.id}:0001',
        textbookId: tb.id,
        day: 1,
        no: '0001',
        headword: '雨',
        readings: const ['あめ'],
        meaning: '비',
        page: 10,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
    await service.saveDraft(draft([entry('雪')]), textbookId: tb.id);

    final overview = await service.overview(tb.id);
    expect(overview.wordCount, 2);
    expect(overview.days.map((d) => (d.day.title, d.words.length)), [
      ('자연, 몸', 1),
    ]);
    expect(overview.days.single.words.single.no, '0001');
    expect(overview.undated.map((w) => w.headword), ['雪']);
  });

  test('overview of an unknown textbook is a library error', () async {
    expect(() => service.overview('nope'), throwsA(isA<LibraryException>()));
    expect(const LibraryException('x').toString(), contains('x'));
  });

  test('a failed word write keeps no word', () async {
    final failing = _FailingWords();
    final service = LibraryService(library: failing, clock: FixedClock(now));
    final tb = await service.createTextbook('단어장');
    await expectLater(
      service.saveDraft(draft([entry('雨')]), textbookId: tb.id),
      throwsA(isA<StateError>()),
    );
    expect(await failing.words(), isEmpty);
  });
}

/// Fails on writing words after they were written (a full disk, say).
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
