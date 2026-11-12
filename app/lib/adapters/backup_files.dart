/// 설정 › 백업 on the device: the share sheet for a new backup file, the
/// system file picker for one to restore, the copy kept before a restore,
/// and the app version written into a file. Nothing here opens a network
/// connection; where a file goes is the learner's choice in the share sheet.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shiori_core/shiori_core.dart';

/// What the learner did with the share sheet.
enum BackupShareResult {
  /// Picked where the file goes (saved, sent, …).
  shared,

  /// Closed the sheet without picking anything.
  dismissed,
}

/// Hands [file] to the share sheet, anchored at [origin] (the tapped row,
/// for the iPad popover).
typedef BackupShare =
    Future<BackupShareResult> Function(BackupExport file, Rect? origin);

/// The bytes of a backup file the learner picks; null when they cancel. A
/// [BackupException] ([BackupProblem.tooLarge]) for a file over the limit,
/// before it is read.
typedef BackupPicker = Future<List<int>?> Function();

/// The folder in the temporary directory a backup is written to before it
/// is shared; emptied before each export and after the sheet closes.
const String backupShareFolder = 'shiori-backup';

/// Writes [file] into [folder] (emptied first, so no earlier backup lingers)
/// and returns it.
Future<File> writeBackupForShare(Directory folder, BackupExport file) async {
  await clearBackupFolder(folder);
  await folder.create(recursive: true);
  final out = File('${folder.path}${Platform.pathSeparator}${file.fileName}');
  await out.writeAsBytes(file.bytes, flush: true);
  return out;
}

/// Removes [folder] and what it holds; nothing when it is missing.
Future<void> clearBackupFolder(Directory folder) async {
  if (await folder.exists()) await folder.delete(recursive: true);
}

/// The share sheet with [file] as a JSON attachment. The written copy goes
/// once the sheet is closed, whatever the learner did.
Future<BackupShareResult> shareBackupFile(
  BackupExport file,
  Rect? origin,
) async {
  final folder = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}'
    '$backupShareFolder',
  );
  final written = await writeBackupForShare(folder, file);
  try {
    final result = await SharePlus.instance.share(
      backupShareParams(written, file, origin),
    );
    return result.status == ShareResultStatus.success
        ? BackupShareResult.shared
        : BackupShareResult.dismissed;
  } finally {
    try {
      await clearBackupFolder(folder);
    } on FileSystemException catch (e) {
      // Left for the next export to clear; the share itself went through.
      debugPrint('[shiori] backup copy not removed: $e');
    }
  }
}

/// What the share sheet gets for [written] (the copy of [file]): the file
/// as JSON under its name, the name as the sheet's title, anchored at
/// [origin].
@visibleForTesting
ShareParams backupShareParams(File written, BackupExport file, Rect? origin) =>
    ShareParams(
      files: [XFile(written.path, mimeType: 'application/json')],
      fileNameOverrides: [file.fileName],
      // The sheet's preview title (iOS), the chooser title (Android).
      title: file.fileName,
      sharePositionOrigin: origin,
    );

/// The JSON files the picker offers: by type on iOS (Files app), by the
/// MIME types storage providers give JSON on Android.
const XTypeGroup backupTypeGroup = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  uniformTypeIdentifiers: ['public.json'],
  mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
);

/// The system file picker (Files app on iOS).
Future<List<int>?> pickBackupFile() async {
  final picked = await openFile(acceptedTypeGroups: const [backupTypeGroup]);
  try {
    return await readPickedBackup(picked);
  } finally {
    if (picked != null) await _removeImportedCopy(picked.path);
  }
}

/// The bytes of [picked]; null for none. Its size is checked against
/// [maxBytes] before it is read.
Future<List<int>?> readPickedBackup(
  XFile? picked, {
  int maxBytes = backupMaxBytes,
}) async {
  if (picked == null) return null;
  final length = await picked.length();
  if (length > maxBytes) {
    throw BackupException(BackupProblem.tooLarge, '$length bytes');
  }
  return picked.readAsBytes();
}

/// iOS copies a picked file into the app's `tmp/<bundle id>-Inbox/`; that
/// copy is not needed once read. Only a file inside one of the app's
/// temporary folders ([removableCopyIn]) is removed, never the original.
Future<void> _removeImportedCopy(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return;
    final roots = [Directory.systemTemp, await getTemporaryDirectory()];
    if (!removableCopyIn(file, roots)) return;
    await file.delete();
  } on FileSystemException catch (e) {
    debugPrint('[shiori] picked backup copy not removed: $e');
  }
}

/// Whether [file] (which exists) lies inside one of [roots] (iOS: `tmp/`,
/// where the picker's copy goes, and `Library/Caches`), links resolved.
@visibleForTesting
bool removableCopyIn(File file, List<Directory> roots) {
  final path = file.resolveSymbolicLinksSync();
  return roots.any((root) {
    if (!root.existsSync()) return false;
    final base = root.resolveSymbolicLinksSync();
    final prefix = base.endsWith(Platform.pathSeparator)
        ? base
        : '$base${Platform.pathSeparator}';
    return path.startsWith(prefix);
  });
}

/// The copy kept before a restore, in `backup/before-restore.json` of the
/// app support folder (not shared with other apps; kept in device backups
/// like the database). Written to a temporary file renamed over it, so a
/// stop mid-write leaves the copy before.
final class FileBackupKeeper implements BackupKeeper {
  FileBackupKeeper({required this.directory});

  /// The copy in the app support folder.
  factory FileBackupKeeper.appSupport() =>
      FileBackupKeeper(directory: getApplicationSupportDirectory);

  static const String folderName = 'backup';
  static const String fileName = 'before-restore.json';

  /// The app support folder (or a test folder); asked on every use.
  final Future<Directory> Function() directory;

  Future<File> _file() async {
    final sep = Platform.pathSeparator;
    return File('${(await directory()).path}$sep$folderName$sep$fileName');
  }

  @override
  Future<void> keep(Uint8List bytes) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<DateTime?> keptAt() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.lastModified();
  }

  @override
  Future<void> discard() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

/// The installed app's version and build (Info.plist / the Android
/// manifest), for the backup file header.
Future<BackupApp> installedApp({required int schema}) async {
  final info = await PackageInfo.fromPlatform();
  return BackupApp(
    version: info.version,
    build: info.buildNumber,
    schema: schema,
  );
}

/// Large files are encoded and checked on another isolate, so the screen
/// keeps drawing.
Future<R> backupWorkElsewhere<R>(FutureOr<R> Function() work) =>
    Isolate.run(work);
