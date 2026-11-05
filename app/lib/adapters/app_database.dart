import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

/// File name of the app's SQLite database inside the app support folder.
const appDatabaseFileName = 'shiori.sqlite';

/// The database file behind both storage blocks, created on first launch.
///
/// - iOS: `<app data container>/Library/Application Support/shiori.sqlite`
/// - Android: `/data/data/<application id>/files/shiori.sqlite`
///
/// The folder belongs to the app: it is kept across app updates and removed
/// when the app is uninstalled. SQLite opens the file on a background isolate
/// at the first query; an open failure shows up as that query's error.
Future<ShioriDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return ShioriDatabase.file(File('${dir.path}/$appDatabaseFileName'));
}
