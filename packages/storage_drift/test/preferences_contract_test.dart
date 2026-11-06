import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

import 'contract/preferences_contract.dart';

final class _InMemory implements PreferencesUnderTest {
  @override
  final StudyPreferencesRepository preferences =
      InMemoryStudyPreferencesRepository();

  @override
  Future<void> close() async {}
}

final class _Drift implements PreferencesUnderTest {
  _Drift(this._db) : preferences = DriftStudyPreferencesRepository(_db);

  final ShioriDatabase _db;
  @override
  final StudyPreferencesRepository preferences;

  @override
  Future<void> close() => _db.close();
}

void main() {
  preferencesContract('in-memory', _InMemory.new);
  preferencesContract('drift', () => _Drift(ShioriDatabase.memory()));

  group('drift settings rows', () {
    late ShioriDatabase db;

    setUp(() => db = ShioriDatabase.memory());
    tearDown(() => db.close());

    Future<List<(String, String)>> rows() => db
        .customSelect('SELECT key, value FROM settings ORDER BY key')
        .map((r) => (r.read<String>('key'), r.read<String>('value')))
        .get();

    test('one row per option, by its stored name', () async {
      await DriftStudyPreferencesRepository(
        db,
      ).save(const StudyPreferences(recordMode: RecordMode.perPlaylist));
      expect(await rows(), [
        ('study.record_mode', 'per_playlist'),
        ('study.scope_mode', 'all_or_playlist'),
      ]);
    });

    test('an unknown stored value reads as the default and is kept', () async {
      await db.customStatement(
        'INSERT INTO settings (key, value) VALUES '
        "('study.record_mode', 'from_a_newer_app'), "
        "('study.scope_mode', 'playlist_only'), ('other.option', 'x')",
      );
      expect(
        await DriftStudyPreferencesRepository(db).load(),
        const StudyPreferences(scopeMode: StudyScopeMode.playlistOnly),
      );
      expect(await rows(), [
        ('other.option', 'x'),
        ('study.record_mode', 'from_a_newer_app'),
        ('study.scope_mode', 'playlist_only'),
      ]);
    });
  });
}
