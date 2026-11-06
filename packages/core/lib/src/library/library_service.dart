import 'package:shiori_core/src/models/capture_draft.dart';
import 'package:shiori_core/src/models/library.dart';
import 'package:shiori_core/src/ports/clock.dart';
import 'package:shiori_core/src/ports/hidden_word_repository.dart';
import 'package:shiori_core/src/ports/repositories.dart';

/// A library request the learner can fix (empty title, textbook gone).
final class LibraryException implements Exception {
  const LibraryException(this.message);

  /// Shown to the learner as is.
  final String message;

  @override
  String toString() => 'LibraryException: $message';
}

final class SaveResult {
  const SaveResult({required this.saved, required this.skipped});

  /// New words.
  final int saved;

  /// Entries left out by the learner or without a headword.
  final int skipped;
}

final class DayOverview {
  const DayOverview({required this.day, required this.words});

  final TextbookDay day;

  /// Every word of the day, hidden ones too.
  final List<Word> words;

  /// The words that are not hidden.
  List<Word> get shownWords =>
      List.unmodifiable(words.where((w) => !w.isHidden));
}

final class TextbookOverview {
  const TextbookOverview({
    required this.textbook,
    required this.days,
    required this.undated,
  });

  final Textbook textbook;
  final List<DayOverview> days;

  /// Words whose page had no readable DAY.
  final List<Word> undated;

  /// Every word, hidden ones too.
  int get wordCount => days.fold(undated.length, (n, d) => n + d.words.length);

  /// Hidden words, in textbook order (days, then undated).
  List<Word> get hiddenWords => List.unmodifiable([
    for (final d in days) ...d.words.where((w) => w.isHidden),
    ...undated.where((w) => w.isHidden),
  ]);

  int get hiddenCount => hiddenWords.length;

  int get shownCount => wordCount - hiddenCount;
}

/// Digits of a word's position in its save (a page holds far fewer words).
const int _positionDigits = 4;

/// Library use cases: textbooks, saving a reviewed draft, browsing by DAY,
/// hiding words the learner already knows.
final class LibraryService {
  /// [hidden] defaults to [library] when that block also hides words (both
  /// stock blocks do).
  LibraryService({
    required this.library,
    required this.clock,
    HiddenWordRepository? hidden,
  }) : hidden =
           hidden ??
           switch (library) {
             final HiddenWordRepository h => h,
             _ => null,
           };

  final LibraryRepository library;
  final Clock clock;

  /// Where words are hidden; null when no block can.
  final HiddenWordRepository? hidden;

  /// Hides [wordIds] now (이미 알아요). Their cards and logs stay.
  Future<void> hideWords(Iterable<String> wordIds) =>
      _hidden.hideWords(wordIds, at: clock.now());

  /// Shows [wordIds] again.
  Future<void> unhideWords(Iterable<String> wordIds) =>
      _hidden.unhideWords(wordIds);

  HiddenWordRepository get _hidden =>
      hidden ??
      (throw StateError('no HiddenWordRepository: words cannot be hidden'));

  Future<Textbook> createTextbook(String title) async {
    final clean = title.trim();
    if (clean.isEmpty) throw const LibraryException('교재 이름이 비어 있습니다');
    final now = clock.now();
    // Checking the id and saving it in one transaction: two books created at
    // the same instant cannot both take the same free id.
    return library.transaction(() async {
      final textbook = Textbook(
        id: await _freshTextbookId(now),
        title: clean,
        createdAt: now,
      );
      await library.saveTextbook(textbook);
      return textbook;
    });
  }

  /// Saves the included entries of [draft] as new words of [textbookId], in
  /// the draft's order. All of them are saved in one transaction: if one
  /// fails, none is kept.
  Future<SaveResult> saveDraft(
    CaptureDraft draft, {
    required String textbookId,
  }) => library.transaction(() => _saveDraft(draft, textbookId));

  Future<SaveResult> _saveDraft(CaptureDraft draft, String textbookId) async {
    if (await library.textbook(textbookId) == null) {
      throw const LibraryException('교재를 찾지 못했어요. 다시 골라 주세요');
    }
    final now = clock.now();
    final stamp = await _freshStamp(textbookId, now);
    final words = <Word>[];
    var skipped = 0;
    for (final (i, e) in draft.entries.indexed) {
      if (!e.included || e.headword.trim().isEmpty) {
        skipped++;
        continue;
      }
      words.add(
        Word(
          id: _wordId(textbookId, stamp, i),
          textbookId: textbookId,
          headword: e.headword.trim(),
          readings: List.unmodifiable(e.readings),
          pos: e.pos,
          meaning: e.meaning.trim(),
          example: e.example,
          createdAt: now,
        ),
      );
    }
    await library.saveWords(words);
    return SaveResult(saved: words.length, skipped: skipped);
  }

  Future<TextbookOverview> overview(String textbookId) async {
    final textbook = await library.textbook(textbookId);
    if (textbook == null) {
      throw const LibraryException('교재를 찾지 못했어요');
    }
    final words = await library.words(textbookId: textbookId);
    final known = {for (final d in await library.days(textbookId)) d.number: d};
    // A DAY with no words left (its page was saved under another DAY) is hidden.
    final numbers = {for (final w in words) ?w.day}.toList()..sort();
    return TextbookOverview(
      textbook: textbook,
      days: List.unmodifiable([
        for (final n in numbers)
          DayOverview(
            day:
                known[n] ??
                TextbookDay(textbookId: textbookId, number: n, title: ''),
            words: List.unmodifiable(words.where((w) => w.day == n)),
          ),
      ]),
      undated: List.unmodifiable(words.where((w) => w.day == null)),
    );
  }

  /// `textbookId:w<stamp>-<position>`: the words of one save share their
  /// time, and the position is zero-padded so the ids sort in the draft's
  /// order (`-0010` after `-0002`).
  String _wordId(String textbookId, int stamp, int index) =>
      '$textbookId:w$stamp-${index.toString().padLeft(_positionDigits, '0')}';

  /// The save time in microseconds, moved on past any earlier save at the
  /// same instant (a clock that did not move) so no word is overwritten.
  Future<int> _freshStamp(String textbookId, DateTime now) async {
    final ids = {
      for (final w in await library.words(textbookId: textbookId)) w.id,
    };
    var stamp = now.microsecondsSinceEpoch;
    while (ids.any((id) => id.startsWith('$textbookId:w$stamp-'))) {
      stamp++;
    }
    return stamp;
  }

  Future<String> _freshTextbookId(DateTime now) async {
    final base = 'tb-${now.microsecondsSinceEpoch.toRadixString(36)}';
    var id = base;
    for (var n = 2; await library.textbook(id) != null; n++) {
      id = '$base-$n';
    }
    return id;
  }
}
