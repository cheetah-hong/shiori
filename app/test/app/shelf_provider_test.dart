// The home shelf reads every textbook's word count and days in one call,
// not one word list per textbook. Synthetic sample pages only.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/harness.dart';

/// Counts the reads the shelf could make.
final class _CountingLibrary implements LibraryRepository {
  final inner = InMemoryLibraryRepository();
  int wordsCalls = 0;
  int statsCalls = 0;

  void reset() => wordsCalls = statsCalls = 0;

  @override
  Future<List<Word>> words({String? textbookId, int? day}) {
    wordsCalls++;
    return inner.words(textbookId: textbookId, day: day);
  }

  @override
  Future<List<TextbookStats>> textbookStats() {
    statsCalls++;
    return inner.textbookStats();
  }

  @override
  Future<List<Textbook>> textbooks() => inner.textbooks();

  @override
  Future<Textbook?> textbook(String id) => inner.textbook(id);

  @override
  Future<void> saveTextbook(Textbook textbook) => inner.saveTextbook(textbook);

  @override
  Future<List<TextbookDay>> days(String textbookId) => inner.days(textbookId);

  @override
  Future<void> saveDay(TextbookDay day) => inner.saveDay(day);

  @override
  Future<Word?> word(String id) => inner.word(id);

  @override
  Future<void> saveWords(List<Word> words) => inner.saveWords(words);

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      inner.transaction(action);
}

/// Two sample pages (DAY 1 and DAY 20) in one textbook, and an empty one.
Future<(Textbook, Textbook)> _seed(TestBlocks blocks) async {
  final full = await blocks.seedPage('s010');
  await blocks.seedPage('s140');
  final empty = await LibraryService(
    library: blocks.library,
    clock: blocks.clock,
  ).createTextbook('빈 교재');
  return (full, empty);
}

void main() {
  test('one stats read and no word lists', () async {
    final library = _CountingLibrary();
    final blocks = TestBlocks(library: library);
    final (full, empty) = await _seed(blocks);
    library.reset();

    final container = ProviderContainer.test(overrides: blocks.overrides);
    final shelf = await container.read(shelfProvider.future);

    expect(library.wordsCalls, 0);
    expect(library.statsCalls, 1);
    final words = await library.inner.words(textbookId: full.id);
    expect(shelf.map((i) => i.textbook), [full, empty]);
    expect(shelf.map((i) => i.wordCount), [words.length, 0]);
    expect(shelf.map((i) => i.days), [
      [1, 20],
      isEmpty,
    ]);
  });

  testWidgets('the home cards show the same count and days', (tester) async {
    usePhoneSize(tester);
    final library = _CountingLibrary();
    final blocks = TestBlocks(library: library);
    final (full, _) = await _seed(blocks);
    final count = (await library.inner.words(textbookId: full.id)).length;
    library.reset();

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('DAY 1–20 · 단어 $count개'), findsOneWidget);
    expect(find.text('단어 0개'), findsOneWidget);
    expect(find.text('빈 교재'), findsOneWidget);
    expect(find.text('단어 $count개'), findsWidgets, reason: 'shelf total');
    expect(library.statsCalls, greaterThan(0));
  });
}
