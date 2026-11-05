// One test per OCR trouble built into the synthetic pages
// (tools/synthetic/make_pages.py), so each rule is checked by name.
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final pipeline = standardPipeline();
  final drafts = <String, CaptureDraft>{};

  setUpAll(() async {
    for (final page in ['s010', 's011', 's140', 's147']) {
      drafts[page] = await pipeline.fromScan(await loadScan(page));
    }
  });

  CapturedEntry word(String page, String no) =>
      drafts[page]!.entries.singleWhere((e) => e.no == no);

  List<String> codes(CapturedEntry e) => [for (final i in e.issues) i.code];

  group('list layout (s010, s011)', () {
    test('the neighbouring page number column adds no words', () {
      expect(drafts['s010']!.entries.map((e) => e.no), [
        for (var n = 1; n <= 12; n++) n.toString().padLeft(4, '0'),
      ]);
    });

    test('a row whose number was not read is numbered from the next row', () {
      final e = word('s010', '0001');
      expect(e.headword, '雨', reason: 'checkbox glyph 問 removed');
    });

    test('checkbox glyphs under the number never reach the headword', () {
      expect(
        [
          for (final no in ['0004', '0005', '0007']) word('s010', no).headword,
        ],
        ['風', '雲', '雪'],
      );
    });

    test('unread one-kanji headwords are flagged, not guessed', () {
      for (final no in ['0002', '0003']) {
        final e = word('s010', no);
        expect(e.headword, isEmpty);
        expect(e.readings, isNotEmpty);
        expect(codes(e), ['headword:missing']);
      }
    });

    test('a misread meaning is not caught (the silent error)', () {
      final e = word('s010', '0005');
      expect(e.meaning, '구룸');
      expect(e.issues, isEmpty);
    });

    test('a lone katakana ロ with a reading becomes 口', () {
      final e = word('s010', '0008');
      expect(e.headword, '口');
      expect(e.issues.single.note, 'ロ → 口');
    });

    test('slash-separated readings, a headword split over two lines', () {
      expect(word('s010', '0009').readings, ['あした', 'あす']);
      expect(word('s010', '0010').headword, '天気予報');
    });

    test('a dash in the reading column (- – 一) means no reading', () {
      expect(word('s010', '0012').readings, isEmpty);
      expect(word('s011', '0024').readings, isEmpty);
      expect(codes(word('s010', '0012')), isEmpty);
    });

    test('POS badges: い형, 부, misread 몀 and 통, badge on its own line', () {
      expect(word('s010', '0011').pos, PartOfSpeech.iAdjective);
      expect(word('s010', '0012').pos, PartOfSpeech.adverb);
      expect(
        (word('s011', '0014').pos, word('s011', '0014').meaning),
        (PartOfSpeech.noun, '산'),
      );
      expect(word('s011', '0023').pos, PartOfSpeech.verb);
      expect(word('s011', '0015').meaning, '강, 개천');
    });

    test('look-alike katakana: タ in a kanji word, ル for る, カ for 力', () {
      expect(
        [
          for (final no in ['0016', '0017', '0018']) word('s011', no).headword,
        ],
        ['夕日', '光る', '力'],
      );
      expect([
        for (final no in ['0016', '0017', '0018'])
          word('s011', no).statusOf(EntryField.headword),
      ], everyElement(FieldStatus.corrected));
    });

    test('a 1 read as l in the number still finds the row', () {
      expect(word('s011', '0021').headword, '指');
    });

    test('an unread meaning is flagged; its badge still counts', () {
      final e = word('s011', '0022');
      expect((e.meaning, e.pos), ('', PartOfSpeech.noun));
      expect(codes(e), ['meaning:missing']);
    });

    test('page meta: DAY header and page line, or a footer with DAY 이', () {
      expect(
        drafts['s010']!.meta,
        const PageMeta(day: 1, title: '자연, 몸', page: 10),
      );
      expect(
        drafts['s011']!.meta,
        const PageMeta(day: 1, title: '자연, 몸', page: 11),
      );
    });
  });

  group('entry layout (s140, s147)', () {
    test('numbers with I, | or a lost digit are restored', () {
      expect(drafts['s140']!.entries.map((e) => e.no), [
        '1211',
        '1212',
        '1213',
        '1214',
        '1215',
        '1216',
      ]);
      expect(word('s147', '1274').headword, '包む');
    });

    test('a ★ glued to the headword or on its own line stays out', () {
      expect(word('s140', '1211').headword, '乗り換える');
      expect(word('s140', '1215').headword, '揺れる');
      expect(word('s147', '1272').headword, '売り場');
    });

    test('`명:` badge on its own line', () {
      final e = word('s140', '1212');
      expect((e.pos, e.meaning), (PartOfSpeech.noun, '표, 승차권'));
    });

    test('furigana stay out of the example; two lines join', () {
      expect(word('s140', '1213').example?.ja, '飛行機は予定より三十分早く空港に到着しました。');
    });

    test('the 관련어 and 문형 boxes end the example', () {
      expect(word('s140', '1213').example?.ko, '비행기는 예정보다 30분 일찍 공항에 도착했습니다.');
      expect(word('s140', '1215').example?.ko, '버스가 심하게 흔들려서 서 있을 수 없었다.');
    });

    test('garbage glued in front of a translation is dropped', () {
      expect(word('s140', '1212').example?.ko, '창구에서 오사카까지 가는 표를 두 장 샀습니다.');
      expect(word('s147', '1274').example?.ko, '선물이라서 예쁘게 포장해 주실 수 있나요?');
    });

    test('an example OCR did not read is marked missing', () {
      final e = word('s147', '1273');
      expect(e.example, isNull);
      expect(codes(e), ['example:missing']);
      expect(e.isFlagged, isFalse, reason: 'core cells are fine');
    });

    test('a katakana word with a dash reading', () {
      final e = word('s147', '1275');
      expect(e.headword, 'レシート');
      expect(e.readings, isEmpty);
      expect(e.issues, isEmpty);
    });

    test(
      'page meta from the footer; DAY from the Japanese pass when unreadable',
      () {
        expect(
          drafts['s140']!.meta,
          const PageMeta(day: 20, title: '여행·교통', page: 140),
        );
        expect(
          drafts['s147']!.meta,
          const PageMeta(day: 21, title: '쇼핑', page: 147),
        );
      },
    );

    test('the neighbouring page edge stays out of every entry', () {
      for (final e in drafts['s140']!.entries) {
        expect(e.example?.ko, isNot(contains('지도')), reason: e.no);
      }
    });
  });
}
