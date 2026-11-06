// Behaviour tests for the study options block, run against every storage
// block from preferences_contract_test.dart.
import 'dart:async';

import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// A fresh options block for one test.
abstract interface class PreferencesUnderTest {
  StudyPreferencesRepository get preferences;
  Future<void> close();
}

void preferencesContract(
  String name,
  FutureOr<PreferencesUnderTest> Function() open,
) {
  group('$name study preferences', () {
    late PreferencesUnderTest storage;
    StudyPreferencesRepository prefs() => storage.preferences;

    setUp(() async => storage = await open());
    tearDown(() => storage.close());

    test('nothing stored: the defaults (shared record, 전체 + 재생목록)', () async {
      expect(await prefs().load(), const StudyPreferences());
    });

    test(
      'every value is stored and read back, also the ones not built yet',
      () async {
        for (final record in RecordMode.values) {
          for (final scope in StudyScopeMode.values) {
            final p = StudyPreferences(recordMode: record, scopeMode: scope);
            await prefs().save(p);
            expect(await prefs().load(), p);
          }
        }
      },
    );

    test('saving again replaces what was stored', () async {
      await prefs().save(
        const StudyPreferences(recordMode: RecordMode.perPlaylist),
      );
      await prefs().save(const StudyPreferences());
      expect(await prefs().load(), const StudyPreferences());
    });
  });
}
