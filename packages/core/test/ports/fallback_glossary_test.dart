// W3: a glossary that answers from a second glossary only when the first
// has no sense for the word. Made-up words only.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

final class _Glossary implements KoreanGlossary {
  _Glossary(this.senses, this.source, {this.info = const []});

  final Map<String, List<List<String>>> senses;
  final GlossarySource source;
  final List<GlossarySourceInfo> info;
  final List<
    ({String headword, List<String> readings, int limit, PartOfSpeech? pos})
  >
  calls = [];

  @override
  Future<List<KoreanSense>> lookup(
    String headword, {
    List<String> readings = const [],
    int limit = 3,
    PartOfSpeech? pos,
  }) async {
    calls.add((headword: headword, readings: readings, limit: limit, pos: pos));
    return [
      for (final (i, words)
          in (senses[headword] ?? const []).take(limit).indexed)
        KoreanSense(words: words, source: source, senseNo: i + 1),
    ];
  }

  @override
  List<GlossarySourceInfo> get sources => info;
}

const _krdictInfo = GlossarySourceInfo(
  source: GlossarySource.krdict,
  publisher: '국립국어원',
  license: 'CC BY-SA 2.0 KR',
  licenseUrl: 'https://creativecommons.org/licenses/by-sa/2.0/kr/',
  edition: '2026-10-19',
);

const _wiktionaryInfo = GlossarySourceInfo(
  source: GlossarySource.wiktionary,
  publisher: '위키낱말사전 기여자',
  license: 'CC BY-SA 4.0',
  licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
  edition: '2026-11-01',
);

void main() {
  late _Glossary primary;
  late _Glossary fallback;
  late FallbackKoreanGlossary both;

  setUp(() {
    primary = _Glossary(
      {
        '雪森': [
          ['눈숲'],
          ['설삼'],
        ],
      },
      GlossarySource.krdict,
      info: const [_krdictInfo],
    );
    fallback = _Glossary(
      {
        '雪森': [
          ['겨울 숲'],
        ],
        '月道': [
          ['달길', '월로'],
          ['달빛 길'],
        ],
      },
      GlossarySource.wiktionary,
      info: const [_wiktionaryInfo],
    );
    both = FallbackKoreanGlossary(primary, fallback);
  });

  test('a word the first glossary knows: its senses only, the second is '
      'not asked', () async {
    final alone = await primary.lookup('雪森', readings: ['ゆきもり'], limit: 5);
    primary.calls.clear();

    final got = await both.lookup(
      '雪森',
      readings: ['ゆきもり'],
      limit: 5,
      pos: PartOfSpeech.noun,
    );

    expect(got, alone);
    expect({for (final s in got) s.source}, {GlossarySource.krdict});
    expect(fallback.calls, isEmpty);
    expect(primary.calls.single.pos, PartOfSpeech.noun);
  });

  test('a word the first glossary does not know: the second one\'s senses, '
      'asked the same way', () async {
    final got = await both.lookup(
      '月道',
      readings: ['つきみち'],
      limit: 4,
      pos: PartOfSpeech.noun,
    );

    expect([for (final s in got) s.text], ['달길, 월로', '달빛 길']);
    expect({for (final s in got) s.source}, {GlossarySource.wiktionary});
    final call = fallback.calls.single;
    expect(call.headword, '月道');
    expect(call.readings, ['つきみち']);
    expect(call.limit, 4);
    expect(call.pos, PartOfSpeech.noun);
  });

  test('neither knows the word: no senses', () async {
    expect(await both.lookup('風路', readings: ['かぜじ']), isEmpty);
  });

  test('the sources of both, the first glossary\'s first', () {
    expect(both.sources, [_krdictInfo, _wiktionaryInfo]);
  });

  test('a fallback that knows nothing changes nothing', () async {
    final empty = FallbackKoreanGlossary(primary, const EmptyKoreanGlossary());
    expect(
      await empty.lookup('雪森', limit: 5),
      await primary.lookup('雪森', limit: 5),
    );
    expect(await empty.lookup('月道'), isEmpty);
  });
}
