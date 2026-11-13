// Times adding the built-in decks the way the deck screen does (deckDraft,
// then LibraryService.addDeck) with the bundled dictionaries and a database
// file of its own, and prints the file size before and after. Needs the real
// deck and dictionary assets (tools/decks/build_decks.py, tools/dict).
//
//   cd app && flutter drive -d <device> [--profile] --flavor dev \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/deck_add_timing_test.dart
//
// Two rounds, each on an empty file: N1 alone, then N5 … N1 one after another.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/features/decks/deck_data.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adding the built-in decks', (tester) async {
    final dictionary = await openAppDictionary();
    final glossary = await openAppGlossary();
    expect(dictionary.isAvailable, isTrue, reason: '${dictionary.problem}');
    expect(glossary.isAvailable, isTrue, reason: '${glossary.problem}');
    final set = parseBuiltinDecks(
      await rootBundle.loadString(builtinDecksAsset),
    );
    final byLevel = {for (final d in set.decks) d.level: d};
    final dir = await getTemporaryDirectory();

    Future<void> round(String name, List<String> levels) async {
      final file = File('${dir.path}/deck_timing_$name.sqlite');
      for (final f in [
        file,
        File('${file.path}-wal'),
        File('${file.path}-shm'),
      ]) {
        if (f.existsSync()) f.deleteSync();
      }
      final db = ShioriDatabase.file(file);
      final service = LibraryService(
        library: DriftLibraryRepository(db),
        clock: const SystemClock(),
      );
      await service.previewAdd(const ['空']); // opens and creates the file
      final before = _size(file);
      final all = Stopwatch()..start();
      for (final level in levels) {
        final deck = byLevel[level]!;
        final draftTime = Stopwatch()..start();
        final draft = await deckDraft(
          deck,
          lexicon: dictionary.lexicon,
          glossary: glossary.glossary,
          fallback: glossary.wiktionary,
        );
        draftTime.stop();
        final addTime = Stopwatch()..start();
        final result = await service.addDeck(draft);
        addTime.stop();
        // ignore: avoid_print
        print(
          '[deck-timing] $name $level words ${deck.words.length} '
          'added ${result.added} linked ${result.linked} '
          'left out ${draft.withoutMeaning.length} '
          'draft ${draftTime.elapsedMilliseconds} ms '
          'add ${addTime.elapsedMilliseconds} ms',
        );
      }
      all.stop();
      await db.close();
      // ignore: avoid_print
      print(
        '[deck-timing] $name total ${all.elapsedMilliseconds} ms '
        'file $before -> ${_size(file)} bytes',
      );
    }

    await tester.runAsync(() async {
      await round('n1', ['N1']);
      await round('all', ['N5', 'N4', 'N3', 'N2', 'N1']);
    });
    dictionary.close();
    glossary.close();
  });
}

/// The database file with its write-ahead log.
int _size(File file) => [
  file,
  File('${file.path}-wal'),
].where((f) => f.existsSync()).fold(0, (n, f) => n + f.lengthSync());
