# dict_jmdict

JMdict(EDRDG의 일본어 사전)를 SQLite로 줄인 파일을 읽는 **순수 Dart** 패키지입니다.
Flutter에도, `shiori_core`에도 의존하지 않습니다. core의 `Dictionary` 포트에는 앱 쪽 어댑터로 끼웁니다
(`docs/dictionary.md` 7절).

하는 일은 세 가지입니다.

1. **읽기로 표제어 후보 찾기**: OCR이 표제어 `雨`를 못 읽었지만 읽기 `あめ`는 읽은 경우
2. **표기·읽기 짝 확인**: `夕べ【ゆうべ】`는 있음, `タベ【ゆうべ】`는 없음
3. **헷갈리는 글자 고치기 제안**: `タベ` → `夕べ`, `ー日` → `一日`, 규칙이 잘못 바꾼 `夕行` → `タ行`

뜻은 영어만 있습니다(JMdict에 한국어 뜻이 없음). 학습 카드의 한국어 뜻은 계속 교재에서 가져옵니다.

## 사용 예

```dart
import 'package:dict_jmdict/dict_jmdict.dart';

final dict = JmdictDictionary.open('/path/to/jmdict-full-lean.sqlite'); // 읽기 전용

dict.lookupByReading('に', requireKanji: true).first;   // 二【に】 common news1 ichi1 nf01
dict.hasPair('夕べ', 'ゆうべ');                           // true
dict.checkPair('本棚', 'ほんだな').match;                 // PairMatch.exact (전체판), 사전에 없으면 compound (本+棚)
dict.suggestHeadword('タベ', 'ゆうべ').first;             // 夕べ [タ→夕@0, ベ→べ@1]
dict.suggestHeadword('', 'さん', prefer: {WordClass.noun}); // 三, 酸, 賛, ...
dict.info.attribution;                                    // 앱 "정보" 화면에 보일 표기 문구
dict.close();
```

## API

| 메서드 | 하는 일 | 돌려주는 것 |
|---|---|---|
| `JmdictDictionary.open(path)` | DB를 읽기 전용으로 엽니다. 스키마 버전이 다르면 `JmdictFormatException` | |
| `JmdictDictionary.fromDatabase(db)` | 이미 열린 `CommonDatabase`를 씁니다(테스트는 메모리 DB) | |
| `lookupByReading(kana, {limit, requireKanji, prefer})` | 이 읽기로 인쇄되는 표제어 후보 | `List<HeadwordCandidate>`, 후보마다 `priority`, `rankReason` |
| `lookupByHeadword(headword, {limit})` | 이 표기의 단어와 읽기 | `List<DictionaryWord>` |
| `hasPair(headword, reading)` | 표기·읽기 짝이 **그대로** 있는가. 읽기가 비면 그 표기가 있는가 | `bool` |
| `checkPair(headword, reading)` | 교재 표기 차이를 허용한 짝 확인 | `PairCheck(match: PairMatch, dictionaryForm, parts)` |
| `suggestHeadword(ocrText, reading, {limit, prefer})` | 헷갈리는 글자 표로 OCR 표제어를 고칠 후보 | `List<HeadwordSuggestion>`, 후보마다 `edits` |
| `info` | 출처, JMdict 날짜, sha256, 판본, 라이선스, 표기 문구 | `DictionaryInfo` |

모든 호출은 동기식입니다. 전체판에서 `checkPair`는 평균 약 50µs, `suggestHeadword`는 약 20µs가 걸렸습니다
(Apple Silicon Mac, JIT). `close()` 뒤의 호출은 모두 `StateError`를 던집니다.
공개 결과(`List`)는 모두 수정할 수 없는 리스트입니다.

### 후보 순위

`lookupByReading`과 `suggestHeadword`는 다음 순서로 정렬합니다. 각 후보의 `rankReason`에 근거가 들어 있습니다
(예: `common news1 ichi1 nf01`).

1. `prefer`로 준 품사(교재의 품사 배지)와 맞는 단어. 걸러 내지는 않고 앞으로만 옮깁니다
2. 보통 표기를 드문 표기(`rK iK oK io rk ik ok`)보다 앞에
3. **짝 우선순위**: 표기와 읽기 **양쪽에 다 붙은** 태그만 셉니다(JMdict에서 우선순위는 특정 짝에만 붙기도 함.
   `獣`는 けもの로는 상용이지만 じゅう로는 태그가 없음). 이 태그로 상용(news1·ichi1·spec1·spec2·gai1) 여부,
   `nfXX` 빈도대(낮을수록 자주 쓰임), 태그가 하나라도 있는지, 태그 개수를 차례로 봅니다
4. 같은 항목의 태그 없는 다른 표기(`二`의 `２`, `弐`)는 다른 단어 뒤로 보냅니다
5. JMdict 항목 번호와 표기 순서

검색 전용 표기(`sK`, `sk`: 흔한 오기)는 `lookupByReading`과 `suggestHeadword` 어디에서도 후보로 내놓지 않습니다.
다만 짝 확인(`hasPair`, `checkPair`)에서는 있다고 보고, 그 표기 자체를 찾는 `lookupByHeadword`는 그 항목을 돌려줍니다.

### 짝 확인 규칙 (`PairMatch`)

| 결과 | 뜻 | 예 |
|---|---|---|
| `exact` | 짝이 그대로 있음(가나 단어는 읽기 없이 그 가나가 있음) | `二【に】`, `コーヒー` |
| `kanaScript` | 히라가나·가타카나를 바꾸면 있음 | `てれび` ~ `テレビ` |
| `spellingVariant` | 오쿠리가나만 다름. 한자가 같은 순서로 있고, 한자 뒤 가나 덩어리에서 더 짧은 쪽이 긴 쪽의 끝부분이며, 남는 글자가 히라가나일 때만 | `締め切` ~ `締め切り` |
| `affixStripped` | `〜`, 괄호 안 부분, 끝의 `する`·`な`(괄호 안이어도 됨)를 떼면 있음 | `勉強する【べんきょうする】`, `静か(な)【しずかな】` |
| `compound` | 한자를 포함한 사전 단어 두 개가 이어진 것. 읽기(히라가나로 맞춤)도 이어져야 하고, 뒤 단어의 연탁을 허용. 약한 확인 | `本+棚【ほんだな】` |
| `none` | 못 찾음. 검토 화면에 "확인 필요"로 표시할 것 | `タベ【ゆうべ】`, `夕行【たぎょう】` |

읽기가 인쇄돼 있는데 표제어가 그 읽기를 다른 문자로 쓴 것뿐이면(`ニ【に】`) `none`입니다.
한자를 가타카나로 잘못 읽었을 가능성이 크기 때문입니다.

### 헷갈리는 글자

기준 보정기(`parse_eval.py` 규칙 11)의 표를 그대로 쓰되 **양방향**으로 씁니다.
`{一 ー - —} {十 +} {二 ニ} {八 ハ} {口 ロ} {夕 タ} {工 エ} {力 カ}` 묶음 안에서 바꿀 수 있고,
가나는 히라가나·가타카나끼리 바꿀 수 있습니다(`ベ`↔`べ`).
`suggestHeadword`는 이 변형을 모두 만드는 대신, 읽기로 찾은 사전 표기와 글자마다 대조합니다(결과는 같음).
바꾼 글자 수가 적은 순서, 그다음 순위 순서로 돌려줍니다.

## 데이터 만들기

원본과 만든 DB는 git에 넣지 않습니다(`tools/dict/.gitignore`). 같은 원본에서는 같은 파일이 나옵니다.

```bash
# 원본(JMdict_e.gz)이 tools/dict/.cache에 없으면 EDRDG에서 https로 받고, 6개 판본을 만들어 크기표를 출력합니다.
# 특정 판으로 고정하려면 --expect-sha256 <원본 sha256> (다르면 종료 코드 3)
python3 tools/dict/build_jmdict_db.py --matrix
# 앱에 넣을 판(권고: 전체 항목, 뜻 없음)
python3 tools/dict/build_jmdict_db.py --entries all --glosses none --out tools/dict/out/jmdict-full-lean.sqlite
# 테스트 DB(JMdict 89개 항목, SQL 텍스트)
python3 tools/dict/build_jmdict_db.py --only tools/dict/test_forms.txt --glosses first \
    --sql packages/dict_jmdict/test/fixtures/mini_jmdict.sql
```

Python 3 표준 라이브러리만 씁니다. 스키마(버전 1)는 `build_jmdict_db.py`의 `SCHEMA`에 있습니다.

- `entry(id, pos, misc)`
- `kanji(entry_id, ord, text, pri, nf, inf)`
- `reading(entry_id, ord, text, pri, nf, inf, nokanji, restr)`
- `sense(entry_id, ord, pos, gloss)`
- `meta`, `tag`
- 색인: `kanji(text)`, `reading(text)`

## 라이선스 표기 (앱에 반드시 넣을 것)

JMdict는 EDRDG 라이선스(CC BY-SA 4.0)를 따릅니다. https://www.edrdg.org/edrdg/licence.html

- 앱의 별도 화면("정보", "출처" 등 메뉴에서 여는 화면)에 아래 문구와 링크를 보여 줍니다.
  시작 화면에만 두는 것은 안 됩니다. 문구는 `dict.info.attribution`에 들어 있습니다.

  > This application uses the JMdict dictionary files. These files are the property of the Electronic
  > Dictionary Research and Development Group, and are used in conformance with the Group's licence.
  > JMdict: https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project
  > Licence: https://www.edrdg.org/edrdg/licence.html

- 변환한 DB 파일도 CC BY-SA 4.0입니다(같은 조건으로 배포). 그 데이터에 저작권을 주장하지 않습니다.
- **데이터를 정기적으로 최신판으로 갱신하는 절차가 있어야 합니다**(라이선스 4절). 갱신하지 않으면 라이선스 위반입니다.
- 앱 코드는 공개하지 않아도 되고, 상업적 사용도 됩니다.

## Flutter에서 쓰는 방법 (이 패키지에서는 하지 않음)

- `sqlite3` 3.x는 빌드 훅으로 SQLite 바이너리를 앱에 넣으므로 `sqlite3_flutter_libs`가 필요 없습니다(그 패키지는 EOL).
  첫 빌드 때 훅이 GitHub 릴리스에서 sha256으로 확인된 바이너리를 받습니다. 오프라인 빌드에서는 `pubspec.yaml`의
  `hooks: user_defines: sqlite3: source: system`으로 OS의 SQLite를 쓸 수 있습니다.
- DB는 asset으로 넣고 첫 실행 때 앱 지원 폴더로 복사한 뒤 `JmdictDictionary.open(path)`로 엽니다.
  Android asset은 APK 안에 압축돼 있어서 SQLite가 바로 열 수 없습니다. asset과 함께 넣은 판 표시(원본 sha256)가 바뀌면 다시 복사합니다
  (`docs/dictionary.md` 7.4절).
- 호출은 동기식이고 빠르지만, 한 페이지(약 16줄)를 검사할 때는 캡처 파이프라인과 함께 `Isolate.run`에서 돌리는 것을 권합니다.

## 테스트

```bash
cd packages/dict_jmdict
dart pub get
dart analyze
dart test
```

테스트 DB `test/fixtures/mini_jmdict.sql`에는 JMdict 항목 89개만 있습니다(JMdict 데이터만).
측정 도구 `tool/query_batch.dart`는 `tools/dict/eval_dict.py`가 씁니다.
