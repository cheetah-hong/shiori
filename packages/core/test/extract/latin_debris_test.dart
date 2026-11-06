// C4–C5: Latin letters in a Korean line that are Japanese (or a mark) read
// as Latin, told from real Latin (JLPT, N3, TV, mp3, kg, T셔츠, a site's
// address); and what becomes of a meaning that has them: the bracket with
// the debris goes, else the sense with it when another sense is clean, else
// the meaning stays as read and is flagged. Made-up lines only.
import 'package:shiori_core/shiori_core.dart';
import 'package:shiori_core/src/extract/latin_debris.dart';
import 'package:test/test.dart';

import 'support/extract_fixtures.dart';
import 'support/stem_fixtures.dart';

/// Korean lines with real Latin in them: none has debris.
const List<String> _realLatin = [
  '텔레비전, TV',
  'TV를 보다',
  'CD, 콤팩트디스크',
  'PC방',
  'e메일, 전자 우편',
  '이메일(e-mail)',
  '와이파이(Wi-Fi)',
  'X선, 엑스레이',
  'T셔츠, 티셔츠',
  'U턴하다',
  'A형 혈액형',
  'SNS에 올리다',
  'OK, 좋아',
  'DVD를 빌리다',
  'USB 메모리',
  'mp3 파일',
  'MP3 플레이어',
  '킬로그램(kg)',
  '1kg, 1킬로그램',
  '5km를 달리다',
  '30cm 자',
  '미터(m)',
  '그램(g)',
  '리터(L)',
  '밀리리터(ml)',
  'A4 용지',
  '3D 영화',
  'CEO, 최고 경영자',
  'IT 기업',
  '홈페이지 주소(URL)',
  'www.example.com',
  'JLPT N3 합격',
  'N5 단어',
  '비타민C',
  'B급 영화',
  'AI, 인공 지능',
  'GPS, 위치 추적',
  'ATM, 현금 자동 입출금기',
  'K팝',
  'SF 소설',
  'PART 2 단어 | DAY 7 날씨',
  '무료 자료 example.com',
];

/// Korean lines with Japanese read as Latin (made-up debris of the shapes
/// OCR gives).
const List<String> _debris = [
  '걷다. (~qW)7의 꼴로)~(이)라고 하다',
  '관련어 27b3t 482t 명 기다리기로 함',
  '[문형] 명사 + MtE를 붙임',
  '4k(네)라고 대답함',
  'Ro는 원래 부지런함',
  '~D를 붙이면 됨',
  'q형 + 9 (하)고 나서',
  'tl(물었어?)라는 질문',
  '반짝 9hz 하다',
];

MeaningRepair _repair(String m) => repairLatinDebris(m);

void main() {
  group('C4 telling debris from real Latin', () {
    for (final s in _debris) {
      test('debris: $s', () => expect(hasLatinDebris(s), isTrue));
    }
    for (final s in _realLatin) {
      test('real: $s', () => expect(hasLatinDebris(s), isFalse));
    }
    test('Korean with no Latin has none', () {
      expect(hasLatinDebris('말하다, 이야기하다. (~의 꼴로) 부르다'), isFalse);
    });
  });

  group('C5 a meaning with debris', () {
    test('the bracket with the debris goes; the rest of the sense stays', () {
      final r = _repair('말하다, 걷다. (~qW)7의 꼴로)~(이)라고 하다');

      expect(r.meaning, '말하다, 걷다. ~(이)라고 하다');
      expect(r.kind, MeaningRepairKind.trimmed);
    });

    test('a bracket with debris after a clean sense', () {
      final r = _repair('먹다 (tl)');

      expect(r.meaning, '먹다');
      expect(r.kind, MeaningRepairKind.trimmed);
    });

    test('debris outside a bracket: its sense goes when another is clean', () {
      final r = _repair('먹다. 27b3t 나다');

      expect(r.meaning, '먹다');
      expect(r.kind, MeaningRepairKind.senseDropped);
    });

    test('the clean senses keep their order around a dropped one', () {
      final r = _repair('먹다. 27b3t 나다. 마시다');

      expect(r.meaning, '먹다. 마시다');
      expect(r.kind, MeaningRepairKind.senseDropped);
    });

    test('a bracket that is all debris leaves nothing: the sense goes', () {
      final r = _repair('먹다. (27b3t)');

      expect(r.meaning, '먹다');
      expect(r.kind, MeaningRepairKind.senseDropped);
    });

    test('one sense only: nothing is taken out, the meaning is flagged', () {
      const m = '27b3t 482t 명 기다리기로 함';
      final r = _repair(m);

      expect(r.meaning, m);
      expect(r.kind, MeaningRepairKind.flagged);
    });

    test('no clean sense: nothing is taken out, the meaning is flagged', () {
      const m = '27b3t 가다. 4k3 오다';
      final r = _repair(m);

      expect(r.meaning, m);
      expect(r.kind, MeaningRepairKind.flagged);
    });

    test('a meaning with no debris (real Latin too) is left as it is', () {
      for (final m in ['말하다, 이야기하다', '텔레비전, TV', '1kg, 1킬로그램']) {
        final r = _repair(m);
        expect(r.meaning, m);
        expect(r.kind, isNull, reason: m);
      }
    });

    group('on the review draft', () {
      List<OcrLine> row(String headword, String reading, double y) => [
        line(headword, 0.10, y),
        line(reading, 0.25, y),
      ];

      Future<CapturedEntry> entry(String meaning) async {
        final draft = await pageDraft(
          GeneralExtractor(lexicon: stemLexicon()),
          scan(ja: row('霧話', 'むわ', 0.10), ko: [line(meaning, 0.45, 0.10)]),
        );
        return draft.entries.singleWhere((e) => e.headword == '霧話');
      }

      test('a trimmed meaning is marked as corrected', () async {
        final e = await entry('말하다. (~qW)7의 꼴로)~라고 하다');

        expect(e.meaning, '말하다. ~라고 하다');
        expect(
          e.issues,
          contains(
            const EntryIssue.corrected(
              EntryField.meaning,
              note: latinDebrisRemovedNote,
            ),
          ),
        );
      });

      test('a dropped sense is marked as corrected', () async {
        final e = await entry('말하다. 27b3t 나다');

        expect(e.meaning, '말하다');
        expect(
          e.issues,
          contains(
            const EntryIssue.corrected(
              EntryField.meaning,
              note: latinDebrisRemovedNote,
            ),
          ),
        );
      });

      test('a meaning with debris in its only sense stays and is flagged '
          'unsure', () async {
        final e = await entry('약속 27b3t 482t 기다리기로 함');

        expect(e.meaning, '약속 27b3t 482t 기다리기로 함');
        expect(
          e.issues,
          contains(
            const EntryIssue.suspect(
              EntryField.meaning,
              note: latinDebrisUnsureNote,
            ),
          ),
        );
      });

      test('a meaning with real Latin gets no such mark', () async {
        final e = await entry('텔레비전 TV 보기');

        expect(e.meaning, '텔레비전 TV 보기');
        expect(
          e.issues.where(
            (i) =>
                i.note == latinDebrisRemovedNote ||
                i.note == latinDebrisUnsureNote,
          ),
          isEmpty,
        );
      });
    });
  });
}
