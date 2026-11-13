// E5: 단어 찾기. A query finds words by headword, reading, key and Korean
// meaning; kana finds kanji headwords by their reading; katakana, width and
// spaces do not matter; the order puts the closest matches first; hidden
// words are found too; a playlist can narrow it. 8,000 made-up words stay
// well inside the time bound. Made-up words.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

void main() {
  final base = DateTime(2026, 11, 14);
  var made = 0;

  Word word(
    String head, {
    List<String> readings = const [],
    String meaning = '뜻',
    bool hidden = false,
  }) {
    made++;
    return Word(
      id: 'w$made',
      headword: head,
      readings: readings,
      meaning: meaning,
      createdAt: base.add(Duration(minutes: made)),
      hiddenAt: hidden ? base : null,
    );
  }

  late List<Word> words;
  late WordSearchIndex index;

  List<String> heads(List<Word> found) => [for (final w in found) w.headword];

  setUp(() {
    made = 0;
    words = [
      word('試語甲', readings: ['しごこう'], meaning: '시험 낱말 하나'),
      word('試語', readings: ['しご'], meaning: '시험 낱말'),
      word('しごか', meaning: '시험 꽃'),
      word('シゴト', meaning: '가짜 일'),
      word('予試語', readings: ['よしご'], meaning: '미리 시험'),
      word('試便だ', readings: ['しべんだ'], meaning: '편리함'),
      word('隠語', readings: ['いんご'], meaning: '숨긴 시험 말', hidden: true),
    ];
    index = WordSearchIndex(words);
  });

  test('searchFold: NFKC, no spaces, katakana as hiragana, lower case', () {
    expect(searchFold(' シゴ ト '), 'しごと');
    expect(searchFold('ｼｺﾞ'), 'しご');
    expect(searchFold('ＡＢＣ'), 'abc');
    expect(searchFold('試語'), '試語');
  });

  test('the index holds every word given', () {
    expect(index.length, words.length);
  });

  test('a headword, whole or in part', () {
    expect(heads(index.find('試語甲')), ['試語甲']);
    expect(heads(index.find('試語')), ['試語', '試語甲', '予試語']);
  });

  test('kana finds kanji headwords by reading; kana headwords too', () {
    expect(heads(index.find('しご')), ['試語', '試語甲', 'しごか', 'シゴト', '予試語']);
  });

  test('katakana, half width and spaces are folded', () {
    expect(heads(index.find('シゴ')), heads(index.find('しご')));
    expect(heads(index.find('ｼｺﾞｶ')), ['しごか']);
    expect(heads(index.find(' し ご か ')), ['しごか']);
  });

  test('a な-adjective with or without its だ', () {
    expect(heads(index.find('試便')), ['試便だ']);
    expect(heads(index.find('試便だ')), ['試便だ']);
  });

  test('a Korean meaning, in part, after the Japanese matches', () {
    expect(heads(index.find('시험')), ['試語', '隠語', '試語甲', 'しごか', '予試語']);
    expect(heads(index.find('낱말 하나')), ['試語甲']);
  });

  test('the order: whole, start, middle, meaning; then shorter, older', () {
    // しご: 試語 (reading whole) → 試語甲, しごか, シゴト (start; as long,
    // so the older first) → 予試語 (middle of よしご).
    final found = index.find('しご');
    expect(found.first.headword, '試語');
    expect(found.last.headword, '予試語');
  });

  test('hidden words are found and say so', () {
    final found = index.find('隠語');
    expect(found.single.isHidden, isTrue);
  });

  test('within narrows to a playlist\'s words', () {
    final ids = {words[0].id, words[4].id};
    expect(heads(index.find('試語', within: ids)), ['試語甲', '予試語']);
  });

  test('a blank query or no match finds nothing', () {
    expect(index.find(''), isEmpty);
    expect(index.find('   '), isEmpty);
    expect(index.find('試語己'), isEmpty);
  });

  test('8,000 words: the index in 300 ms, a query in 50 ms', () {
    const kana = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';
    final many = [
      for (var i = 0; i < 8000; i++)
        Word(
          id: 'm$i',
          headword: i.isEven
              ? String.fromCharCodes([
                  0x4E00 + i % 9000,
                  0x4E00 + (i * 7) % 9000,
                ])
              : '${kana[i % kana.length]}${kana[(i ~/ 3) % kana.length]}'
                    '${kana[(i ~/ 7) % kana.length]}',
          readings: i.isEven
              ? ['${kana[i % kana.length]}${kana[(i ~/ 5) % kana.length]}']
              : const [],
          meaning: '합성 낱말 $i',
          createdAt: base.add(Duration(seconds: i)),
        ),
    ];
    final sw = Stopwatch()..start();
    final big = WordSearchIndex(many);
    final built = sw.elapsedMilliseconds;
    expect(built, lessThanOrEqualTo(300), reason: 'index ${built}ms');
    for (final q in ['あ', 'かけ', '합성', '낱말 79', '一']) {
      sw
        ..reset()
        ..start();
      final found = big.find(q);
      final took = sw.elapsedMilliseconds;
      expect(found, isNotEmpty, reason: q);
      expect(took, lessThanOrEqualTo(50), reason: '$q ${took}ms');
    }
  });
}
