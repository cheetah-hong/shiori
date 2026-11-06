import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// The voice data asset folder and its edition file
/// (tools/voice/build_voice_asset.py).
const voiceAssetDir = 'assets/voice';
const voiceEditionAsset = '$voiceAssetDir/voice.edition.json';

/// The edition that was unpacked, kept in the voice folder.
const _markerName = 'voice.edition';

final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
final _gzipName = RegExp(r'^[A-Za-z0-9._-]+\.gz$');

/// One file of the voice data: unpacked to [path] (inside the voice folder)
/// from the gzip asset [gzip].
final class VoiceFile {
  const VoiceFile({
    required this.path,
    required this.gzip,
    required this.gzipBytes,
    required this.bytes,
    required this.sha256,
  });

  /// Throws [FormatException] when a field is missing, [path] leaves the
  /// voice folder or [gzip] names a folder.
  factory VoiceFile.fromJson(Map<String, Object?> json) {
    final path = _string(json, 'path');
    if (!isSafeRelativePath(path)) {
      throw FormatException('voice edition: unsafe path "$path"');
    }
    final gzip = _string(json, 'gzip');
    if (!_gzipName.hasMatch(gzip) || gzip.startsWith('.')) {
      throw FormatException('voice edition: unsafe gzip name "$gzip"');
    }
    final sha = _string(json, 'sha256');
    if (!_sha256Hex.hasMatch(sha)) {
      throw const FormatException('voice edition: no sha256');
    }
    return VoiceFile(
      path: path,
      gzip: gzip,
      gzipBytes: _size(json, 'gzip_bytes'),
      bytes: _size(json, 'bytes'),
      sha256: sha,
    );
  }

  final String path;
  final String gzip;
  final int gzipBytes;
  final int bytes;
  final String sha256;
}

/// What the voice edition file says.
final class VoiceEdition {
  const VoiceEdition({
    required this.variant,
    required this.builtOn,
    required this.coreVersion,
    required this.modelFile,
    required this.dictionaryDir,
    required this.styleId,
    required this.credit,
    required this.files,
  });

  /// Throws [FormatException] when a field is missing or a path leaves the
  /// voice folder.
  factory VoiceEdition.fromJson(Map<String, Object?> json) {
    final files = switch (json['files']) {
      final List<Object?> list => [
        for (final f in list)
          if (f is Map<String, Object?>)
            VoiceFile.fromJson(f)
          else
            throw const FormatException(
              'voice edition: a file is not an object',
            ),
      ],
      _ => throw const FormatException('voice edition: no files'),
    };
    final modelFile = _string(json, 'model_file');
    final dictionaryDir = _string(json, 'dictionary_dir');
    if (!isSafeRelativePath(modelFile) || !isSafeRelativePath(dictionaryDir)) {
      throw const FormatException('voice edition: unsafe model or dictionary');
    }
    if (!files.any((f) => f.path == modelFile)) {
      throw const FormatException('voice edition: the model is not listed');
    }
    if (!files.any((f) => f.path.startsWith('$dictionaryDir/'))) {
      throw const FormatException(
        'voice edition: the dictionary is not listed',
      );
    }
    if (files.map((f) => f.path).toSet().length != files.length) {
      throw const FormatException('voice edition: a path is listed twice');
    }
    return VoiceEdition(
      variant: _string(json, 'variant'),
      builtOn: _string(json, 'built_on'),
      coreVersion: _string(json, 'core_version'),
      modelFile: modelFile,
      dictionaryDir: dictionaryDir,
      styleId: _size(json, 'style_id'),
      credit: _string(json, 'credit'),
      files: List.unmodifiable(files),
    );
  }

  final String variant;
  final String builtOn;
  final String coreVersion;
  final String modelFile;
  final String dictionaryDir;
  final int styleId;
  final String credit;
  final List<VoiceFile> files;
}

/// A relative path that stays inside the folder it is joined to: no
/// leading `/`, no empty, `.` or `..` parts, no backslash.
bool isSafeRelativePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains('\\')) {
    return false;
  }
  return path.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
}

/// Why there is no voice data.
enum VoiceAssetsProblem {
  /// This build has no voice data.
  missing,

  /// The data does not match its edition file (or the edition is broken).
  damaged,

  /// Something else went wrong (storage full, …); trying again may help.
  failed,
}

sealed class VoiceAssetsResult {
  const VoiceAssetsResult();
}

/// The voice data, unpacked and checked, in [dir].
final class VoiceAssetsReady extends VoiceAssetsResult {
  const VoiceAssetsReady({required this.dir, required this.edition});

  final Directory dir;
  final VoiceEdition edition;

  String get modelPath => '${dir.path}/${edition.modelFile}';
  String get dictionaryPath => '${dir.path}/${edition.dictionaryDir}';
}

final class VoiceAssetsUnavailable extends VoiceAssetsResult {
  const VoiceAssetsUnavailable(this.problem, {required this.kind});

  final String problem;
  final VoiceAssetsProblem kind;
}

/// The gzip or its content does not match the edition.
final class _Mismatch implements Exception {
  const _Mismatch(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Unpacks the voice data into [dir] when its edition changed (each gzip
/// streamed through a `.part` file and checked against the edition's sizes
/// and sha256 before it takes its name), then gives the folder. Never throws.
///
/// Same edition as the marker and every file of the size it gives: used as
/// it is (the sha256 is checked when unpacking only). Otherwise the marker is
/// removed first, every file unpacked again, and the marker written last.
Future<VoiceAssetsResult> prepareVoiceAssets({
  required AssetBundle bundle,
  required Directory dir,
  required void Function(String message) log,
}) async {
  final String editionText;
  try {
    editionText = await bundle.loadString(voiceEditionAsset, cache: false);
  } on Object catch (error) {
    log('not in this build: $error');
    return VoiceAssetsUnavailable('$error', kind: VoiceAssetsProblem.missing);
  }
  final VoiceEdition edition;
  try {
    edition = switch (jsonDecode(editionText)) {
      final Map<String, Object?> json => VoiceEdition.fromJson(json),
      _ => throw const FormatException('voice edition: not a JSON object'),
    };
  } on FormatException catch (error) {
    log('edition: $error');
    return VoiceAssetsUnavailable('$error', kind: VoiceAssetsProblem.damaged);
  }
  try {
    await dir.create(recursive: true);
    final marker = File('${dir.path}/$_markerName');
    if (await _isCurrent(marker, editionText) &&
        await _allSized(dir, edition)) {
      return VoiceAssetsReady(dir: dir, edition: edition);
    }
    if (await marker.exists()) await marker.delete();
    final timer = Stopwatch()..start();
    for (final f in edition.files) {
      await _unpack(bundle, dir, f);
    }
    await marker.writeAsString(editionText, flush: true);
    log('unpacked ${edition.variant} in ${timer.elapsedMilliseconds} ms');
    return VoiceAssetsReady(dir: dir, edition: edition);
  } on _Mismatch catch (error) {
    log('damaged: $error');
    await _removeFiles(dir, edition);
    return VoiceAssetsUnavailable('$error', kind: VoiceAssetsProblem.damaged);
  } on Object catch (error) {
    log('not unpacked: $error');
    await _removeFiles(dir, edition);
    return VoiceAssetsUnavailable('$error', kind: VoiceAssetsProblem.failed);
  }
}

Future<bool> _isCurrent(File marker, String editionText) async =>
    await marker.exists() && await marker.readAsString() == editionText;

Future<bool> _allSized(Directory dir, VoiceEdition edition) async {
  for (final f in edition.files) {
    final file = File('${dir.path}/${f.path}');
    if (!await file.exists() || await file.length() != f.bytes) return false;
  }
  return true;
}

Future<void> _unpack(AssetBundle bundle, Directory dir, VoiceFile f) async {
  final ByteData data;
  try {
    data = await bundle.load('$voiceAssetDir/${f.gzip}');
  } on Object catch (error) {
    throw _Mismatch('${f.gzip} is not in the build ($error)');
  }
  if (data.lengthInBytes != f.gzipBytes) {
    throw _Mismatch(
      '${f.gzip} is ${data.lengthInBytes} bytes, the edition says ${f.gzipBytes}',
    );
  }
  final target = File('${dir.path}/${f.path}');
  await target.parent.create(recursive: true);
  final part = '${target.path}.part';
  final packed = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final bytes = f.bytes;
  final sha = f.sha256;
  try {
    final problem = await Isolate.run(
      () => _decodeCheckWrite(packed, bytes, sha, part),
    );
    if (problem != null) throw _Mismatch('${f.path}: $problem');
    await File(part).rename(target.path);
  } finally {
    final p = File(part);
    if (await p.exists()) await p.delete();
  }
}

/// Runs on a background isolate: streams the gzip into [partPath] while
/// counting and hashing; null when the result has [bytes] bytes and sha256
/// [sha], else what differs.
String? _decodeCheckWrite(
  Uint8List packed,
  int bytes,
  String sha,
  String partPath,
) {
  final out = File(partPath).openSync(mode: FileMode.write);
  final digest = _DigestSink();
  final hasher = sha256.startChunkedConversion(digest);
  var count = 0;
  var tooBig = false;
  final sink = _CallbackSink((chunk) {
    count += chunk.length;
    if (count > bytes) {
      tooBig = true;
      return;
    }
    hasher.add(chunk);
    out.writeFromSync(chunk);
  });
  try {
    final decoder = gzip.decoder.startChunkedConversion(sink);
    const step = 1 << 20;
    for (var at = 0; at < packed.length && !tooBig; at += step) {
      final end = at + step < packed.length ? at + step : packed.length;
      decoder.add(Uint8List.sublistView(packed, at, end));
    }
    decoder.close();
  } on FormatException catch (error) {
    out.closeSync();
    return 'not a gzip (${error.message})';
  }
  out.flushSync();
  out.closeSync();
  if (tooBig || count != bytes) return 'unpacks to $count bytes, not $bytes';
  hasher.close();
  final got = digest.value.toString();
  return got == sha ? null : 'sha256 is $got, the edition says $sha';
}

Future<void> _removeFiles(Directory dir, VoiceEdition edition) async {
  for (final f in edition.files) {
    for (final p in ['${dir.path}/${f.path}', '${dir.path}/${f.path}.part']) {
      try {
        final file = File(p);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Left for the next run, which unpacks again before using anything.
      }
    }
  }
}

String _string(Map<String, Object?> json, String key) => switch (json[key]) {
  final String v when v.isNotEmpty => v,
  _ => throw FormatException('voice edition: no $key'),
};

int _size(Map<String, Object?> json, String key) => switch (json[key]) {
  final int v when v >= 0 => v,
  _ => throw FormatException('voice edition: no $key'),
};

final class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

final class _CallbackSink implements Sink<List<int>> {
  _CallbackSink(this._onChunk);

  final void Function(List<int> chunk) _onChunk;

  @override
  void add(List<int> data) => _onChunk(data);

  @override
  void close() {}
}
