import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shiori/features/reminders/nudge_settings.dart';
import 'package:shiori_core/shiori_core.dart';

/// [NudgeSettings] in a small JSON file in the app support folder, written
/// to a temporary file first and then renamed over the old one.
final class FileNudgeStore implements NudgeStore {
  FileNudgeStore({required this.directory});

  factory FileNudgeStore.appSupport() =>
      FileNudgeStore(directory: getApplicationSupportDirectory);

  static const fileName = 'nudge.json';

  /// The file's format; a file of another one is refused.
  static const version = 1;

  final Future<Directory> Function() directory;

  Future<File> _file() async => File('${(await directory()).path}/$fileName');

  @override
  Future<NudgeSettings> load() async {
    final file = await _file();
    if (!await file.exists()) return const NudgeSettings();
    return decodeNudgeSettings(await file.readAsString());
  }

  @override
  Future<void> save(NudgeSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(encodeNudgeSettings(settings), flush: true);
    await temporary.rename(file.path);
  }
}

const int _minutesPerDay = 24 * 60;

/// The file's content for [settings].
String encodeNudgeSettings(NudgeSettings settings) => jsonEncode({
  'version': FileNudgeStore.version,
  'reminder': {
    'on': settings.remindersOn,
    'minute': settings.reminderTime?.minutes,
    'offered': settings.offered,
  },
  'haptics': settings.haptics,
  'swipeHinted': settings.swipeHinted,
});

/// The settings in [text]; a [FormatException] when it is not such a file.
NudgeSettings decodeNudgeSettings(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('not a settings file');
  }
  if (json case {
    'version': FileNudgeStore.version,
    'reminder': {
      'on': final bool on,
      'minute': final int? minute,
      'offered': final bool offered,
    },
    'haptics': final bool haptics,
    'swipeHinted': final bool swipeHinted,
  }) {
    if (minute != null && (minute < 0 || minute >= _minutesPerDay)) {
      throw FormatException('reminder time out of the day', minute);
    }
    return NudgeSettings(
      remindersOn: on,
      reminderTime: minute == null ? null : ReminderTime(minute),
      offered: offered,
      haptics: haptics,
      swipeHinted: swipeHinted,
    );
  }
  throw const FormatException('not a settings file of this version');
}
