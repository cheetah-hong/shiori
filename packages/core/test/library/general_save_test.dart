// E9: words from the word extractor save as ordinary words (the saved Word
// has the same fields as before; evidence stays on the review draft).
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../extract/support/connect_fixtures.dart';
import '../extract/support/extract_fixtures.dart';

void main() {
  late InMemoryLibraryRepository library;
  late LibraryService service;

  setUp(() {
    library = InMemoryLibraryRepository();
    service = LibraryService(
      library: library,
      clock: FixedClock(DateTime(2026, 11, 6, 9)),
    );
  });

  Future<List<Word>> saveFixture(String fixture) async {
    final draft = await pageDraft(
      syntheticExtractor(),
      await loadGeneralScan(fixture),
    );
    final book = await service.createTextbook('내 단어장');
    final result = await service.saveDraft(draft, textbookId: book.id);
    expect(result.saved, draft.entries.length);
    return library.words(textbookId: book.id);
  }

  test(
    'printed words: headword, readings, part of speech, meaning; no number',
    () async {
      final words = await saveFixture('g01');

      expect(words, isNotEmpty);
      final hashiru = words.singleWhere((w) => w.headword == '走る');
      expect(hashiru.readings, ['はしる']);
      expect(hashiru.meaning, '달리다');
      expect(hashiru.pos, PartOfSpeech.verb);
      expect(hashiru.no, isNull);
      final camera = words.singleWhere((w) => w.headword == 'カメラ');
      expect(camera.readings, isEmpty);
      expect(camera.meaning, '카메라');
      // Each word got its own id although none has a number.
      expect({for (final w in words) w.id}, hasLength(words.length));
    },
  );

  test(
    'sentence words keep their sentence and translation as the example',
    () async {
      final words = await saveFixture('g02');

      final kutsu = words.singleWhere((w) => w.headword == '靴');
      expect(kutsu.example, isNotNull);
      expect(kutsu.example!.ja, contains('靴'));
      expect(kutsu.example!.ko, isNotEmpty);
      expect(kutsu.readings, ['くつ']);
    },
  );

  test('a word the learner left out is not saved', () async {
    final draft = await pageDraft(
      syntheticExtractor(),
      await loadGeneralScan('g03'),
    );
    final book = await service.createTextbook('내 단어장');
    final first = draft.entries.first;
    final edited = draft.replaceEntry(0, first.copyWith(included: false));
    final result = await service.saveDraft(edited, textbookId: book.id);

    expect(result.skipped, 1);
    expect(
      (await library.words(textbookId: book.id)).map((w) => w.headword),
      isNot(contains(first.headword)),
    );
  });
}
