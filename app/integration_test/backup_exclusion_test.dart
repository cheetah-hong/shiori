// On an iPhone or the iOS simulator: the crash log's folder is out of device
// backups after the first record, and the learning database's folder is not.
//
//   cd app && flutter test integration_test/backup_exclusion_test.dart -d <device> --flavor dev
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/adapters/backup_exclusion.dart';
import 'package:shiori/adapters/file_crash_log.dart';
import 'package:shiori/app/crash_reporting.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crash log folder excluded, database folder kept', (_) async {
    expect(
      Platform.isIOS,
      isTrue,
      reason: 'iOS only (Android: allowBackup off)',
    );
    final support = await getApplicationSupportDirectory();
    final log = FileCrashLog.appSupport();
    await log.record(
      CrashReport(
        time: DateTime.now(),
        source: CrashSource.platform,
        error: 'backup exclusion check',
      ),
    );

    const marks = ChannelBackupExclusion();
    final folder = '${support.path}/${FileCrashLog.folderName}';
    expect(
      File('$folder/${FileCrashLog.fileName}').existsSync(),
      isTrue,
      reason: 'the record is written into the excluded folder',
    );
    expect(await marks.isExcluded(folder), isTrue);
    expect(await marks.isExcluded(support.path), isFalse);

    await log.clear();
  });
}
