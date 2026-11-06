import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// File name of the app's SQLite database inside the app support folder.
const appDatabaseFileName = 'shiori.sqlite';

/// The database file behind the storage blocks, its folder made on first
/// launch.
///
/// - iOS: `<app data container>/Library/Application Support/shiori.sqlite`
/// - Android: `/data/data/<application id>/files/shiori.sqlite`
///
/// The folder belongs to the app: it is kept across app updates and removed
/// when the app is uninstalled. The file itself is opened by
/// `ShioriDatabase.file` (startup.dart), on a background isolate at the
/// first query; an open failure shows up as that query's error.
Future<File> appDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return File('${dir.path}/$appDatabaseFileName');
}
