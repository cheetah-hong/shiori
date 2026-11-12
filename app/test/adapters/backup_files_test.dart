// The backup files on the device: the copy kept before a restore, the file
// written for the share sheet, and a picked file read only when it fits.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('shiori_backup_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('FileBackupKeeper', () {
    FileBackupKeeper keeper() => FileBackupKeeper(directory: () async => dir);

    test('nothing kept at first', () async {
      expect(await keeper().read(), isNull);
      expect(await keeper().keptAt(), isNull);
      await keeper().discard();
    });

    test(
      'keeps one copy in backup/before-restore.json, replacing the last',
      () async {
        await keeper().keep(Uint8List.fromList([1, 2, 3]));
        await keeper().keep(Uint8List.fromList([4, 5]));

        expect(await keeper().read(), [4, 5]);
        expect(await keeper().keptAt(), isNotNull);
        final folder = Directory('${dir.path}/backup');
        expect(folder.listSync().map((f) => f.uri.pathSegments.last), [
          'before-restore.json',
        ]);
      },
    );

    test('discard removes it', () async {
      await keeper().keep(Uint8List.fromList([1]));
      await keeper().discard();

      expect(await keeper().read(), isNull);
      expect(await keeper().keptAt(), isNull);
    });
  });

  group('the file for the share sheet', () {
    test('written under its name; an earlier one is cleared first', () async {
      final folder = Directory('${dir.path}/shiori-backup');
      await writeBackupForShare(
        folder,
        BackupExport(
          fileName: 'shiori-backup-20261111-0900.json',
          bytes: Uint8List.fromList([1]),
        ),
      );

      final file = await writeBackupForShare(
        folder,
        BackupExport(
          fileName: 'shiori-backup-20261112-2230.json',
          bytes: Uint8List.fromList([7, 8]),
        ),
      );

      expect(file.uri.pathSegments.last, 'shiori-backup-20261112-2230.json');
      expect(file.readAsBytesSync(), [7, 8]);
      expect(folder.listSync(), hasLength(1));

      await clearBackupFolder(folder);
      expect(folder.existsSync(), isFalse);
      await clearBackupFolder(folder);
    });
  });

  group('a picked file', () {
    test('none picked: null', () async {
      expect(await readPickedBackup(null), isNull);
    });

    test('read when it fits', () async {
      final file = File('${dir.path}/b.json')..writeAsBytesSync([1, 2, 3, 4]);

      expect(await readPickedBackup(XFile(file.path), maxBytes: 4), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('over the limit: refused before it is read', () async {
      final file = File('${dir.path}/b.json')..writeAsBytesSync([1, 2, 3, 4]);

      await expectLater(
        readPickedBackup(XFile(file.path), maxBytes: 3),
        throwsA(
          isA<BackupException>().having(
            (e) => e.problem,
            'problem',
            BackupProblem.tooLarge,
          ),
        ),
      );
    });
  });
}
