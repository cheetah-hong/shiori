// D2, D3: the gzip asset is checked against its edition file (sizes and
// sha256) when it is unpacked, and the unpacked file's size on every run.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/adapters/unpacked_asset.dart';

import '../support/dictionary.dart' show MemoryAssetBundle;

const _gz = 'assets/dict/test.sqlite.gz';
const _fileName = 'test.sqlite';
const _markerName = 'test.sqlite.edition';

/// Made-up file contents standing in for a SQLite file.
final _content = utf8.encode('made-up dictionary file ' * 400);

AssetDigest _digestOf(List<int> content, {List<int>? gz}) => AssetDigest(
  gzipBytes: (gz ?? gzip.encode(content)).length,
  sqliteBytes: content.length,
  sqliteSha256: sha256.convert(content).toString(),
);

void main() {
  late Directory dir;
  late List<String> logs;
  late List<String> opened;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('shiori_unpack_');
    logs = [];
    opened = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File unpacked() => File('${dir.path}/$_fileName');
  File marker() => File('${dir.path}/$_markerName');
  List<String> leftovers() => [
    for (final f in dir.listSync()) f.uri.pathSegments.last,
  ];

  MemoryAssetBundle bundleOf(List<int> gz) => MemoryAssetBundle({_gz: gz});

  Future<({List<int> value, bool unpacked})> open(
    MemoryAssetBundle bundle, {
    required AssetDigest expected,
    String edition = 'edition 1',
  }) => openUnpackedAsset(
    bundle: bundle,
    gzipAsset: _gz,
    editionText: edition,
    dir: dir,
    fileName: _fileName,
    markerName: _markerName,
    expected: expected,
    open: (file) {
      opened.add(file.path);
      return file.readAsBytesSync();
    },
    log: logs.add,
  );

  group('D2 unpacking checks the asset against its edition', () {
    test('a matching asset is unpacked, marked and opened', () async {
      final gz = gzip.encode(_content);
      final result = await open(bundleOf(gz), expected: _digestOf(_content));
      expect(result.unpacked, isTrue);
      expect(result.value, _content);
      expect(unpacked().readAsBytesSync(), _content);
      expect(marker().readAsStringSync(), 'edition 1');
      expect(leftovers()..sort(), [_fileName, _markerName]);
    });

    test(
      'a different sha256: not opened, nothing left, a typed error',
      () async {
        final gz = gzip.encode(_content);
        final other = _digestOf(_content);
        final expected = AssetDigest(
          gzipBytes: other.gzipBytes,
          sqliteBytes: other.sqliteBytes,
          sqliteSha256: 'f' * 64,
        );
        await expectLater(
          open(bundleOf(gz), expected: expected),
          throwsA(
            isA<UnpackedAssetMismatch>()
                .having(
                  (e) => e.field,
                  'field',
                  AssetMismatchField.sqliteSha256,
                )
                .having((e) => e.expected, 'expected', 'f' * 64)
                .having(
                  (e) => e.actual,
                  'actual',
                  sha256.convert(_content).toString(),
                )
                .having((e) => e.asset, 'asset', _gz),
          ),
        );
        expect(opened, isEmpty);
        expect(leftovers(), isEmpty, reason: 'no file, no .part, no marker');
      },
    );

    test('a different unpacked size is caught before the sha256', () async {
      final gz = gzip.encode(_content);
      final right = _digestOf(_content);
      final expected = AssetDigest(
        gzipBytes: right.gzipBytes,
        sqliteBytes: right.sqliteBytes + 1,
        sqliteSha256: right.sqliteSha256,
      );
      await expectLater(
        open(bundleOf(gz), expected: expected),
        throwsA(
          isA<UnpackedAssetMismatch>().having(
            (e) => e.field,
            'field',
            AssetMismatchField.sqliteBytes,
          ),
        ),
      );
      expect(opened, isEmpty);
      expect(leftovers(), isEmpty);
    });

    test('a gzip of another size is refused', () async {
      final gz = gzip.encode(_content);
      final right = _digestOf(_content);
      final expected = AssetDigest(
        gzipBytes: right.gzipBytes + 10,
        sqliteBytes: right.sqliteBytes,
        sqliteSha256: right.sqliteSha256,
      );
      await expectLater(
        open(bundleOf(gz), expected: expected),
        throwsA(
          isA<UnpackedAssetMismatch>().having(
            (e) => e.field,
            'field',
            AssetMismatchField.gzipBytes,
          ),
        ),
      );
      expect(leftovers(), isEmpty);
    });

    test('an asset cut short (gzip does not notice) is refused', () async {
      final gz = gzip.encode(_content);
      final half = gz.sublist(0, gz.length ~/ 2);
      // The edition matches the cut gzip's size: only the content gives it away.
      await expectLater(
        open(bundleOf(half), expected: _digestOf(_content, gz: half)),
        throwsA(isA<UnpackedAssetMismatch>()),
      );
      expect(opened, isEmpty);
      expect(leftovers(), isEmpty);
    });

    test('a refused asset of a new edition removes the old file and marker, '
        'and the next run tries again', () async {
      final gz = gzip.encode(_content);
      await open(bundleOf(gz), expected: _digestOf(_content));

      final bad = AssetDigest(
        gzipBytes: gz.length,
        sqliteBytes: _content.length,
        sqliteSha256: '0' * 64,
      );
      await expectLater(
        open(bundleOf(gz), expected: bad, edition: 'edition 2'),
        throwsA(isA<UnpackedAssetMismatch>()),
      );
      expect(leftovers(), isEmpty);

      final again = await open(
        bundleOf(gz),
        expected: _digestOf(_content),
        edition: 'edition 2',
      );
      expect(again.unpacked, isTrue);
      expect(marker().readAsStringSync(), 'edition 2');
    });
  });

  group('D3 later runs', () {
    test(
      'same marker and the file of the right size: not unpacked again',
      () async {
        final gz = gzip.encode(_content);
        await open(bundleOf(gz), expected: _digestOf(_content));
        final modified = unpacked().lastModifiedSync();

        // A broken archive proves the second run never reads it.
        final again = bundleOf(const [1, 2, 3]);
        final result = await open(again, expected: _digestOf(_content));
        expect(result.unpacked, isFalse);
        expect(result.value, _content);
        expect(again.loads, isNot(contains(_gz)));
        expect(unpacked().lastModifiedSync(), modified);
      },
    );

    test('same marker but the file changed size: unpacked again', () async {
      final gz = gzip.encode(_content);
      await open(bundleOf(gz), expected: _digestOf(_content));
      unpacked().writeAsBytesSync(_content.sublist(0, 100));

      final bundle = bundleOf(gz);
      final result = await open(bundle, expected: _digestOf(_content));
      expect(result.unpacked, isTrue);
      expect(bundle.loads, contains(_gz));
      expect(unpacked().readAsBytesSync(), _content);
    });

    test('same marker but no file: unpacked again', () async {
      final gz = gzip.encode(_content);
      await open(bundleOf(gz), expected: _digestOf(_content));
      unpacked().deleteSync();

      final result = await open(bundleOf(gz), expected: _digestOf(_content));
      expect(result.unpacked, isTrue);
      expect(unpacked().readAsBytesSync(), _content);
    });
  });

  group('AssetDigest.fromJson', () {
    test('reads the three fields the build scripts write', () {
      final d = AssetDigest.fromJson({
        'gzip_bytes': 12,
        'sqlite_bytes': 34,
        'sqlite_sha256': 'ab' * 32,
        'variant': 'lean',
      });
      expect(d.gzipBytes, 12);
      expect(d.sqliteBytes, 34);
      expect(d.sqliteSha256, 'ab' * 32);
    });

    test('a missing or malformed field is a FormatException', () {
      final good = <String, Object?>{
        'gzip_bytes': 12,
        'sqlite_bytes': 34,
        'sqlite_sha256': 'ab' * 32,
      };
      for (final key in good.keys) {
        expect(
          () => AssetDigest.fromJson({...good}..remove(key)),
          throwsFormatException,
          reason: 'without $key',
        );
      }
      for (final bad in <Map<String, Object?>>[
        {...good, 'gzip_bytes': '12'},
        {...good, 'sqlite_bytes': -1},
        {...good, 'sqlite_sha256': 'not hex'},
        {...good, 'sqlite_sha256': 'AB' * 32},
      ]) {
        expect(
          () => AssetDigest.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });
}
