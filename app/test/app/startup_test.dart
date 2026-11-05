import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/blocks.dart';
import 'package:shiori/app/startup.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

void main() {
  test('an opened database is plugged into the storage blocks', () async {
    final db = ShioriDatabase.memory();
    addTearDown(db.close);
    final c = ProviderContainer.test(
      overrides: [await appDatabaseOverride(open: () async => db)],
    );
    expect(c.read(appDatabaseProvider), same(db));
    expect(c.read(libraryRepositoryProvider), isA<DriftLibraryRepository>());
  });

  test(
    'a folder failure still starts the app and surfaces the error',
    () async {
      const failure = FileSystemException('no space left');
      final c = ProviderContainer.test(
        overrides: [
          await appDatabaseOverride(open: () => Future.error(failure)),
        ],
      );
      expect(
        () => c.read(libraryRepositoryProvider),
        throwsA(predicate((e) => '$e'.contains('no space left'))),
      );
    },
  );

  test('a folder lookup that hangs times out instead of blocking', () async {
    final never = Completer<ShioriDatabase>();
    final c = ProviderContainer.test(
      overrides: [
        await appDatabaseOverride(
          open: () => never.future,
          timeout: const Duration(milliseconds: 10),
        ),
      ],
    );
    expect(
      () => c.read(appDatabaseProvider),
      throwsA(predicate((e) => '$e'.contains('TimeoutException'))),
    );
  });

  testWidgets('the home screen shows the load error instead of hanging', (
    tester,
  ) async {
    const failure = FileSystemException('no space left');
    final override = await tester.runAsync(
      () => appDatabaseOverride(open: () => Future.error(failure)),
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
}
