import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shiori/adapters/app_database.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_storage_drift/shiori_storage_drift.dart';

final class _FakePaths extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePaths(this.support);

  final String support;

  @override
  Future<String?> getApplicationSupportPath() async => support;
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('shiori_app_db_');
    // A folder that does not exist yet, as on first launch.
    PathProviderPlatform.instance = _FakePaths('${root.path}/support');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('the database file sits in the app support folder, made on first '
      'launch', () async {
    final file = await appDatabaseFile();

    expect(file.path, '${root.path}/support/shiori.sqlite');
    expect(Directory('${root.path}/support').existsSync(), isTrue);
  });

  test('a database file keeps what was written across a reopen', () async {
    final at = DateTime(2026, 11, 5, 21);
    final file = await appDatabaseFile();
    final db = ShioriDatabase.file(file);
    await DriftLibraryRepository(
      db,
    ).savePlaylist(Playlist(id: 'pl', name: '단어장', createdAt: at, position: 0));
    await db.close();

    expect(file.existsSync(), isTrue);
    final again = ShioriDatabase.file(await appDatabaseFile());
    addTearDown(again.close);
    final playlist = (await DriftLibraryRepository(again).playlists()).single;
    expect(playlist.name, '단어장');
    expect(playlist.createdAt, at);
  });
}
