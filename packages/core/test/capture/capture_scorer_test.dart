// The scorer counts entries the answers do not ask for: a number read twice,
// a number not on the page, an entry without a number. Made-up answers and a
// template that returns fixed entries.
import 'package:shiori_core/eval.dart';
import 'package:shiori_core/shiori_core.dart';
import 'package:test/test.dart';

/// Returns [entries] for every scan.
final class _FixedTemplate implements TextbookTemplate {
  const _FixedTemplate(this.entries);

  final List<CapturedEntry> entries;

  @override
  String get id => 'vocab.list';

  @override
  String get label => 'fixed';

  @override
  String get suggestedTextbookTitle => 'fixed';

  @override
  double match(OcrScan scan) => 1.0;

  @override
  TemplateResult parse(OcrScan scan) =>
      TemplateResult(entries: entries, meta: const PageMeta(page: 1));
}

CapturedEntry _entry(String? no, String headword, String meaning) =>
    CapturedEntry(
      no: no,
      headword: headword,
      readings: const [],
      pos: PartOfSpeech.noun,
      meaning: meaning,
    );

GroundTruthEntry _answer(String no, String headword, String meaning) =>
    GroundTruthEntry(
      no: no,
      headword: headword,
      readings: const [],
      pos: '명',
      meaning: meaning,
    );

final _truth = GroundTruth([
  GroundTruthPage(
    page: 1,
    fixture: 'x001',
    day: null,
    title: null,
    entries: [
      _answer('0001', '机', '책상'),
      _answer('0002', '窓', '창문'),
      _answer('0003', '庭', '마당'),
    ],
  ),
]);

Future<CaptureScore> _score(List<CapturedEntry> entries) => scoreCapture(
  truth: _truth,
  loadScan: (_) async => const OcrScan(
    japanese: OcrPage(lines: []),
    korean: OcrPage(lines: []),
  ),
  pipeline: CapturePipeline(
    templates: TemplateRegistry([_FixedTemplate(entries)]),
    correctors: const [],
  ),
);

void main() {
  group('extra entries', () {
    test('a repeated number and a number not in the answers', () async {
      final score = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '', '창문'),
        _entry('0002', '窓', '창문'),
        _entry('0009', '門', '대문'),
      ]);
      final page = score.pages.single;
      expect(page.entries, 4);
      expect(page.extras, 2);
      expect(score.extras, 2);
      expect(page.mistakes, contains('DUP 0002 '));
      expect(page.mistakes, contains('EXTRA 0009 門'));
    });

    test('the later entry of a repeated number is the one scored', () async {
      final score = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '', '창문'),
        _entry('0002', '窓', '창문'),
        _entry('0003', '庭', '마당'),
      ]);
      expect(score.total('row'), (ok: 3, of: 3));
      expect(score.total('found'), (ok: 3, of: 3));
      expect(score.pages.single.extras, 1);
      expect(score.pages.single.mistakes, ['DUP 0002 ']);
    });

    test('an entry without a number is extra', () async {
      final score = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '窓', '창문'),
        _entry('0003', '庭', '마당'),
        _entry(null, '', '대문'),
      ]);
      expect(score.pages.single.entries, 4);
      expect(score.pages.single.extras, 1);
      expect(score.extras, 1);
      expect(score.pages.single.mistakes, ['EXTRA ---- ']);
      expect(score.total('row'), (ok: 3, of: 3));
    });

    test('no extras: scores and the table read as before', () async {
      final score = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '窓', '창문'),
        _entry('0003', '門', '마당'),
      ]);
      final page = score.pages.single;
      expect(page.entries, 3);
      expect(page.extras, 0);
      expect(score.extras, 0);
      expect(page.found, 3);
      expect(page.rowsOk, 2);
      expect(page.fields, {
        'headword': 2,
        'readings': 3,
        'pos': 3,
        'meaning': 3,
      });
      expect(page.mistakes, ["0003 bad=[headword] issues=[] got=門||명|마당"]);
      expect(
        score.table(verbose: true),
        '  1 0003 bad=[headword] issues=[] got=門||명|마당\n'
        'page tpl    n found head read  pos mean  row exJA exKO meta\n'
        '   1 list   3     3    2    3    3    3    2    -    - ok\n'
        '\n'
        'TOTAL  headword=2/3  readings=3/3  pos=3/3  meaning=3/3  '
        'ex_ja=0/0  ex_ko=0/0  row=2/3  found=3/3\n'
        'core fields wrong but NOT flagged (silent errors): 1\n'
        'core fields wrong and flagged for review: 0;  '
        'flagged but actually correct: 0',
      );
    });

    test('the extras summary lists every page and the total', () async {
      final none = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '窓', '창문'),
        _entry('0003', '庭', '마당'),
      ]);
      expect(
        none.extrasSummary(),
        'extra entries (repeated number, not in the answers or no number): 0\n'
        '  page 1: 3 entries, 0 extra',
      );
      final some = await _score([
        _entry('0001', '机', '책상'),
        _entry('0002', '', '창문'),
        _entry('0002', '窓', '창문'),
        _entry('0009', '門', '대문'),
      ]);
      expect(
        some.extrasSummary(),
        'extra entries (repeated number, not in the answers or no number): 2\n'
        '  page 1: 4 entries, 2 extra',
      );
    });
  });
}
