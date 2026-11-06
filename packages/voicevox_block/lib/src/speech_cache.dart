import 'dart:io';
import 'dart:typed_data';

final _hexKey = RegExp(r'^[0-9a-f]+$');
var _nextPart = 0;

/// Sounds made before, as WAV files `<key>.wav` in [dir], at most [maxBytes]
/// in all (the files used longest ago go first).
final class SpeechCache {
  SpeechCache({required this.dir, required this.maxBytes});

  final Directory dir;
  final int maxBytes;

  /// The file for [key] when it is a whole WAV file (and marks it used);
  /// a damaged file is deleted and null returned, so the sound is made again.
  /// [key] is lowercase hex.
  Future<File?> lookup(String key) async {
    final file = _fileOf(key);
    if (!await file.exists()) return null;
    if (!isWholeWav(await file.readAsBytes())) {
      await _deleteQuietly(file);
      return null;
    }
    await file.setLastModified(DateTime.now());
    return file;
  }

  /// Writes [wav] for [key] (through a `.part` file), then deletes the files
  /// used longest ago until the cache fits [maxBytes] (never the new one).
  /// Throws [FormatException] when [wav] is not a whole WAV file.
  Future<File> store(String key, Uint8List wav) async {
    final file = _fileOf(key);
    if (!isWholeWav(wav)) {
      throw const FormatException('speech cache: not a whole WAV file');
    }
    await dir.create(recursive: true);
    // A name of its own per write: two writes of the same key never share
    // a part file, and the later rename simply replaces the earlier file.
    final part = File('${file.path}.${_nextPart++}.$pid.part');
    try {
      await part.writeAsBytes(wav, flush: true);
      await part.rename(file.path);
    } finally {
      if (await part.exists()) await _deleteQuietly(part);
    }
    await _trim(keep: file);
    return file;
  }

  /// A RIFF/WAVE file whose RIFF size and `data` chunk fit its length.
  static bool isWholeWav(Uint8List bytes) {
    if (bytes.length < 44) return false;
    final b = ByteData.sublistView(bytes);
    if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') return false;
    if (b.getUint32(4, Endian.little) != bytes.length - 8) return false;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final size = b.getUint32(at + 4, Endian.little);
      final end = at + 8 + size;
      if (end > bytes.length) return false;
      if (_tag(bytes, at) == 'data') return end == bytes.length;
      at = end + (size.isOdd ? 1 : 0);
    }
    return false;
  }

  File _fileOf(String key) {
    if (!_hexKey.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'is not lowercase hex');
    }
    return File('${dir.path}/$key.wav');
  }

  Future<void> _trim({required File keep}) async {
    final files = <(File, int, DateTime)>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.wav')) continue;
      final stat = await e.stat();
      files.add((e, stat.size, stat.modified));
    }
    var total = files.fold<int>(0, (sum, f) => sum + f.$2);
    files.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (file, size, _) in files) {
      if (total <= maxBytes) break;
      if (file.path == keep.path) continue;
      await _deleteQuietly(file);
      total -= size;
    }
  }

  static String _tag(Uint8List bytes, int at) =>
      String.fromCharCodes(bytes.sublist(at, at + 4));

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone (another call trimmed it): nothing to do.
    }
  }
}
