// The home playlists read every playlist's word and hidden counts in one
// call, not one word list per playlist. Synthetic sample pages only.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/data.dart';
import 'package:shiori/shared/hide_labels.dart';
import 'package:shiori_core/shiori_core.dart';

import '../support/forwarding_library.dart';
import '../support/harness.dart';

/// Counts the reads the playlists could make.
final class _CountingLibrary extends ForwardingLibrary {
  int wordsCalls = 0;
  int statsCalls = 0;

  void reset() => wordsCalls = statsCalls = 0;

  @override
  Future<List<Word>> words({String? playlistId}) {
    wordsCalls++;
    return super.words(playlistId: playlistId);
  }

  @override
  Future<List<PlaylistStats>> playlistStats() {
    statsCalls++;
    return super.playlistStats();
  }
}

final class _Seeded {
  const _Seeded({
    required this.full,
    required this.travel,
    required this.empty,
  });

  /// Sample page 10, two of its words hidden.
  final Playlist full;

  /// Sample page 140.
  final Playlist travel;
  final Playlist empty;
}

/// Three playlists, put in the order empty, full, travel.
Future<_Seeded> _seed(TestBlocks blocks) async {
  final service = LibraryService(library: blocks.library, clock: blocks.clock);
  final full = await blocks.seedPage('s010');
  final travel = await blocks.seedPage('s140', name: '여행 단어');
  final empty = await service.createPlaylist('빈 목록');
  await service.reorderPlaylists([empty.id, full.id, travel.id]);
  final words = await blocks.library.words(playlistId: full.id);
  await service.hideWords([words[0].id, words[1].id]);
  return _Seeded(full: full, travel: travel, empty: empty);
}

void main() {
  test('one stats read, no word lists, in the playlists\' order', () async {
    final library = _CountingLibrary();
    final blocks = TestBlocks(library: library);
    final seeded = await _seed(blocks);
    final fullCount = (await library.inner.words(
      playlistId: seeded.full.id,
    )).length;
    final travelCount = (await library.inner.words(
      playlistId: seeded.travel.id,
    )).length;
    library.reset();

    final container = ProviderContainer.test(overrides: blocks.overrides);
    final playlists = await container.read(playlistsProvider.future);

    expect(library.wordsCalls, 0);
    expect(library.statsCalls, 1);
    expect(playlists.map((s) => s.playlist.id), [
      seeded.empty.id,
      seeded.full.id,
      seeded.travel.id,
    ]);
    expect(playlists.map((s) => s.playlist.position), [0, 1, 2]);
    expect(playlists.map((s) => s.wordCount), [0, fullCount, travelCount]);
    expect(playlists.map((s) => s.hiddenCount), [0, 2, 0]);
    expect(playlists.map((s) => s.shownCount), [0, fullCount - 2, travelCount]);
  });

  test('reads again once the data revision is bumped', () async {
    final library = _CountingLibrary();
    final blocks = TestBlocks(library: library);
    final seeded = await _seed(blocks);
    final container = ProviderContainer.test(overrides: blocks.overrides);
    container.listen(playlistsProvider, (_, _) {});
    expect(await container.read(playlistsProvider.future), hasLength(3));
    library.reset();

    final added = await LibraryService(
      library: library,
      clock: blocks.clock,
    ).createPlaylist('새 목록');
    expect(
      await container.read(playlistsProvider.future),
      hasLength(3),
      reason: 'kept until the revision moves',
    );
    container.read(dataRevisionProvider.notifier).bump();
    final playlists = await container.read(playlistsProvider.future);

    expect(library.statsCalls, 1);
    expect(playlists.map((s) => s.playlist.id), [
      seeded.empty.id,
      seeded.full.id,
      seeded.travel.id,
      added.id,
    ]);
  });

  testWidgets('the home tiles show the same counts', (tester) async {
    usePhoneSize(tester);
    final library = _CountingLibrary();
    final blocks = TestBlocks(library: library);
    final seeded = await _seed(blocks);
    final fullCount = (await library.inner.words(
      playlistId: seeded.full.id,
    )).length;
    final travelCount = (await library.inner.words(
      playlistId: seeded.travel.id,
    )).length;
    library.reset();

    await tester.pumpWidget(app(blocks));
    await tester.pumpAndSettle();

    expect(find.text('JLPT 단어장'), findsOneWidget);
    expect(
      find.text('단어 ${fullCount - 2}개 · ${HideLabels.hiddenCount(2)}'),
      findsOneWidget,
    );
    expect(find.text('여행 단어'), findsOneWidget);
    expect(find.text('단어 $travelCount개'), findsOneWidget);
    expect(find.text('빈 목록'), findsOneWidget);
    expect(find.text('단어 0개'), findsOneWidget);
    expect(library.statsCalls, greaterThan(0));
  });
}
