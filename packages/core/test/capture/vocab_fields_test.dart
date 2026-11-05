import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/capture/vocab/anchors.dart';
import 'package:shiori_core/src/capture/vocab/fields.dart';
import 'package:shiori_core/src/capture/vocab/layout.dart';
import 'package:shiori_core/src/capture/vocab/page_meta.dart';
import 'package:test/test.dart';

OcrLine line(
  String t, {
  double x = 0.1,
  double y = 0.5,
  double w = 0.05,
  double h = 0.02,
}) => OcrLine(text: t, x: x, y: y, width: w, height: h);

OcrScan scan({List<OcrLine> ja = const [], List<OcrLine> ko = const []}) =>
    OcrScan(
      japanese: OcrPage(lines: ja),
      korean: OcrPage(lines: ko),
    );

void main() {
  group('cell clean-up', () {
    test('cleanHead drops the number, checkbox noise and the star', () {
      expect(cleanHead('0009 □□□ 明日 ★'), '明日');
      expect(cleanHead('口晴れ', overCheckbox: true), '晴れ');
      expect(cleanHead('N天気', overCheckbox: true), '天気');
      expect(cleanHead('ロロロ 到着'), '到着');
    });

    test('splitPos reads the badge, fixing 통 and 몀', () {
      expect(splitPos('명 강, 개천'), (PartOfSpeech.noun, '강, 개천'));
      expect(splitPos('통 불다'), (PartOfSpeech.verb, '불다'));
      expect(splitPos('몀. 산'), (PartOfSpeech.noun, '산'));
      expect(splitPos('な형 조용하다'), (PartOfSpeech.naAdjective, '조용하다'));
      expect(splitPos('명'), (PartOfSpeech.noun, ''));
      expect(splitPos('명사가 아님'), (null, '명사가 아님'));
    });

    test('cleanMeaning normalizes width, commas and spaces', () {
      expect(cleanMeaning(' 강，  개천 .'), '강, 개천');
    });

    test('parseReadings splits on slashes and treats a dash as no reading', () {
      expect(parseReadings('あした/あす'), ['あした', 'あす']);
      expect(parseReadings('–'), isEmpty);
      expect(parseReadings('あした / あす'), ['あした', 'あす']);
      expect(parseReadings('ｶﾞｯｺｳ'), [
        'ガッコウ',
      ], reason: 'half-width katakana via NFKC');
    });

    test('cleanHead drops an OCR-read number and the checkbox edge bar', () {
      expect(cleanHead('0018O カ'), 'カ');
      expect(cleanHead('DO17 光る'), '光る');
      expect(cleanHead('|揺れる'), '揺れる');
      expect(cleanHead('DOOD'), 'DOOD', reason: 'not a number: too few digits');
    });

    test('readings: bar noise, glued neighbour text, spaced slashes', () {
      expect(parseReadings('| ゆれる'), ['ゆれる']);
      expect(parseReadings('ひかる で'), ['ひかる']);
      expect(readingText('あした / あす'), 'あした/あす');
      expect(isReadingCell('ひかる で'), isTrue);
      expect(isReadingCell('かわ 川'), isFalse);
      expect(isReadingCell('かわ 川', firstToken: true), isTrue);
      expect(isReadingCell('–'), isTrue);
      expect(isReadingCell(''), isFalse);
    });

    test('normTitle unifies the middle dot', () {
      expect(normTitle(' 여행 • 교통 '), '여행·교통');
      expect(normTitle('여행・교통'), '여행·교통');
    });
  });

  group('anchors', () {
    test('reads I, l and | as 1 and fills a number that lost a digit', () {
      final anchors = findAnchors([
        line('12I3 ロロロ', y: 0.30),
        line('1211 ロロロ', y: 0.10),
        line('121 ロロロ', y: 0.20),
        line('not a number', y: 0.40),
      ]);
      expect(anchors.map((a) => a.no), ['1211', '1212', '1213']);
    });

    test('reads 0 as O or D and a checkbox read as O after the number', () {
      final anchors = findAnchors([
        line('OO14', y: 0.10),
        line('0018O カ', y: 0.20),
        line('D02l', y: 0.30),
        line('DOOD', y: 0.40),
      ]);
      expect(anchors.map((a) => a.no), ['0014', '0018', '0021']);
    });

    test('a lone number away from the page column is not a page', () {
      final anchors = findAnchors([
        for (var k = 0; k < 4; k++) line('00${13 + k}', y: 0.2 + 0.05 * k),
        line('2010', x: 0.6, y: 0.3),
      ]);
      expect(anchors.map((a) => a.no), ['0013', '0014', '0015', '0016']);
    });

    test('a run of numbers that lost digits counts back from the next one', () {
      expect(
        findAnchors([
          line('08 ロロ', y: 0.1),
          line('09 ロロ', y: 0.15),
          line('0010', y: 0.2),
        ]).map((a) => a.no),
        ['0008', '0009', '0010'],
      );
    });

    test('a short number with nothing around it stays unknown', () {
      expect(findAnchors([line('14 ロロ')]).single.no, isNull);
    });

    test('a short number before a known one counts down', () {
      expect(
        findAnchors([
          line('09 ロロ', y: 0.1),
          line('0010', y: 0.2),
        ]).map((a) => a.no),
        ['0009', '0010'],
      );
    });

    test('a short number before 0001 stays unknown instead of 0000', () {
      final anchors = findAnchors([
        line('01 ロロ', y: 0.1),
        line('0001', y: 0.2),
      ]);
      expect(anchors.map((a) => a.no), [null, '0001']);
    });

    test('inferNumber counts by distance from the nearest known row', () {
      expect(inferNumber([null, null, '0010'], 0), 8);
      expect(inferNumber(['0008', null, '0010'], 1), 9);
      expect(inferNumber(['0015', null, null], 2), 17);
      expect(inferNumber([null, '0001'], 0), isNull);
      expect(inferNumber([null, null], 0), isNull);
    });

    test('anchorGap needs two anchors', () {
      expect(anchorGap(findAnchors([line('0001')])), isNull);
    });
  });

  group('page meta', () {
    test('reads DAY, title and page from the footer, fixing 이 → 01', () {
      final meta = readPageMeta(
        scan(ko: [line('PART 1 | DAY 이 자연, 몸 11', y: 0.95)]),
      );
      expect(meta, const PageMeta(day: 1, title: '자연, 몸', page: 11));
    });

    test('uses the Japanese pass DAY when the footer DAY is unreadable', () {
      final meta = readPageMeta(
        scan(
          ja: [line('DAY 21', y: 0.02)],
          ko: [line('DAY 그l 여행 • 교통 147', y: 0.95)],
        ),
      );
      expect(meta, const PageMeta(day: 21, title: '여행·교통', page: 147));
    });

    test('falls back to the DAY header and the page line', () {
      final meta = readPageMeta(
        scan(
          ko: [
            line('DAY', y: 0.05),
            line('01', y: 0.06),
            line('자연, 몸', y: 0.06),
            line('10 단어장 예시 페이지', y: 0.95),
          ],
        ),
      );
      expect(meta, const PageMeta(day: 1, title: '자연, 몸', page: 10));
    });

    test('the DAY digits must sit by the DAY label, not a word number', () {
      final meta = readPageMeta(
        scan(
          ko: [
            line('DAY', x: 0.85, y: 0.20),
            line('0017', x: 0.92, y: 0.21),
            line('10 단어장 예시 페이지', y: 0.95),
          ],
        ),
      );
      expect(meta, const PageMeta(day: null, title: null, page: 10));
    });

    test('a period in the footer title is a comma', () {
      final meta = readPageMeta(
        scan(ko: [line('PART 1 | DAY 01 자연. 몸 11', y: 0.95)]),
      );
      expect(meta.title, '자연, 몸');
    });

    test('empty page gives empty meta', () {
      expect(readPageMeta(scan()), PageMeta.empty);
    });
  });

  group('TemplateRegistry', () {
    final registry = TemplateRegistry(const [
      ListPageTemplate(),
      EntryPageTemplate(),
    ]);

    test('few numbers fall back to the list layout', () {
      expect(registry.detect(scan(ja: [line('0001')])).id, 'vocab.list');
    });

    // Made-up example sentences (synthetic set words).
    final sentences = [
      line('次の駅で急行に乗り換えてください。', y: 0.17, w: 0.3),
      line('窓口で大阪までの切符を買いました。', y: 0.32, w: 0.3),
    ];

    test('widely spaced numbers with an example mean the entry layout', () {
      final s = scan(
        ja: [
          line('1211', y: 0.1),
          line('1212', y: 0.25),
          line('1213', y: 0.4),
          ...sentences.take(1),
        ],
      );
      expect(registry.detect(s).id, 'vocab.entry');
    });

    test('a page without any example sentence is a list page, '
        'even when the few numbers read are far apart', () {
      final s = scan(ja: [line('0013', y: 0.2), line('0019', y: 0.5)]);
      expect(registry.detect(s).id, 'vocab.list');
    });

    test('three example sentences mean the entry layout '
        'even with fewer than two numbers read', () {
      final s = scan(
        ja: [
          line('1211', y: 0.1),
          ...sentences,
          line('朝の高速道路はいつも渋滞しています。', y: 0.5, w: 0.3),
        ],
      );
      expect(registry.detect(s).id, 'vocab.entry');
    });

    test('furigana and kana-only lines are not example sentences', () {
      expect(isSentenceLine(line('ひこうき よてい さんじゅっぷんはや')), isFalse);
      expect(isSentenceLine(line('問大 0015 강, 개천 안녕하세요')), isFalse);
      expect(isSentenceLine(sentences.first), isTrue);
    });

    test('looks templates up by id', () {
      expect(registry.byId('vocab.entry'), isA<EntryPageTemplate>());
      expect(registry.byId('nope'), isNull);
    });

    test('rejects an empty or duplicated template list', () {
      expect(() => TemplateRegistry(const []), throwsArgumentError);
      expect(
        () => TemplateRegistry(const [ListPageTemplate(), ListPageTemplate()]),
        throwsArgumentError,
      );
    });

    test('templates describe themselves for the review screen', () {
      for (final t in registry.templates) {
        expect(t.label, isNotEmpty);
        expect(t.suggestedTextbookTitle, isNotEmpty);
      }
    });

    test('an entry page without numbers has no entries', () {
      expect(const EntryPageTemplate().parse(scan()).entries, isEmpty);
    });
  });
}
