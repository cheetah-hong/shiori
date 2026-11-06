import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/adapters/bundled_dictionary.dart';
import 'package:shiori/adapters/bundled_glossary.dart';
import 'package:shiori/adapters/dictionary_problem.dart';
import 'package:shiori/app/startup.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

import '../support/dictionary.dart';

/// Where the database file would be; the tests open memory databases.
Future<File> _locate() async => File('shiori.sqlite');

void main() {
  test('an opened database is plugged into the storage blocks', () async {
    final db = ShioriDatabase.memory();
    final opened = <File>[];
    final c = ProviderContainer.test(
      overrides: [
        await appDatabaseOverride(
          locate: _locate,
          open: (file) {
            opened.add(file);
            return db;
          },
        ),
      ],
    );
    expect(c.read(appDatabaseProvider), same(db));
    expect(c.read(libraryRepositoryProvider), isA<DriftLibraryRepository>());
    expect(opened.map((f) => f.path), ['shiori.sqlite']);
  });

  test(
    'a folder failure still starts the app and surfaces the error',
    () async {
      const failure = FileSystemException('no space left');
      var opens = 0;
      final c = ProviderContainer.test(
        overrides: [
          await appDatabaseOverride(
            locate: () => Future.error(failure),
            open: (file) {
              opens++;
              return ShioriDatabase.memory();
            },
          ),
        ],
      );
      expect(
        () => c.read(libraryRepositoryProvider),
        throwsA(predicate((e) => '$e'.contains('no space left'))),
      );
      expect(opens, 0, reason: 'no file to open');
    },
  );

  test('a folder lookup that hangs times out instead of blocking', () async {
    final never = Completer<File>();
    final c = ProviderContainer.test(
      overrides: [
        await appDatabaseOverride(
          locate: () => never.future,
          open: (file) => ShioriDatabase.memory(),
          timeout: const Duration(milliseconds: 10),
        ),
      ],
    );
    expect(
      () => c.read(appDatabaseProvider),
      throwsA(predicate((e) => '$e'.contains('TimeoutException'))),
    );
  });

  test('invalidating the database opens a new connection and closes the '
      'old one', () async {
    final opened = <ShioriDatabase>[];
    final c = ProviderContainer.test(
      overrides: [
        await appDatabaseOverride(
          locate: _locate,
          open: (file) {
            final db = ShioriDatabase.memory();
            opened.add(db);
            return db;
          },
        ),
      ],
    );
    final first = c.read(appDatabaseProvider);
    expect(await DriftLibraryRepository(first).playlists(), isEmpty);

    c.invalidate(appDatabaseProvider);
    final second = c.read(appDatabaseProvider);

    expect(opened, hasLength(2));
    expect(second, isNot(same(first)));
    expect(c.read(libraryRepositoryProvider), isA<DriftLibraryRepository>());
    expect(await DriftLibraryRepository(second).playlists(), isEmpty);
    await expectLater(
      DriftLibraryRepository(first).playlists(),
      throwsA(isStateError),
      reason: 'the first connection is closed',
    );
  });

  testWidgets('the home screen shows the load error instead of hanging', (
    tester,
  ) async {
    const failure = FileSystemException('no space left');
    final override = await tester.runAsync(
      () => appDatabaseOverride(locate: () => Future.error(failure)),
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [override!],
        child: const ShioriApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('불러오지 못했어요'), findsWidgets);
  });

  test('opening the dictionary never holds up startup', () async {
    final unpacking = Completer<BundledDictionary>();
    var started = false;
    final override = bundledDictionaryOverride(
      open: () {
        started = true;
        return unpacking.future;
      },
    );
    expect(started, isTrue, reason: 'starts before the first frame');
    final c = ProviderContainer.test(overrides: [override]);
    expect(c.read(lexiconProvider), isA<EmptyLexicon>());

    final opened = BundledDictionary.opened(openMiniJmdict(), testEdition);
    addTearDown(opened.close);
    unpacking.complete(opened);
    await c.read(bundledDictionaryProvider.future);
    expect(c.read(lexiconProvider), isA<JmdictLexiconAdapter>());
  });

  test('invalidating the dictionaries (「다시 시도」) opens them again; the '
      'first open is the one started before the first frame', () async {
    var dictionaryOpens = 0;
    var glossaryOpens = 0;
    final c = ProviderContainer.test(
      overrides: [
        bundledDictionaryOverride(
          open: () async {
            dictionaryOpens++;
            return const BundledDictionary.unavailable(
              'damaged',
              problemKind: DictionaryProblem.damaged,
            );
          },
        ),
        bundledGlossaryOverride(
          open: () async {
            glossaryOpens++;
            return const BundledGlossary.unavailable('none');
          },
        ),
      ],
    );
    await c.read(bundledDictionaryProvider.future);
    await c.read(bundledGlossaryProvider.future);
    expect((dictionaryOpens, glossaryOpens), (1, 1));

    c.invalidate(bundledDictionaryProvider);
    c.invalidate(bundledGlossaryProvider);
    await c.read(bundledDictionaryProvider.future);
    await c.read(bundledGlossaryProvider.future);
    expect((dictionaryOpens, glossaryOpens), (2, 2));
  });
}
