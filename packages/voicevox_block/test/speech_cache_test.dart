import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voicevox_block/voicevox_block.dart';

import 'support/fake_ops.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('speech_cache_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  const a = 'aa11';
  const b = 'bb22';
  const c = 'cc33';

  test('stores a sound and finds it again', () async {
    final cache = SpeechCache(dir: dir, maxBytes: 10000);
    expect(await cache.lookup(a), isNull);
    final wav = wavOf(10);
    final file = await cache.store(a, wav);
    expect(await file.readAsBytes(), wav);
    expect((await cache.lookup(a))?.path, file.path);
    expect(dir.listSync().whereType<File>().map((f) => f.path), [file.path]);
  });

  test(
    'keeps within the size cap, dropping the file used longest ago',
    () async {
      final one = wavOf(100).length;
      final cache = SpeechCache(dir: dir, maxBytes: one * 2);
      final fa = await cache.store(a, wavOf(100));
      await fa.setLastModified(DateTime(2026, 1, 1));
      final fb = await cache.store(b, wavOf(100));
      await fb.setLastModified(DateTime(2026, 1, 2));
      // Using a makes b the one used longest ago.
      expect(await cache.lookup(a), isNotNull);
      await cache.store(c, wavOf(100));
      expect(await cache.lookup(b), isNull);
      expect(await cache.lookup(a), isNotNull);
      expect(await cache.lookup(c), isNotNull);
    },
  );

  test(
    'never drops the sound just stored, even when it alone is too big',
    () async {
      final cache = SpeechCache(dir: dir, maxBytes: 10);
      await cache.store(a, wavOf(100));
      expect(await cache.lookup(a), isNotNull);
      await cache.store(b, wavOf(100));
      expect(await cache.lookup(a), isNull);
      expect(await cache.lookup(b), isNotNull);
    },
  );

  test('a damaged file is deleted and reported missing', () async {
    final cache = SpeechCache(dir: dir, maxBytes: 10000);
    final file = await cache.store(a, wavOf(50));
    final bytes = await file.readAsBytes();
    await file.writeAsBytes(bytes.sublist(0, bytes.length - 7));
    expect(await cache.lookup(a), isNull);
    expect(await file.exists(), isFalse);
  });

  test('refuses to store what is not a whole WAV file', () async {
    final cache = SpeechCache(dir: dir, maxBytes: 10000);
    expect(
      () => cache.store(a, Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(await cache.lookup(a), isNull);
  });

  test('refuses a key that is not lowercase hex', () async {
    final cache = SpeechCache(dir: dir, maxBytes: 10000);
    for (final bad in ['../x', 'AB12', '', 'a/b']) {
      expect(
        () => cache.store(bad, wavOf(4)),
        throwsArgumentError,
        reason: bad,
      );
      expect(() => cache.lookup(bad), throwsArgumentError, reason: bad);
    }
  });

  test('works when the folder does not exist yet', () async {
    final cache = SpeechCache(
      dir: Directory('${dir.path}/later/sounds'),
      maxBytes: 10000,
    );
    expect(await cache.lookup(a), isNull);
    await cache.store(a, wavOf(4));
    expect(await cache.lookup(a), isNotNull);
  });

  group('isWholeWav', () {
    test('accepts a whole file', () {
      expect(SpeechCache.isWholeWav(wavOf(3)), isTrue);
    });

    test('refuses a cut, a wrong header or a wrong size', () {
      final w = wavOf(30);
      expect(SpeechCache.isWholeWav(w.sublist(0, w.length - 1)), isFalse);
      expect(SpeechCache.isWholeWav(Uint8List(10)), isFalse);
      final notRiff = Uint8List.fromList(w)..[0] = 0x58;
      expect(SpeechCache.isWholeWav(notRiff), isFalse);
      final longer = Uint8List.fromList([...w, 0, 0]);
      expect(SpeechCache.isWholeWav(longer), isFalse);
    });
  });
}
