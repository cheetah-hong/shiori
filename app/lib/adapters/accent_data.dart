import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:voicevox_block/voicevox_block.dart';

/// Kanjium accent table asset and its edition file
/// (tools/voice/build_accent_asset.py).
const accentTableAsset = 'assets/accent/kanjium-accents.tsv.gz';
const accentEditionAsset = 'assets/accent/kanjium-accents.edition.json';

/// What the accent edition file says (shown on the 정보 screen).
final class AccentEdition {
  const AccentEdition({
    required this.builtOn,
    required this.entries,
    required this.license,
    required this.attribution,
  });

  final String builtOn;
  final int entries;
  final String license;
  final String attribution;
}

/// The accent table the app runs with; empty without data.
final class AccentData {
  const AccentData(this.table, this.edition);

  final AccentTable table;
  final AccentEdition? edition;
}

/// Loads and checks the accent table (gzip size, then size and sha256 of the
/// table). Never throws: without data, or with data that does not match its
/// edition, the table is empty and the reason logged.
Future<AccentData> openAccentData({
  required AssetBundle bundle,
  required void Function(String message) log,
}) async {
  final Map<String, Object?> json;
  try {
    final text = await bundle.loadString(accentEditionAsset, cache: false);
    json = switch (jsonDecode(text)) {
      final Map<String, Object?> m => m,
      _ => throw const FormatException('accent edition: not a JSON object'),
    };
  } on Object catch (error) {
    log('not in this build: $error');
    return AccentData(AccentTable.empty, null);
  }
  try {
    final edition = AccentEdition(
      builtOn: _string(json, 'built_on'),
      entries: _int(json, 'entries'),
      license: _string(json, 'license'),
      attribution: _string(json, 'attribution'),
    );
    final gzipBytes = _int(json, 'gzip_bytes');
    final tsvBytes = _int(json, 'tsv_bytes');
    final tsvSha = _string(json, 'tsv_sha256');
    final data = await bundle.load(accentTableAsset);
    if (data.lengthInBytes != gzipBytes) {
      throw FormatException(
        'gzip is ${data.lengthInBytes} bytes, the edition says $gzipBytes',
      );
    }
    final packed = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final table = await Isolate.run(() => _decode(packed, tsvBytes, tsvSha));
    return AccentData(table, edition);
  } on Object catch (error) {
    log('not used: $error');
    return AccentData(AccentTable.empty, null);
  }
}

/// [openAccentData] with the app's asset bundle.
Future<AccentData> openAppAccentData() =>
    openAccentData(bundle: rootBundle, log: _log);

AccentTable _decode(Uint8List packed, int bytes, String sha) {
  final raw = gzip.decode(packed);
  if (raw.length != bytes) {
    throw FormatException('table is ${raw.length} bytes, not $bytes');
  }
  final got = sha256.convert(raw).toString();
  if (got != sha) throw FormatException('table sha256 is $got, not $sha');
  return AccentTable.parse(utf8.decode(raw));
}

String _string(Map<String, Object?> json, String key) => switch (json[key]) {
  final String v when v.isNotEmpty => v,
  _ => throw FormatException('accent edition: no $key'),
};

int _int(Map<String, Object?> json, String key) => switch (json[key]) {
  final int v when v >= 0 => v,
  _ => throw FormatException('accent edition: no $key'),
};

void _log(String message) => debugPrint('[shiori] accent data: $message');
