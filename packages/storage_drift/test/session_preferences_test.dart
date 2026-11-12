// The daily goal and the card order (설정): stored in the settings table,
// kept across restarts, and read as the default when unknown.
import 'dart:io';

import 'package:drift/drift.dart' show Variable;

import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';
import 'package:test/test.dart';

void main() {
  group('kept across a restart', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('shiori_prefs_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('daily goal and card order read back from a reopened file', () async {
      final file = File('${dir.path}/shiori.sqlite');
      const chosen = StudyPreferences(
        dailyGoal: DailyGoal.thirty,
        shuffle: false,
        mode: StudyMode.recall,
      );
      final first = ShioriDatabase.file(file);
      await DriftStudyPreferencesRepository(first).save(chosen);
      await first.close();

      final second = ShioriDatabase.file(file);
      addTearDown(second.close);
      expect(await DriftStudyPreferencesRepository(second).load(), chosen);
    });
  });

  group('drift settings rows', () {
    late ShioriDatabase db;

    setUp(() => db = ShioriDatabase.memory());
    tearDown(() => db.close());

    Future<Map<String, String>> rows() async => {
      for (final r
          in await db.customSelect('SELECT key, value FROM settings').get())
        r.read<String>('key'): r.read<String>('value'),
    };

    test(
      'the defaults add no row: a file from before holds the same rows',
      () async {
        await DriftStudyPreferencesRepository(
          db,
        ).save(const StudyPreferences());
        expect((await rows()).keys.toSet(), {
          'study.record_mode',
          'study.scope_mode',
        });
      },
    );

    test('a daily goal other than 10 and 섞기 끔 are stored by name', () async {
      final prefs = DriftStudyPreferencesRepository(db);
      await prefs.save(
        const StudyPreferences(dailyGoal: DailyGoal.all, shuffle: false),
      );
      expect((await rows())['study.daily_goal'], 'all');
      expect((await rows())['study.shuffle'], 'off');
      await prefs.save(const StudyPreferences(dailyGoal: DailyGoal.fifty));
      expect((await rows())['study.daily_goal'], '50');
      expect((await rows()).containsKey('study.shuffle'), isFalse);
      await prefs.save(const StudyPreferences());
      expect((await rows()).containsKey('study.daily_goal'), isFalse);
    });

    for (final (goal, shuffle) in [
      ('15', 'maybe'),
      ('all ', 'on'),
      ('', ''),
      ('-10', 'OFF'),
    ]) {
      test('unknown stored values ($goal, $shuffle) read as the defaults and '
          'are kept', () async {
        await db.customInsert(
          'INSERT INTO settings (key, value) VALUES '
          "('study.daily_goal', ?), ('study.shuffle', ?)",
          variables: [Variable.withString(goal), Variable.withString(shuffle)],
        );
        final p = await DriftStudyPreferencesRepository(db).load();
        expect((p.dailyGoal, p.shuffle), (DailyGoal.ten, true));
        expect((await rows())['study.daily_goal'], goal);
        expect((await rows())['study.shuffle'], shuffle);
      });
    }
  });

  test('StudyPreferences: daily goal and card order in ==, hashCode, '
      'copyWith', () {
    const a = StudyPreferences(dailyGoal: DailyGoal.twenty, shuffle: false);
    expect(a == const StudyPreferences(), isFalse);
    expect(a == const StudyPreferences(dailyGoal: DailyGoal.twenty), isFalse);
    expect(
      a.hashCode,
      const StudyPreferences(
        dailyGoal: DailyGoal.twenty,
        shuffle: false,
      ).hashCode,
    );
    expect(a.copyWith(mode: StudyMode.choice).dailyGoal, DailyGoal.twenty);
    expect(a.copyWith(mode: StudyMode.choice).shuffle, isFalse);
    expect(a.copyWith(dailyGoal: DailyGoal.all).dailyGoal, DailyGoal.all);
    expect(a.copyWith(shuffle: true).shuffle, isTrue);
  });
}
