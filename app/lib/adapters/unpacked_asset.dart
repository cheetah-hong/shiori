import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Opens the SQLite file unpacked from a gzip asset in [dir], unpacking it
/// first when [editionText] (the asset's edition file) differs from the
/// marker kept next to it. Throws when the asset cannot be unpacked, does not
/// hold what [expected] says ([UnpackedAssetMismatch]), or the unpacked file
/// does not open with [open]; nothing of it is kept then (no file, no marker),
/// so the next run tries again. `unpacked` says whether this call unpacked
/// the asset.
///
/// - Same edition as the marker, and the unpacked file has the size the
///   edition gives: it is opened as it is. If it no longer opens, or its size
///   changed, it is unpacked again. (The sha256 is checked only when
///   unpacking: the files are opened read-only, and hashing 30 MB on every
///   start would cost a few hundred milliseconds each time.)
/// - First run, or a new edition: the asset is decoded on a background
///   isolate and checked against [expected] (gzip size, then SQLite size and
///   sha256) before anything is written; only then is it written to
///   `<dir>/<fileName>` (through a `.part` file) and the edition text written
///   as the marker.
Future<({T value, bool unpacked})> openUnpackedAsset<T>({
  required AssetBundle bundle,
  required String gzipAsset,
  required String editionText,
  required Directory dir,
  required String fileName,
  required String markerName,
  required AssetDigest expected,
  required T Function(File file) open,
  required void Function(String message) log,
}) async {
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  final marker = File('${dir.path}/$markerName');

  if (await _isCurrent(marker, editionText) &&
      await _hasSize(file, expected.sqliteBytes)) {
    try {
      return (value: open(file), unpacked: false);
    } on Object catch (error) {
      log('the unpacked file does not open ($error); unpacking it again');
    }
  }
  await _deleteIfPresent(marker);
  await _deleteIfPresent(file);
  final timer = Stopwatch()..start();
  await _unpack(bundle, gzipAsset, file, expected);
  final T opened;
  try {
    opened = open(file);
  } on Object {
    await _deleteIfPresent(file);
    rethrow;
  }
  await marker.writeAsString(editionText, flush: true);
  log('$gzipAsset: unpacked and checked in ${timer.elapsedMilliseconds} ms');
  return (value: opened, unpacked: true);
}

/// What an edition file says its gzip asset holds (both builders write
/// `gzip_bytes`, `sqlite_bytes` and `sqlite_sha256`).
final class AssetDigest {
  const AssetDigest({
    required this.gzipBytes,
    required this.sqliteBytes,
    required this.sqliteSha256,
  });

  /// Throws [FormatException] when a field is missing or malformed.
  factory AssetDigest.fromJson(Map<String, Object?> json) {
    int size(String key) => switch (json[key]) {
      final int v when v >= 0 => v,
      _ => throw FormatException('edition: no $key'),
    };
    return AssetDigest(
      gzipBytes: size('gzip_bytes'),
      sqliteBytes: size('sqlite_bytes'),
      sqliteSha256: switch (json['sqlite_sha256']) {
        final String v when _sha256Hex.hasMatch(v) => v,
        _ => throw const FormatException('edition: no sqlite_sha256'),
      },
    );
  }

  /// [AssetDigest.fromJson] of an edition file's text.
  factory AssetDigest.fromEditionText(String text) =>
      switch (jsonDecode(text)) {
        final Map<String, Object?> json => AssetDigest.fromJson(json),
        _ => throw const FormatException('edition: not a JSON object'),
      };

  static final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

  /// Size of the gzip asset.
  final int gzipBytes;

  /// Size of the SQLite file inside it.
  final int sqliteBytes;

  /// sha256 of the SQLite file inside it, lowercase hex.
  final String sqliteSha256;
}

/// Which check an asset failed.
enum AssetMismatchField { gzipBytes, sqliteBytes, sqliteSha256 }

/// The asset does not hold what its edition file says: cut short, damaged,
/// or from another build. Nothing was kept from it.
final class UnpackedAssetMismatch implements Exception {
  const UnpackedAssetMismatch({
    required this.asset,
    required this.field,
    required this.expected,
    required this.actual,
  });

  final String asset;
  final AssetMismatchField field;
  final String expected;
  final String actual;

  @override
  String toString() =>
      'UnpackedAssetMismatch: $asset ${field.name} is $actual, '
      'the edition says $expected';
}

Future<bool> _isCurrent(File marker, String editionText) async =>
    await marker.exists() && await marker.readAsString() == editionText;

Future<bool> _hasSize(File file, int bytes) async =>
    await file.exists() && await file.length() == bytes;

/// Decodes and checks the gzip asset off the UI isolate. The SQLite file
/// only appears once it is complete and matches [expected].
Future<void> _unpack(
  AssetBundle bundle,
  String asset,
  File file,
  AssetDigest expected,
) async {
  final data = await bundle.load(asset);
  if (data.lengthInBytes != expected.gzipBytes) {
    throw UnpackedAssetMismatch(
      asset: asset,
      field: AssetMismatchField.gzipBytes,
      expected: '${expected.gzipBytes}',
      actual: '${data.lengthInBytes}',
    );
  }
  final packed = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final part = File('${file.path}.part');
  try {
    final partPath = part.path;
    final sqliteBytes = expected.sqliteBytes;
    final sqliteSha256 = expected.sqliteSha256;
    // The check's result comes back as a value: an error thrown inside the
    // isolate may arrive wrapped.
    final mismatch = await Isolate.run(
      () => _decodeCheckAndWrite(packed, sqliteBytes, sqliteSha256, partPath),
    );
    if (mismatch != null) {
      throw UnpackedAssetMismatch(
        asset: asset,
        field: mismatch.field,
        expected: switch (mismatch.field) {
          AssetMismatchField.sqliteBytes => '$sqliteBytes',
          _ => sqliteSha256,
        },
        actual: mismatch.actual,
      );
    }
    await part.rename(file.path);
  } finally {
    await _deleteIfPresent(part);
  }
}

/// Runs on the background isolate: null when [packed] unpacks to
/// [sqliteBytes] bytes with sha256 [sqliteSha256] (then written to
/// [partPath]), else what differs. Dart's gzip decoder does not notice a
/// stream cut short, so the size and sha256 are what catch it.
({AssetMismatchField field, String actual})? _decodeCheckAndWrite(
  List<int> packed,
  int sqliteBytes,
  String sqliteSha256,
  String partPath,
) {
  final List<int> raw;
  try {
    raw = gzip.decode(packed);
  } on FormatException catch (error) {
    return (
      field: AssetMismatchField.sqliteBytes,
      actual: 'not a gzip (${error.message})',
    );
  }
  if (raw.length != sqliteBytes) {
    return (field: AssetMismatchField.sqliteBytes, actual: '${raw.length}');
  }
  final digest = sha256.convert(raw).toString();
  if (digest != sqliteSha256) {
    return (field: AssetMismatchField.sqliteSha256, actual: digest);
  }
  File(partPath).writeAsBytesSync(raw, flush: true);
  return null;
}

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}
