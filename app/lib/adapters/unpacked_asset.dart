import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

/// Opens the SQLite file unpacked from a gzip asset in [dir], unpacking it
/// first when [editionText] (the asset's edition file) differs from the
/// marker kept next to it. Throws when the asset cannot be unpacked or the
/// unpacked file does not open with [open]; the file is then removed.
/// `unpacked` says whether this call unpacked the asset.
///
/// - Same edition as the marker: the unpacked file is opened as it is. If it
///   no longer opens, it is unpacked again.
/// - First run, or a new edition: the asset is decoded on a background
///   isolate into `<dir>/<fileName>` (through a `.part` file), then the
///   edition text is written as the marker.
Future<({T value, bool unpacked})> openUnpackedAsset<T>({
  required AssetBundle bundle,
  required String gzipAsset,
  required String editionText,
  required Directory dir,
  required String fileName,
  required String markerName,
  required T Function(File file) open,
  required void Function(String message) log,
}) async {
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  final marker = File('${dir.path}/$markerName');

  if (await _isCurrent(marker, editionText) && await file.exists()) {
    try {
      return (value: open(file), unpacked: false);
    } on Object catch (error) {
      log('the unpacked file does not open ($error); unpacking it again');
    }
  }
  if (await marker.exists()) await marker.delete();
  await _unpack(bundle, gzipAsset, file);
  final T opened;
  try {
    opened = open(file);
  } on Object {
    await _deleteIfPresent(file);
    rethrow;
  }
  await marker.writeAsString(editionText, flush: true);
  return (value: opened, unpacked: true);
}

Future<bool> _isCurrent(File marker, String editionText) async =>
    await marker.exists() && await marker.readAsString() == editionText;

/// Decodes the gzip asset off the UI isolate. The SQLite file only appears
/// once it is complete.
Future<void> _unpack(AssetBundle bundle, String asset, File file) async {
  final data = await bundle.load(asset);
  final packed = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final part = File('${file.path}.part');
  try {
    final partPath = part.path;
    await Isolate.run(
      () => File(partPath).writeAsBytesSync(gzip.decode(packed), flush: true),
    );
    await part.rename(file.path);
  } finally {
    await _deleteIfPresent(part);
  }
}

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}
