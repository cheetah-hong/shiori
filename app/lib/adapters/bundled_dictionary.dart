import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jmdict_block/jmdict_block.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori_core/shiori_core.dart';

/// gzip of the JMdict SQLite file (tools/dict/build_app_asset.py).
const dictionaryAsset = 'assets/dict/jmdict-full-lean.sqlite.gz';

/// Which data the asset holds: JSON written next to it by the same script.
const dictionaryEditionAsset = 'assets/dict/jmdict-full-lean.edition.json';

/// Where the asset is unpacked inside the app support folder.
const dictionaryFileName = 'jmdict-full-lean.sqlite';

/// The edition file that was unpacked, kept next to the SQLite file.
const dictionaryMarkerName = 'jmdict-full-lean.sqlite.edition';

/// The data inside the dictionary asset (shown on the 정보 screen).
final class DictionaryEdition {
  const DictionaryEdition({
    required this.variant,
    required this.sourceSha256,
    required this.jmdictCreated,
    required this.builtOn,
  });

  /// Throws [FormatException] when a field is missing.
  factory DictionaryEdition.fromJson(Map<String, Object?> json) {
    String field(String key) => switch (json[key]) {
      final String v when v.isNotEmpty => v,
      _ => throw FormatException('dictionary edition: no $key'),
    };
    return DictionaryEdition(
      variant: field('variant'),
      sourceSha256: field('source_sha256'),
      jmdictCreated: field('jmdict_created'),
      builtOn: field('built_on'),
    );
  }

  /// `full-lean`: every JMdict entry, no glosses.
  final String variant;

  /// sha256 of the JMdict_e.gz the database was built from.
  final String sourceSha256;

  /// Date in the JMdict file header.
  final String jmdictCreated;

  /// Day the asset was built.
  final String builtOn;
}

/// The dictionary the app runs with: JMdict, or nothing and why.
final class BundledDictionary {
  const BundledDictionary.opened(
    JmdictDictionaryAdapter this.jmdict,
    this.edition,
  ) : problem = null;

  const BundledDictionary.unavailable(String this.problem)
    : jmdict = null,
      edition = null;

  final JmdictDictionaryAdapter? jmdict;
  final DictionaryEdition? edition;

  /// Why there is no dictionary (for the log and the 정보 screen).
  final String? problem;

  bool get isAvailable => jmdict != null;

  /// The block for the dictionary slot.
  Dictionary get dictionary => jmdict ?? const EmptyDictionary();

  /// Source, licence and notice of the data; null without a dictionary.
  DictionaryInfo? get info => jmdict?.info;

  void close() => jmdict?.close();
}

/// Unpacks the bundled JMdict into [supportDirectory] when its edition
/// changed, then opens it. Never throws: any failure is logged and answered
/// with [BundledDictionary.unavailable] (the app runs with no dictionary).
///
/// - First run, or a new edition: the gzip asset is decoded on a background
///   isolate into `<support>/jmdict-full-lean.sqlite` (through a `.part`
///   file), then the edition file is copied next to it as a marker.
/// - Same edition as the marker: the unpacked file is opened as it is. If it
///   no longer opens, it is unpacked again.
Future<BundledDictionary> openBundledDictionary({
  required AssetBundle bundle,
  required Future<Directory> Function() supportDirectory,
  void Function(String message) log = _log,
}) async {
  try {
    final editionText = await bundle.loadString(
      dictionaryEditionAsset,
      cache: false,
    );
    final edition = _parseEdition(editionText);
    final dir = await supportDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$dictionaryFileName');
    final marker = File('${dir.path}/$dictionaryMarkerName');

    if (await _isCurrent(marker, editionText) && await file.exists()) {
      try {
        return BundledDictionary.opened(_open(file), edition);
      } on Object catch (error) {
        log('the unpacked file does not open ($error); unpacking it again');
      }
    }
    if (await marker.exists()) await marker.delete();
    await _unpack(bundle, file);
    final JmdictDictionaryAdapter opened;
    try {
      opened = _open(file);
    } on Object {
      await _deleteIfPresent(file);
      rethrow;
    }
    await marker.writeAsString(editionText, flush: true);
    log('unpacked ${edition.variant}, JMdict ${edition.jmdictCreated}');
    return BundledDictionary.opened(opened, edition);
  } on Object catch (error, stack) {
    log('not available: $error\n$stack');
    return BundledDictionary.unavailable('$error');
  }
}

/// [openBundledDictionary] with the app's asset bundle and cache folder.
///
/// The cache folder, not the support folder: the file can always be made
/// again from the asset, so it stays out of device backups (iOS backs up
/// Application Support). If the system clears the cache, the next start
/// unpacks again.
Future<BundledDictionary> openAppDictionary() => openBundledDictionary(
  bundle: rootBundle,
  supportDirectory: getApplicationCacheDirectory,
);

DictionaryEdition _parseEdition(String text) => switch (jsonDecode(text)) {
  final Map<String, Object?> json => DictionaryEdition.fromJson(json),
  _ => throw const FormatException('dictionary edition: not a JSON object'),
};

Future<bool> _isCurrent(File marker, String editionText) async =>
    await marker.exists() && await marker.readAsString() == editionText;

JmdictDictionaryAdapter _open(File file) =>
    JmdictDictionaryAdapter(JmdictDictionary.open(file.path));

/// Decodes the gzip asset off the UI isolate. The SQLite file only appears
/// once it is complete.
Future<void> _unpack(AssetBundle bundle, File file) async {
  final data = await bundle.load(dictionaryAsset);
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

void _log(String message) => debugPrint('[shiori] dictionary: $message');
