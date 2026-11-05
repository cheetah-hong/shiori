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

  test('opens the database file in the app support folder', () async {
    final at = DateTime(2026, 11, 5, 21);
    final db = await openAppDatabase();
    await DriftLibraryRepository(
      db,
    ).saveTextbook(Textbook(id: 'tb', title: '단어장', createdAt: at));
    await db.close();

    expect(
      File('${root.path}/support/$appDatabaseFileName').existsSync(),
      isTrue,
    );
    final again = await openAppDatabase();
    addTearDown(again.close);
    expect(
      (await DriftLibraryRepository(again).textbooks()).single.createdAt,
      at,
    );
  });
}
