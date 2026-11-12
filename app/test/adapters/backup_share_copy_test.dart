// The share sheet's arguments for a backup file, and which picked copies
// may be removed after reading (only ones inside the app's temporary
// folders, never the file the learner picked elsewhere).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/backup_files.dart';
import 'package:shiori_core/shiori_core.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('shiori_copy_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('the share sheet', () {
    test('the file as JSON under its name, the name as the title, the '
        'tapped row as the anchor', () {
      final written = File('${dir.path}/w.json')..writeAsBytesSync([1]);
      final file = BackupExport(
        fileName: 'shiori-backup-20261112-2230.json',
        bytes: Uint8List.fromList([1]),
      );
      const origin = Rect.fromLTWH(16, 700, 358, 72);

      final params = backupShareParams(written, file, origin);

      expect(params.title, 'shiori-backup-20261112-2230.json');
      expect(params.fileNameOverrides, ['shiori-backup-20261112-2230.json']);
      expect(params.files, hasLength(1));
      expect(params.files!.single.path, written.path);
      expect(params.files!.single.mimeType, 'application/json');
      expect(params.sharePositionOrigin, origin);
      expect(params.text, isNull);
    });
  });

  group('a picked copy that may be removed', () {
    late Directory tmp;
    late Directory caches;

    setUp(() {
      tmp = Directory('${dir.path}/tmp')..createSync();
      caches = Directory('${dir.path}/Library/Caches')
        ..createSync(recursive: true);
    });

    File fileAt(String path) => File('${dir.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1]);

    test("inside tmp/ (where iOS puts the picker's copy)", () {
      final copy = fileAt('tmp/app.bundle-Inbox/b.json');
      expect(removableCopyIn(copy, [tmp, caches]), isTrue);
    });

    test('inside the caches folder', () {
      expect(
        removableCopyIn(fileAt('Library/Caches/b.json'), [tmp, caches]),
        isTrue,
      );
    });

    test('elsewhere: never', () {
      final original = fileAt('Documents/b.json');
      expect(removableCopyIn(original, [tmp, caches]), isFalse);
    });

    test('a folder whose name only starts like tmp: never', () {
      expect(removableCopyIn(fileAt('tmpfiles/b.json'), [tmp]), isFalse);
    });

    test(
      'a link in tmp/ to a file elsewhere: never (the link is resolved)',
      () {
        final original = fileAt('Documents/b.json');
        final link = Link('${tmp.path}/b.json')..createSync(original.path);
        expect(removableCopyIn(File(link.path), [tmp]), isFalse);
      },
    );

    test('a root that does not exist takes nothing', () {
      final copy = fileAt('tmp/b.json');
      expect(removableCopyIn(copy, [Directory('${dir.path}/gone')]), isFalse);
    });
  });
}
