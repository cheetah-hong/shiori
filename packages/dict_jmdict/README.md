# dict_jmdict

JMdict(EDRDG의 일본어 사전)를 SQLite로 줄인 파일을 읽는 **순수 Dart** 패키지입니다.
Flutter에도, `shiori_core`에도 의존하지 않습니다. core의 `Lexicon` 포트(단어 추출기의 사전)에는 어댑터 패키지 `packages/jmdict_block`으로 끼웁니다.

하는 일은 하나입니다: **표기 여러 개를 한 번에 찾기**(`lookupForms`). 한자 표기는 그 항목의 한자 표기와, 가나는 읽기와(히라가나·가타카나 모두) 맞춰
항목, 표기, 그 표기의 읽기, 한자 표기 전부, 품사, 우선 표시·nf, `uk`(보통 가나로 씀)를 돌려줍니다. 검색 전용 표기(sK·sk)는 맞추지 않습니다.
(2026-11-06 전에는 읽기로 표제어 후보 찾기, 짝 확인, 헷갈리는 글자 고치기 제안도 했습니다. 가로줄 틀의 보정기와 함께 걷어냈습니다, `docs/dictionary.md` 머리말.)

뜻은 영어만 있습니다(JMdict에 한국어 뜻이 없음). 한국어 뜻은 사진과 한국어 뜻 사전(`packages/krdict_block`)에서 가져옵니다.

## 사용 예

```dart
import 'package:dict_jmdict/dict_jmdict.dart';

final dict = JmdictDictionary.open('/path/to/jmdict-full-lean.sqlite'); // 읽기 전용

dict.lookupForms(['雨', 'あめ', 'テレビ']);   // 표기마다 FormEntry 목록(없는 표기는 빠짐)
dict.info.attribution;                       // 앱 "정보" 화면에 보일 표기 문구
dict.close();
```

## API

| 메서드 | 하는 일 | 돌려주는 것 |
|---|---|---|
| `JmdictDictionary.open(path)` | DB를 읽기 전용으로 엽니다. 스키마 버전이 다르면 `JmdictFormatException` | |
| `JmdictDictionary.fromDatabase(db)` | 이미 열린 `CommonDatabase`를 씁니다(테스트는 메모리 DB) | |
| `lookupForms(forms)` | 표기 여러 개를 종류별 한 번의 질의로 | `Map<String, List<FormEntry>>` |
| `info` | 출처, JMdict 날짜, sha256, 판본, 라이선스, 표기 문구 | `DictionaryInfo` |

`close()` 뒤의 호출은 모두 `StateError`를 던집니다.

## 데이터 만들기

원본과 만든 DB는 git에 넣지 않습니다(`tools/dict/.gitignore`). 같은 원본에서는 같은 파일이 나옵니다.

```bash
# 원본(JMdict_e.gz)이 tools/dict/.cache에 없으면 EDRDG에서 https로 받고, 6개 판본을 만들어 크기표를 출력합니다.
# 특정 판으로 고정하려면 --expect-sha256 <원본 sha256> (다르면 종료 코드 3)
python3 tools/dict/build_jmdict_db.py --matrix
# 앱에 넣을 판(권고: 전체 항목, 뜻 없음)
python3 tools/dict/build_jmdict_db.py --entries all --glosses none --out tools/dict/out/jmdict-full-lean.sqlite
# 테스트 DB(JMdict 103개 항목, SQL 텍스트)
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
- 호출은 동기식입니다. 단어 추출기는 쪽 하나에 필요한 표기를 한 번에 묻습니다(`lookupForms`).

## 테스트

```bash
cd packages/dict_jmdict
dart pub get
dart analyze
dart test
```

테스트 DB `test/fixtures/mini_jmdict.sql`에는 JMdict 항목 103개만 있습니다(JMdict 데이터만).
