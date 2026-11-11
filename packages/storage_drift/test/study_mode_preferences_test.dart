// The study mode picked last (홈·재생목록 chips) is a study option like the
// others: stored, read back, and a value this build does not know reads as
// 뜻 맞히기.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

void main() {
  for (final (name, open) in [
    (
      'in-memory',
      () => (
        InMemoryStudyPreferencesRepository() as StudyPreferencesRepository,
        () async {},
      ),
    ),
    (
      'drift',
      () {
        final db = ShioriDatabase.memory();
        return (
          DriftStudyPreferencesRepository(db) as StudyPreferencesRepository,
          db.close,
        );
      },
    ),
  ]) {
    group('$name study mode option', () {
      late StudyPreferencesRepository prefs;
      late Future<void> Function() close;

      setUp(() {
        final (p, c) = open();
        prefs = p;
        close = c;
      });
      tearDown(() => close());

      test('nothing stored: 뜻 맞히기', () async {
        expect((await prefs.load()).mode, StudyMode.meaning);
      });

      test('every mode is stored and read back with the other '
          'options', () async {
        for (final mode in StudyMode.values) {
          final p = StudyPreferences(
            scopeMode: StudyScopeMode.playlistOnly,
            mode: mode,
          );
          await prefs.save(p);
          expect(await prefs.load(), p, reason: '$mode');
        }
        await prefs.save(const StudyPreferences());
        expect(await prefs.load(), const StudyPreferences());
      });
    });
  }

  group('drift settings row', () {
    late ShioriDatabase db;

    setUp(() => db = ShioriDatabase.memory());
    tearDown(() => db.close());

    Future<Map<String, String>> rows() async => {
      for (final r
          in await db.customSelect('SELECT key, value FROM settings').get())
        r.read<String>('key'): r.read<String>('value'),
    };

    test('stored by name under study.mode', () async {
      await DriftStudyPreferencesRepository(
        db,
      ).save(const StudyPreferences(mode: StudyMode.listening));
      expect((await rows())['study.mode'], 'listening');
    });

    test('an unknown stored mode reads as 뜻 맞히기 and is kept', () async {
      await db.customStatement(
        "INSERT INTO settings (key, value) VALUES ('study.mode', 'flying')",
      );
      expect(
        (await DriftStudyPreferencesRepository(db).load()).mode,
        StudyMode.meaning,
      );
      expect((await rows())['study.mode'], 'flying');
    });
  });

  test('StudyPreferences: mode in equality and copyWith', () {
    const a = StudyPreferences(mode: StudyMode.choice);
    expect(a == const StudyPreferences(), isFalse);
    expect(
      a.copyWith(recordMode: RecordMode.perPlaylist).mode,
      StudyMode.choice,
    );
    expect(a.copyWith(mode: StudyMode.recall).mode, StudyMode.recall);
    expect(a.hashCode, const StudyPreferences(mode: StudyMode.choice).hashCode);
  });
}
