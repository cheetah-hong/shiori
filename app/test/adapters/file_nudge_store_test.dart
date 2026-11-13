// N3: reminder and haptics settings in a small file of this device, out of
// the learning database and so out of backups.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/file_nudge_store.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  late Directory dir;
  late FileNudgeStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nudge');
    store = FileNudgeStore(directory: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File file() => File('${dir.path}/${FileNudgeStore.fileName}');

  test('no file: the defaults (off, not offered, haptics on)', () async {
    expect(await store.load(), const NudgeSettings());
    const defaults = NudgeSettings();
    expect(
      (
        defaults.remindersOn,
        defaults.reminderTime,
        defaults.offered,
        defaults.haptics,
        defaults.swipeHinted,
      ),
      (false, null, false, true, false),
    );
    expect(defaults.timeOrDefault, ReminderTime.evening);
  });

  test('saved settings read back', () async {
    const saved = NudgeSettings(
      remindersOn: true,
      reminderTime: ReminderTime(8 * 60 + 30),
      offered: true,
      haptics: false,
      swipeHinted: true,
    );
    await store.save(saved);
    expect(await store.load(), saved);
    expect(await FileNudgeStore(directory: () async => dir).load(), saved);
  });

  test('the file is versioned JSON and leaves no temporary file', () async {
    await store.save(const NudgeSettings(reminderTime: ReminderTime(420)));
    final text = file().readAsStringSync();
    expect(text, contains('"version":1'));
    expect(text, contains('420'));
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toList(), [
      FileNudgeStore.fileName,
    ]);
  });

  test('the folder is made when missing', () async {
    final nested = Directory('${dir.path}/a/b');
    await FileNudgeStore(
      directory: () async => nested,
    ).save(const NudgeSettings(offered: true));
    expect(
      await FileNudgeStore(directory: () async => nested).load(),
      const NudgeSettings(offered: true),
    );
  });

  test('a damaged file is a FormatException', () async {
    for (final text in [
      '',
      'not json',
      '[]',
      '{"version":2,"reminder":{},"haptics":true}',
      '{"version":1,"reminder":{"on":true,"minute":1440,"offered":true},'
          '"haptics":true,"swipeHinted":false}',
      '{"version":1,"reminder":{"on":"yes","minute":60,"offered":true},'
          '"haptics":true,"swipeHinted":false}',
    ]) {
      file().writeAsStringSync(text);
      await expectLater(store.load(), throwsFormatException, reason: text);
    }
  });

  test('encode and decode round trip, with no time picked', () {
    const s = NudgeSettings(offered: true, haptics: false);
    expect(decodeNudgeSettings(encodeNudgeSettings(s)), s);
  });

  test('copyWith keeps what it is not given', () {
    const s = NudgeSettings(
      remindersOn: true,
      reminderTime: ReminderTime(60),
      offered: true,
      haptics: false,
      swipeHinted: true,
    );
    expect(s.copyWith(), s);
    expect(s.copyWith(haptics: true).haptics, isTrue);
    expect(s.copyWith(haptics: true).reminderTime, const ReminderTime(60));
  });
}
