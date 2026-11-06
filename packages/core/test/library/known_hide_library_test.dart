// Hiding words from the textbook list (LibraryService) and what the models
// say about hidden words.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 21);
  late InMemoryLibraryRepository repo;
  late LibraryService service;

  /// Words of [textbookId] as earlier app versions saved them: numbered,
  /// on a DAY (or none).
  Future<void> put(
    String textbookId, {
    int? day,
    required List<(String, String)> words,
  }) => repo.saveWords([
    for (final (no, head) in words)
      Word(
        id: '$textbookId:$no',
        textbookId: textbookId,
        day: day,
        no: no,
        headword: head,
        readings: const ['よみ'],
        meaning: '뜻',
        createdAt: now,
      ),
  ]);

  setUp(() async {
    repo = InMemoryLibraryRepository();
    service = LibraryService(library: repo, clock: FixedClock(now));
  });

  test(
    'hideWords and unhideWords use the clock and the library block',
    () async {
      expect(service.hidden, same(repo));
      final tb = await service.createTextbook('단어장');
      await put(tb.id, day: 1, words: [('0001', '雨'), ('0002', '雪')]);
      await service.hideWords(['${tb.id}:0002']);
      expect((await repo.word('${tb.id}:0002'))?.hiddenAt, now);
      await service.unhideWords(['${tb.id}:0002']);
      expect((await repo.word('${tb.id}:0002'))?.isHidden, isFalse);
    },
  );

  test('an unknown word id is reported, not skipped', () async {
    await expectLater(
      service.hideWords(['nope']),
      throwsA(isA<WordNotFoundException>()),
    );
    await expectLater(
      service.unhideWords(['nope']),
      throwsA(isA<WordNotFoundException>()),
    );
  });

  test('the overview keeps hidden words and says which they are', () async {
    final tb = await service.createTextbook('단어장');
    await put(
      tb.id,
      day: 1,
      words: [('0001', '雨'), ('0002', '雪'), ('0003', '風')],
    );
    await put(tb.id, day: 2, words: [('0004', '山')]);
    await put(tb.id, words: [('0005', '川')]);
    await service.hideWords([
      '${tb.id}:0002',
      '${tb.id}:0004',
      '${tb.id}:0005',
    ]);

    final overview = await service.overview(tb.id);
    expect(overview.wordCount, 5, reason: 'every word, hidden ones too');
    expect(overview.hiddenCount, 3);
    expect(overview.shownCount, 2);
    expect(overview.hiddenWords.map((w) => w.headword), ['雪', '山', '川']);
    expect(overview.days.map((d) => d.day.number), [1, 2]);
    expect(overview.days.first.words.map((w) => w.headword), ['雨', '雪', '風']);
    expect(overview.days.first.shownWords.map((w) => w.headword), ['雨', '風']);
    expect(overview.days.last.shownWords, isEmpty);
  });

  test('nothing hidden: the overview counts as before', () async {
    final tb = await service.createTextbook('단어장');
    await put(tb.id, day: 1, words: [('0001', '雨')]);
    final overview = await service.overview(tb.id);
    expect((overview.hiddenCount, overview.shownCount), (0, 1));
    expect(overview.hiddenWords, isEmpty);
  });

  group('models', () {
    Word w({DateTime? hiddenAt}) => Word(
      id: 'w',
      textbookId: 'tb',
      headword: '雨',
      readings: const ['あめ'],
      meaning: '비',
      createdAt: now,
      hiddenAt: hiddenAt,
    );

    test('Word tells hidden from shown and compares the time', () {
      expect(w().isHidden, isFalse);
      expect(w(hiddenAt: now).isHidden, isTrue);
      expect(w(hiddenAt: now), w(hiddenAt: now));
      expect(w(hiddenAt: now).hashCode, w(hiddenAt: now).hashCode);
      expect(w(hiddenAt: now), isNot(w()));
      expect(w().withHiddenAt(now), w(hiddenAt: now));
      expect(w(hiddenAt: now).withHiddenAt(null), w());
      expect(w(hiddenAt: now).toString(), contains('hidden'));
    });

    test('TextbookStats counts hidden words apart', () {
      final book = Textbook(id: 'a', title: 'A', createdAt: now);
      TextbookStats s({int hidden = 1}) => TextbookStats(
        textbook: book,
        wordCount: 5,
        days: const [1],
        hiddenCount: hidden,
      );
      expect(s().shownCount, 4);
      expect(s(), s());
      expect(s().hashCode, s().hashCode);
      expect(s(), isNot(s(hidden: 2)));
      expect(
        TextbookStats(textbook: book, wordCount: 2, days: const []).hiddenCount,
        0,
      );
      expect(s().toString(), contains('hidden: 1'));
    });

    test('WordNotFoundException names the ids', () {
      expect(
        const WordNotFoundException(['a', 'b']).toString(),
        allOf(contains('a'), contains('b')),
      );
    });
  });
}
