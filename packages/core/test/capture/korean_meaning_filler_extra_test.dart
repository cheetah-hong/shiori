// Added after the review: a glossary that fails on a lookup (a damaged file)
// leaves the meaning cell empty instead of stopping the page.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

final class _BrokenGlossary implements KoreanGlossary {
  const _BrokenGlossary();

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
  }) async => throw const FormatException('database disk image is malformed');

  @override
  List<GlossarySourceInfo> get sources => const [];
}

void main() {
  test(
    'a failing lookup leaves the empty meaning to the missing flag',
    () async {
      var e = const CapturedEntry(
        no: '0001',
        headword: '鼻',
        readings: ['はな'],
        pos: PartOfSpeech.noun,
        meaning: '',
      );
      for (final c in standardCorrectors(
        const EmptyDictionary(),
        glossary: const _BrokenGlossary(),
      )) {
        e = await c.correct(e);
      }
      expect(e.meaning, isEmpty);
      expect([for (final i in e.issues) i.code], ['meaning:missing']);
    },
  );
}
