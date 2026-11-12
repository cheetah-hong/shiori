import 'package:shiori_core/shiori_core.dart';

import 'harness.dart';

/// Made-up word number [n] (語n, read よみn), added [n] seconds after the
/// test clock's start so new words keep this order.
Word madeUpWord(int n) => Word(
  id: 'w$n',
  headword: '語$n',
  readings: ['よみ$n'],
  meaning: '뜻$n',
  createdAt: testNow.add(Duration(seconds: n)),
);

/// Stores playlist [id] named [name] holding the made-up words [numbers].
Future<void> seedMadeUpPlaylist(
  LibraryRepository library,
  String id,
  String name,
  Iterable<int> numbers,
) async {
  await library.savePlaylist(
    Playlist(
      id: id,
      name: name,
      createdAt: testNow,
      position: (await library.playlists()).length,
    ),
  );
  final words = [for (final n in numbers) madeUpWord(n)];
  await library.insertWords(words);
  await library.addToPlaylist(id, [for (final w in words) w.id], at: testNow);
}

/// A card whose review time came [hours] hours ago.
ReviewCard dueCardOf(int n, {int hours = 1}) => ReviewCard(
  wordId: 'w$n',
  level: 2,
  dueAt: testNow.subtract(Duration(hours: hours)),
  lastReviewedAt: testNow.subtract(const Duration(days: 3)),
);

/// A card whose review time comes in [days] days.
ReviewCard waitingCardOf(int n, {int days = 2}) => ReviewCard(
  wordId: 'w$n',
  level: 2,
  dueAt: testNow.add(Duration(days: days)),
  lastReviewedAt: testNow,
);
