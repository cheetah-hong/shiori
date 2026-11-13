# 사전 블록(JMdict) 결과 보고

- 날짜: 2026-11-05 (KST)
- 결과물
  - `packages/dict_jmdict/`: 순수 Dart 패키지, 테스트, README
  - `tools/dict/`: 데이터 빌드 스크립트, 효과 측정 스크립트
  - 이 문서
- 처음 보고 때는 core와 `app/`을 건드리지 않고 7절을 제안으로 적었습니다. **7절은 이후 적용됐습니다**(위치는 7절, 결과는 `docs/verification.md` 8절).
- 교재 측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했습니다(4절).
- **2026-11-06 걷어냄:** 가로줄 틀 경로를 걷어내면서(`docs/extraction.md` 9절) 이 사전을 쓰던 보정기(표제어 후보, 짝 확인·「사전에 없음」, 헷갈리는 글자 고치기)와
  core `Dictionary` 포트·`JmdictDictionaryAdapter`, `dict_jmdict`의 그 질의(`lookupByReading`·`lookupByHeadword`·`hasPair`·`checkPair`·`suggestHeadword`)와 측정 도구
  (`tools/dict/eval_dict.py`, `tool/query_batch.dart`)도 걷어냈습니다. 지금 사전은 단어 추출기의 `Lexicon` 포트(`lookupForms`, 표기 여러 개를 한 번에)로만 씁니다.
  아래 1~10절은 그때의 결과 보고로 남깁니다.

## 1. 요약

- **앱에 넣을 판: `full-lean`(JMdict 전체 항목, 영어 뜻 없음)**
  - 크기: SQLite 30.5 MB, gzip 12.2 MB
  - 교재 59줄에서 오탐 0건, JLPT N5–N3 3,054개는 모두 사전에 있음
  - 상용어판(2.9 MB)은 작지만 교재 1줄과 JLPT 1.4%를 "사전에 없음"으로 잘못 표시합니다.
- **표제어를 못 읽은 두 줄**: 읽기만으로 둘 다 정답이 1순위입니다.
  - JLPT 한자 단어 2,601개로 모의 측정한 결과: 1순위 82.1%, 3순위 안 96.3%
  - 교재 품사 배지를 힌트로 주면 1순위 83.9%, 3순위 안 97.0%
- **헷갈리는 글자**: 규칙이 보정한 3줄은 보정 뒤 모두 사전 짝이 `exact`입니다.
  규칙 없이 사전만으로도 같은 답을 1순위로 냅니다.
  - JLPT 단어의 한자를 헷갈리는 가타카나로 바꿔 넣은 65개: 사전 65/65 검출·복원, 규칙 31/65(`ー日`, `+分`처럼 낱말 안의 `ー`/`+`를 규칙이 못 고침)
- **새로 찾은 문제**: 기준 보정 규칙 "한자가 있으면 헷갈리는 가타카나를 한자로"가 실제 단어 5,536개(상용 34개)를 망가뜨립니다.
  - 예: `アメリカ人`→`アメリ力人`, `ローマ字`→`口ーマ字`, `タ行`→`夕行`
  - 사전 짝 검사가 이 중 5,532개를 "사전에 없음"으로 잡고, 사전 제안은 5,535개를 원래 단어로 되돌립니다.
  - 놓친 4개는 바뀐 표기도 사전에 있거나(`一夕偏`) 합성어로 통과한 경우(`二短調` = `二`+`短調`)입니다(5.2절).
  - core의 `ConfusableGlyphCorrector`가 같은 규칙이므로 7.3절에 대안을 적었습니다.
- **오탐**: 교재에서 맞게 읽힌 57줄 중 0건, JLPT 3,054개 중 0건(전체판).
- **반드시 정할 것**: EDRDG 라이선스 4절은 **데이터 정기 갱신 절차**를 의무로 둡니다(8절).

## 2. 데이터

### 2.1 출처와 판

| 항목 | 값 |
|---|---|
| 원본 | EDRDG `JMdict_e.gz` (JMdict 일본어·영어 XML, Rev 1.09 DTD) |
| URL | https://www.edrdg.org/pub/Nihongo/JMdict_e.gz (`http://ftp.edrdg.org/…`와 같은 파일, TLS로 받음) |
| JMdict 날짜(파일 머리말) | 2026-11-04 |
| 서버 Last-Modified | Wed, 04 Nov 2026 11:05:58 GMT |
| 크기, sha256 | 10,592,854 bytes, `7f6dc7a4a50411e5a99c35969f28740e174714f04708ea84d50d6bdc09a001ed` |
| 항목 수 | 219,015 (표기 233,769, 읽기 265,958, 뜻 253,935) |
| 라이선스 | CC BY-SA 4.0, EDRDG General Dictionary Licence (https://www.edrdg.org/edrdg/licence.html) |

- **jmdict-simplified 대신 원본 XML을 쓴 이유**: 빈도대 태그 `nf01`~`nf48`가 원본에만 있어서 후보 순위 근거로 씁니다.
  jmdict-simplified에는 `common` 참·거짓만 있습니다.
- **재현**: EDRDG는 최신판만 내려 주므로, 같은 판은 위 sha256으로 확인합니다.
  `--expect-sha256 <값>`을 주면 다른 파일일 때 빌드를 멈춥니다.
  같은 원본에서 세 번 빌드해 DB sha256이 모두 같았습니다. 빌드 시각을 DB에 넣지 않습니다.
- 원본(`tools/dict/.cache/`)과 만든 DB(`tools/dict/out/`)는 `.gitignore`로 뺐습니다. 출처와 판 정보는 DB의 `meta` 테이블에 들어갑니다.
- **JMdict에는 한국어 뜻이 없습니다.** 학습 카드의 한국어 뜻은 계속 교재(OCR 한국어 판독)에서 가져옵니다.
  사전의 영어 뜻은 넣더라도 참고용입니다.

### 2.2 판본별 크기

`python3 tools/dict/build_jmdict_db.py --matrix` 출력입니다. 모든 판본의 스키마가 같아서 패키지는 어느 판이든 엽니다.

| 판본 | 설명 | 항목 | 표기 | 읽기 | 뜻(sense) | SQLite | gzip -9 |
|---|---|---:|---:|---:|---:|---:|---:|
| `full-all` | 전체 항목 · 모든 뜻 (전체판) | 219,015 | 233,769 | 265,958 | 253,935 | 42.4 MB | 17.8 MB |
| `full-first` | 전체 항목 · 첫 뜻만 | 219,015 | 233,769 | 265,958 | 219,015 | 40.6 MB | 17.0 MB |
| **`full-lean`** | **전체 항목 · 뜻 없음 (필요한 열만)** | 219,015 | 233,769 | 265,958 | 0 | **30.5 MB** | **12.2 MB** |
| `common-all` | 상용어만 · 모든 뜻 | 22,650 | 26,577 | 27,606 | 37,200 | 4.8 MB | 2.1 MB |
| `common-first` | 상용어만 · 첫 뜻만 | 22,650 | 26,577 | 27,606 | 22,650 | 4.0 MB | 1.8 MB |
| `common-lean` | 상용어만 · 뜻 없음 | 22,650 | 26,577 | 27,606 | 0 | 2.9 MB | 1.2 MB |

- **상용어**: JMdict의 정의(news1·ichi1·spec1·spec2·gai1 중 하나라도 있는 항목)를 따릅니다. 그런 항목은 모든 표기를 남깁니다.
- **크기 구성(`full-lean`)**: 읽기 테이블 30%, 읽기 색인 25%, 표기 테이블 19%, 표기 색인 16%, 항목(품사) 10%.
  - 기본 키를 `(text, …)`로 바꿔 색인을 없애는 방법도 시험했지만 크기가 같았습니다. WITHOUT ROWID 테이블의 보조 색인에 기본 키가 다 들어가기 때문입니다.
  - 남은 용량은 대부분 조회에 필요한 텍스트 색인입니다.

### 2.3 판본별 정확도와 권고

| 측정 (5절) | `full-lean` | `common-lean` |
|---|---|---|
| 교재: 맞는 줄인데 "사전에 없음"(오탐) | **0/57** | 1/57 (맞게 읽힌 줄 하나: 한자에 가나 오쿠리가나가 붙은 그 단어가 상용어판에 없음) |
| JLPT N5–N3 3,054개 중 "사전에 없음" | **0** | 43 (1.4%) (`お酒`, `私`, `お互い` 등) |
| 표제어 빠진 줄 제안(모의, 3순위 안) | 96.3% | 96.0% |
| 규칙이 망가뜨린 가타카나+한자 단어: 짝 검사가 잡음 / 제안이 되돌림 | 5,532 / 5,535 (5,536개 중) | 5,534 / 44 (외래어 합성어 대부분이 상용어판에 없음) |

**권고: `full-lean`을 앱에 넣습니다.**

- 교재 뜻은 OCR로 가져오므로 영어 뜻 열은 필요 없습니다. 뜻을 보여 주고 싶으면 `full-first`(+10 MB)입니다.
- 상용어판은 작지만, 교재의 N5–N3 단어조차 상용 표시가 없는 경우가 있습니다.
  그 결과 맞는 줄을 틀렸다고 표시합니다(그런 교재 단어 중 두 개는 합성어 규칙으로 통과했고 한 개는 못 막음).
- 탑재 방법(7.4절)
  - gzip 12.2 MB를 asset으로 넣고 첫 실행 때 풀면, 내려받는 크기는 줄지만 설치 후 디스크는 약 42 MB를 씁니다.
  - 압축하지 않은 30.5 MB를 asset으로 넣어도 앱 스토어 다운로드는 zip으로 압축됩니다.

## 3. 패키지 `dict_jmdict`

API와 규칙은 `packages/dict_jmdict/README.md`에 있습니다. 요약입니다.

| 메서드 | 하는 일 |
|---|---|
| `lookupForms(forms)` | 표기 여러 개를 한 번에: 한자 표기·가나 읽기(두 문자 모두) → 항목, 표기, 읽기, 한자 표기 전부, 품사, 우선 표시·nf, `uk` (단어 추출기, `docs/extraction.md` 6절) |
| `info` | 출처, 날짜, sha256, 라이선스, 표기 문구 |

(2026-11-06 전에는 `lookupByReading`·`hasPair`·`checkPair`·`suggestHeadword`·`lookupByHeadword`가 더 있었습니다. 아래 검증 숫자는 그때의 것입니다.)

- **의존성**: `sqlite3: ">=3.4.0 <3.6.0"` 하나뿐입니다(dart:ffi, 빌드 훅으로 SQLite 동봉. `packages/storage_drift`와 같은 범위: 3.6부터는 Flutter 3.41이 고정한 meta 1.17과 맞지 않음). Flutter와 core에는 의존하지 않습니다. 루트 workspace 파일은 만들지 않았습니다.
- **검증**
  - `dart analyze`: 문제 없음
  - `dart test`: 63개 모두 통과(테스트 DB를 103개 항목으로 다시 만든 뒤에도 같음)
  - 라인 커버리지: 96.2%(462/480)
- **테스트 DB**: `test/fixtures/mini_jmdict.sql`(JMdict 103개 항목, SQL 텍스트 52 KB. 사전 연결 때 `一日`·`日`·`空`·`カ月`을 더함)
  - 동음어 묶음(に·さん·はち·じゅう·ゆうべ), 헷갈리는 한자 단어, 가타카나+한자 단어(タ行·カ所·ハ長調),
    오쿠리가나 변형, 합성어 부품(本·棚 등), re_restr·re_nokanji·검색 전용 표기를 넣었습니다.
  - JMdict 데이터만 들어 있습니다.
- **속도**: 전체판에서 `checkPair` 평균 40–60µs, `suggestHeadword` 17–27µs(Apple Silicon Mac, JIT, 약 2만 번 호출).

## 4. 측정 방법

`python3 tools/dict/eval_dict.py [--verbose]`로 실행합니다.

- **교재 59줄**: 기준 해석기 `parse_eval.py`(기본 `tools/reference`, 없으면 `research/ocr/prototype`)를 import해 비공개 세트 5쪽을 해석합니다.
  - 기록된 OCR 결과와 정답은 비공개 폴더 `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/`에서 읽습니다(`SHIORI_PRIVATE_DIR` 기본값은 `<repo>/.private`).
  - 보정기가 돌기 전의 표제어도 기록합니다(`correct`를 감싸서).
  - 사전 호출은 모두 Dart 패키지(`tool/query_batch.dart`)로 합니다. 측정값은 실제 패키지의 동작입니다.
- **JLPT N5–N3 모의**: 59줄은 표본이 작아서(표제어 빠진 줄 2개, 규칙 보정 3개) 넓은 목록으로 같은 검사를 흉내 냈습니다.
  - 목록: Waller의 JLPT 목록에 JMdict 번호를 붙인 것(github.com/stephenmk/yomitan-jlpt-vocab, CC BY-SA 4.0)
  - N5 684, N4 640, N3 1,730개입니다. `.cache`에만 받고 저장소와 앱에는 넣지 않습니다.
- 교재 본문(OCR 결과, 정답)은 메모리에서만 쓰고, 저장소에 들어가는 파일에는 쓰지 않습니다.

## 5. 측정 결과

### 5.1 교재 59줄 (기준 해석기 + 사전 검사, `full-lean`)

| 항목 | 결과 |
|---|---|
| (a) 표제어를 못 읽은 두 줄(읽기는 읽음) | **둘 다 정답이 1순위**. 품사 힌트(명사 배지)를 줘도 둘 다 1순위 |
| (b) 표제어·읽기가 틀린 줄 | 2줄(위의 두 줄). 해석기가 이미 2줄 모두 "표제어 없음"으로 표시, 사전도 2줄 모두 표시 |
| (b) 사전이 새로 잡은 줄 | **0** (59줄 안에 표시 없이 틀린 표제어·읽기가 없음) |
| (b) 규칙 보정 3줄 | 보정 전에는 3줄 모두 짝 없음, 보정 뒤 모두 짝 `exact`. 사전만으로도 3줄 모두 보정 결과가 1순위 |
| (c) 맞는 줄을 "사전에 없음"으로 표시(오탐) | **0/57** |
| 짝 검사 결과(읽기 60개) | 전부 `exact` |

- 2026-11-05에 다시 돌려도 같은 수치가 나왔습니다.
- **(b)가 0인 이유**: 남은 오류 7줄 중 사전이 볼 수 있는 칸(표제어·읽기)의 오류는 위의 두 줄이고,
  둘 다 이미 "표제어 없음"으로 표시됩니다. 나머지 5줄(한국어 뜻 한 글자 오판독 1, 한국어 뜻 누락 1, ★ 누락 3)은 한국어 뜻과 ★ 칸이라 사전으로 검사할 수 없습니다.
  (★ 칸은 2026-11에 채점에서 걷어냈습니다(verification.md 10절). 지금 기준으로 남은 오류는 4줄이고, 사전이 볼 수 있는 칸의 오류는 같은 두 줄입니다.)
  즉 0은 "효과 없음"이 아니라 이 표본에 사전이 잡을 오류가 없었다는 뜻입니다. 5.2절 모의 측정으로 보완했습니다.

### 5.2 JLPT N5–N3 모의 (`full-lean`)

| 측정 | 결과 |
|---|---|
| (c′) 단어 3,054개(N5 684, N4 640, N3 1,730)를 짝 검사 → "사전에 없음" | **0** (모두 `exact`) |
| (a′) 한자 단어 2,601개의 표제어를 지우고 읽기로 제안 → 1순위 / 3순위 안 / 5순위 안 | 82.1% / 96.3% / 98.4% |
| (a′) 같은 측정에 품사 힌트(정답 항목의 품사) → 1순위 / 3순위 안 / 5순위 안 | **83.9% / 97.0% / 98.7%** |
| (b′) 한자를 헷갈리는 글자로 바꿔 넣은 단어(`一`→`ー`, `十`→`+`, `二`→`ニ`, `夕`→`タ` 등) | 65개 |
| (b′) 짝 검사가 오류로 잡음 | **65/65** |
| (b′) 사전 제안 1순위가 원래 단어 | **65/65** |
| (b′) 기준 규칙 보정기가 원래 단어로 고침 | 31/65 (`ー日`, `ー緒`, `+分`, `唯ー`처럼 낱말 안의 `ー`·`+`는 규칙 대상이 아님) |
| (b″) 기준 규칙이 실제 가타카나+한자 단어를 바꿔 버림 | 5,536개 (상용 34개) |
| (b″) 그 결과를 짝 검사가 잡음 / 사전 제안이 원래 단어로 되돌림 | 5,532 / 5,535 |

- **(b″)에서 짝 검사가 놓친 4개**
  - `一タ偏`→`一夕偏`: 바뀐 표기도 JMdict에 있습니다.
  - `ニ短調`·`ニ長調`·`ニ調`→`二…`: `二`+`短調`처럼 합성어 규칙으로 통과합니다.
    JMdict의 읽기는 `ニたんちょう`(가타카나 섞임)지만, 합성어 판정이 읽기를 히라가나로 맞춘 뒤 나누므로 통과합니다.
    교재처럼 읽기가 히라가나(`にたんちょう`)로 인쇄된 경우에도 똑같이 통과합니다.
  - **합성어 확인은 약한 확인**입니다. 보정기에서는 OCR 원문이 정확히 사전에 있으면 원문을 우선합니다(7.3절).
  - 사전 제안은 이 4개 중 `ニ…` 3개를 되돌립니다(규칙 결과에서 `二`→`ニ` 한 글자를 되돌린 원래 표기가 1순위). `一夕偏`은 그대로 둡니다.
- **(a′) 1순위를 놓친 경우**: 대부분 문맥 없이는 가릴 수 없는 동음이의어입니다(会う/合う, 暑い/熱い/厚い, 書く/欠く).
  `何時`, `居る`, `此処`처럼 보통 가나로 쓰는 단어(JMdict `uk`)는 한자 표기가 뒤로 밀립니다.
  **검토 화면에서는 후보를 3개 이상 보여 주는 것을 권합니다**(3순위 안 97%).
- **모의 측정의 한계**
  - stephenmk 목록은 드문 표기를 JMdict의 흔한 표기로 바꿔 둔 것이라 (c′) 오탐률이 실제보다 낮게 나올 수 있습니다.
  - 품사 힌트는 정답 항목의 JMdict 품사로 흉내 냈습니다.

### 5.3 순위 규칙을 바꾼 근거

측정 중 놓친 사례를 보고 세 가지를 고쳤고, 위 수치는 고친 뒤의 것입니다.

| 놓친 사례 | 원인 | 바꾼 규칙 | 효과 |
|---|---|---|---|
| `二`→`ニ`(읽기 に)을 못 잡음 | 가타카나 단어 `ニ`와 조사 `に`가 있어 문자만 바꾼 짝으로 통과 | 읽기가 인쇄됐는데 표제어가 그 읽기 자체면 `none`. 제안에서도 맨 뒤 | (b′) 64→65/65 |
| 상위 3개에 `２`(`二`의 전각 숫자 표기)가 낌 | 태그 없는 표기를 항목 번호순으로 정렬 | 같은 항목의 태그 없는 다른 표기는 다른 단어 뒤로 | 읽기 に의 상위 3: 二 荷 似 |
| `書く`(かく)가 5위 밖 | 빈도대가 낮은 명사(核, 格, 画)가 앞섬 | 품사 힌트 `prefer`(걸러 내지 않고 앞으로만) | (a′) 1순위 +1.8%p |

## 6. 교재 표기와 사전 표제어가 다를 때의 처리 규칙

`checkPair`가 아래 순서로 시도합니다. `none`만 "확인 필요"로 표시합니다.

| 순서 | 경우 | 규칙 | 결과 | 표시 |
|---|---|---|---|---|
| 1 | 짝이 그대로 있음 | 표기·읽기가 사전의 한 항목에 있고 re_restr·re_nokanji를 지킴 | `exact` | 없음 |
| 2 | 가나 단어(교재 읽기 칸 `–`) | 표제어가 사전의 읽기로 있음(어느 항목이든) | `exact` | 없음 |
| 3 | 읽기가 인쇄됐는데 표제어가 그 읽기를 다른 문자로 쓴 것 | (`ニ【に】`) 한자 오인식으로 봄 | `none` | 확인 필요 |
| 4 | 히라가나·가타카나 차이 | 표기·읽기의 문자를 바꿔서 있음 (`ゴミ`~`ごみ`) | `kanaScript` | 없음 |
| 5 | 오쿠리가나 차이 | 같은 읽기의 사전 표기와 한자가 같은 순서이고, 한자 뒤 가나 덩어리마다 짧은 쪽이 긴 쪽의 끝이며 남는 글자가 히라가나 (`締切`~`締め切り`, `終る`~`終わる`). 앞에 붙는 `お`·`ご`는 단어의 일부로 봄. 가나가 **바뀐** 것(`乗り換えろ`~`乗り換える`)은 변형이 아님 | `spellingVariant` | 없음 |
| 6 | `〜する`, `〜な`, `〜`, 괄호 | `〜`·`～`·`~`를 지움. 표제어가 `する`/`な`로 끝나고(괄호 안이어도 됨) 읽기도 그 어미로 끝나거나 비었거나 표제어 쪽 어미가 괄호(선택)이면 양쪽에서 뗌. 그다음 남은 `(…)`·`（…）`를 지우고 1–5를 다시 봄 (`勉強する`→`勉強`, `静か(な)【しずかな】`→`静か【しずか】`) | `affixStripped` | 없음 |
| 7 | 합성어 | 둘 다 한자를 포함한 사전 단어 두 개로 나뉘고, 읽기(히라가나로 맞춤)도 앞뒤로 나뉨. 뒤 단어의 첫 가나가 탁음이면 청음 읽기도 허용(연탁: `本棚【ほんだな】`). 가나 조각은 허용하지 않음(`タ日`이 `タ`+`日`로 통과하지 않게). **약한 확인**: 헷갈리는 글자로 바뀐 표기도 합성어로 통과할 수 있음(`二短調`) | `compound` | 없음 |
| 8 | 그 밖 | | `none` | 확인 필요 |

- 읽기가 여러 개(`あした/あす`)면 읽기마다 확인하고 하나라도 `none`이면 줄을 표시합니다.
- 교재 59줄에서는 1·2만 쓰였습니다(60/60 `exact`).
- 상용어판에서는 교재의 두 줄이 7로 통과했습니다.

## 7. core `Dictionary` 포트에 맞춘 어댑터 (적용됐다가 2026-11-06 걷어냄)

처음에는 제안으로 쓴 절이고, 적용됐다가 가로줄 틀 경로와 함께 걷어냈습니다(머리말). 기록으로 남깁니다. 아래 스케치는 그때 모습 그대로 두고, 실제 위치와 달라진 점만 적습니다.

| 절 | 실제 위치 | 스케치와 다른 점 |
|---|---|---|
| 7.1 어댑터 | `packages/jmdict_block/lib/src/jmdict_dictionary_adapter.dart` (`JmdictDictionaryAdapter`, `wordClassesFor`) | `app/`이 아니라 순수 Dart 패키지에 둠(Flutter 없이 `dart test`와 사전을 켠 점수 측정 `tool/eval_capture_dict.dart`). `fixHeadword`는 빈 표제어에 `[]` |
| 7.2 포트 확장 | `packages/core/lib/src/ports/dictionary.dart` | 스케치 그대로 |
| 7.3 보정기 | `packages/core/lib/src/capture/correctors/dictionary_pair_corrector.dart`, 순서는 `standardCorrectors()` | 되돌리거나 고칠 때 규칙이 남긴 표제어 "자동 보정" 표시를 지우고 사전 표시 하나만 남김 |
| 7.3 규칙 좁히기 | `confusable_glyph_corrector.dart` | 한 글자 가타카나만 바꿈. 헷갈리는 글자로만 된 2글자 이상 덩어리는 바꾸지 않고 "의심" 표시 |
| 7.4 Flutter 탑재 | `app/lib/adapters/bundled_dictionary.dart`, `app/lib/app/blocks.dart`(`bundledDictionaryProvider`, `dictionaryProvider`), `app/lib/app/startup.dart` | 판 표시는 `jmdict-full-lean.edition.json`(원본 sha256, JMdict 날짜, 만든 날). 앱 지원 폴더가 아니라 **캐시 폴더**에 풂(다시 만들 수 있는 파일이라 iOS 백업 제외). 풀기는 `Isolate.run`, 실패하면 `EmptyDictionary`. asset 생성: `tools/dict/build_app_asset.py` |

### 7.1 지금 포트 그대로 끼우기 (앱 쪽 파일)

`dict_jmdict`는 core를 모르고 core도 `dict_jmdict`를 모르므로, 둘 다 의존하는 `app/`에 어댑터를 둡니다.

```dart
// app/lib/adapters/jmdict_dictionary.dart
import 'package:dict_jmdict/dict_jmdict.dart' as jm;
import 'package:shiori_core/shiori_core.dart';

final class JmdictDictionaryAdapter implements Dictionary {
  JmdictDictionaryAdapter(this._jm);

  final jm.JmdictDictionary _jm;

  /// core calls this when the headword was not read. A printed reading means
  /// the headword is not just that kana, so suggestHeadword('', reading) is
  /// used: it leaves the bare reading out (measured in docs/dictionary.md 5.1).
  @override
  Future<List<DictionaryEntry>> byReading(String reading, {int limit = 5}) async => [
    for (final s in _jm.suggestHeadword('', reading, limit: limit))
      DictionaryEntry(
        headword: s.headword,
        readings: [s.candidate.reading],
        glosses: s.candidate.glosses,
      ),
  ];

  @override
  Future<List<DictionaryEntry>> byHeadword(String headword, {int limit = 5}) async => [
    for (final w in _jm.lookupByHeadword(headword, limit: limit))
      DictionaryEntry(headword: w.headword, readings: w.readings, glosses: w.glosses),
  ];
}
```

끼우는 한 줄(`blocks.dart`의 `dictionaryProvider`). DB 열기는 asset 복사 때문에 비동기이므로 `main`에서 연 뒤 넘깁니다.

```dart
ProviderScope(
  overrides: [dictionaryProvider.overrideWithValue(JmdictDictionaryAdapter(await openBundledJmdict()))],
  child: const ShioriApp(),
)
```

이것만으로 `DictionaryCandidateCorrector`가 표제어를 못 읽은 줄에 후보를 채웁니다(5.1 (a)).

### 7.2 포트 확장 제안: 짝 확인과 글자 고치기

지금 포트에는 짝 확인과 고치기 제안이 없어서 (b)·(c)의 효과를 쓸 수 없습니다. 제안입니다.

```dart
// packages/core/lib/src/ports/dictionary.dart (제안)
enum PairStatus { known, compoundOnly, notFound, unavailable }

abstract interface class Dictionary {
  Future<List<DictionaryEntry>> byReading(String reading, {int limit = 5, PartOfSpeech? pos});
  Future<List<DictionaryEntry>> byHeadword(String headword, {int limit = 5});

  /// Whether the dictionary has [headword] with every reading in [readings]
  /// (empty: a kana word). compoundOnly: found only as two words in a row,
  /// a weak match. EmptyDictionary answers unavailable.
  Future<PairStatus> checkPair(String headword, List<String> readings);

  /// Dictionary headwords [ocrHeadword] could be through look-alike glyphs,
  /// best first; empty when none. EmptyDictionary answers [].
  Future<List<String>> fixHeadword(String ocrHeadword, String reading,
      {PartOfSpeech? pos, int limit = 3});
}
```

어댑터 쪽 구현:

```dart
  @override
  Future<PairStatus> checkPair(String headword, List<String> readings) async {
    final checks = readings.isEmpty
        ? [_jm.checkPair(headword, null)]
        : [for (final r in readings) _jm.checkPair(headword, r)];
    if (checks.any((c) => !c.isKnown)) return PairStatus.notFound;
    return checks.any((c) => c.match == jm.PairMatch.compound)
        ? PairStatus.compoundOnly
        : PairStatus.known;
  }

  @override
  Future<List<String>> fixHeadword(String ocr, String reading,
          {PartOfSpeech? pos, int limit = 3}) async =>
      [for (final s in _jm.suggestHeadword(ocr, reading, limit: limit, prefer: _classes(pos))) s.headword];

Set<jm.WordClass> _classes(PartOfSpeech? pos) => switch (pos) {
  null => const {},
  PartOfSpeech.noun => {jm.WordClass.noun},
  PartOfSpeech.verb => {jm.WordClass.verb},
  PartOfSpeech.adjective => {jm.WordClass.iAdjective, jm.WordClass.naAdjective},
  PartOfSpeech.iAdjective => {jm.WordClass.iAdjective},
  PartOfSpeech.naAdjective => {jm.WordClass.naAdjective},
  PartOfSpeech.adverb => {jm.WordClass.adverb},
  PartOfSpeech.conjunction => {jm.WordClass.conjunction},
  PartOfSpeech.interjection => {jm.WordClass.interjection},
  PartOfSpeech.prenominal => {jm.WordClass.adnominal},
  PartOfSpeech.particle => {jm.WordClass.particle},
};
```

### 7.3 보정기 체인 제안: `DictionaryPairCorrector`

규칙 보정기 뒤, 누락 표시 앞에 둡니다. 규칙이 잘못 바꾼 경우(`タ行`→`夕行`)를 되돌리려면
OCR 원문 표제어가 필요합니다. 그래서 `CapturedEntry`에 `ocrHeadword`(템플릿이 채움)를 두는 것을 함께 제안합니다.
"사전에 없음"은 지금의 `missing`·`corrected`와 다른 상태라 새 `IssueKind`도 필요합니다.

```dart
// standardCorrectors: ConfusableGlyph → KanaOkurigana → DictionaryCandidate
//                     → DictionaryPair (new) → MissingFieldFlagger
final class DictionaryPairCorrector implements EntryCorrector {
  const DictionaryPairCorrector(this.dictionary);

  final Dictionary dictionary;

  @override
  String get id => 'dictionary-pair';

  @override
  Future<CapturedEntry> correct(CapturedEntry e) async {
    if (e.headword.isEmpty) return e; // DictionaryCandidateCorrector offers candidates
    final status = await dictionary.checkPair(e.headword, e.readings);
    if (status == PairStatus.known || status == PairStatus.unavailable) {
      return e; // confirmed (a rule correction too), or no dictionary
    }
    final ocr = e.ocrHeadword ?? e.headword;
    // 1. a rule broke a real word (タ行 → 夕行, ニ短調 → 二短調 found only as
    //    a compound): go back to what OCR read when the dictionary has it
    if (ocr != e.headword &&
        await dictionary.checkPair(ocr, e.readings) == PairStatus.known) {
      return e.copyWith(headword: ocr, issues: [
        ...e.issues.where((i) => i.field != EntryField.headword),
        EntryIssue.corrected(EntryField.headword, note: '${e.headword} → $ocr (사전)'),
      ]);
    }
    if (status == PairStatus.compoundOnly) return e; // weak, but nothing better
    // 2. look-alike glyphs explain the text (ー日 → 一日)
    final reading = e.readings.isEmpty ? '' : e.readings.first;
    final fixes = await dictionary.fixHeadword(ocr, reading, pos: e.pos);
    if (fixes.isNotEmpty) {
      return e.copyWith(headword: fixes.first, headwordCandidates: fixes, issues: [
        ...e.issues,
        EntryIssue.corrected(EntryField.headword, note: '$ocr → ${fixes.first} (사전)'),
      ]);
    }
    // 3. not in the dictionary: the learner checks it
    return e.copyWith(issues: [...e.issues, const EntryIssue.unverified(EntryField.headword)]);
  }
}
```

**사전 없이 쓸 때의 규칙 대안**: 규칙을 "앞뒤에 가타카나가 없는(길이 1인) 가타카나만 한자로"로 좁힙니다.

- 망가지는 실제 단어: 5,536개 → 73개(`カ月`, `カ所`, `タ行`, `ハ長調` 등은 남음)
- `タ日`→`夕日`처럼 한자 옆에 홀로 있는 가타카나를 고치는 보정은 그대로 됩니다.
- 교재 59줄에서는 이 규칙이 한 번도 쓰이지 않아 점수에는 영향이 없습니다.

### 7.4 Flutter 탑재 (처음 제안. 적용 내용은 7절 표)

- **SQLite 바이너리**: `sqlite3` 3.x는 빌드 훅으로 SQLite를 앱에 넣으므로 `sqlite3_flutter_libs`가 필요 없습니다(그 패키지는 0.6.0+eol).
  - 첫 빌드 때 훅이 GitHub 릴리스에서 sha256으로 확인된 바이너리를 받습니다.
  - 오프라인 CI는 `hooks: user_defines: sqlite3: source: system`을 씁니다.
- **DB 파일**: Android asset은 APK 안에 압축돼 있어 SQLite가 바로 열 수 없습니다. 첫 실행 때 앱 지원 폴더로 복사합니다.

```dart
Future<jm.JmdictDictionary> openBundledJmdict() async {
  final dir = await getApplicationSupportDirectory();                  // path_provider
  final file = File('${dir.path}/jmdict-full-lean.sqlite');
  final marker = File('${file.path}.version');
  final bundled = await rootBundle.loadString('assets/dict/VERSION');  // source sha256 at build time
  if (!file.existsSync() || !marker.existsSync() || marker.readAsStringSync() != bundled) {
    final gz = await rootBundle.load('assets/dict/jmdict-full-lean.sqlite.gz');
    await file.writeAsBytes(gzip.decode(gz.buffer.asUint8List()), flush: true);
    await marker.writeAsString(bundled);
  }
  return jm.JmdictDictionary.open(file.path);
}
```

- **호출 위치**: 호출은 동기식이고 빠르지만(5절), 캡처 파이프라인을 `Isolate.run`에서 돌릴 때 함께 넣는 것을 권합니다.

## 8. 라이선스 표기 의무 (EDRDG 라이선스 원문 확인, 2026-11-05)

1. **표기 화면**: 앱 안의 **별도 화면**("정보", "출처" 등 메뉴에서 여는 화면)에 사용 사실과 출처를 밝힙니다. 시작 화면에만 두면 안 됩니다.
2. **링크**: 문서·라이선스 파일 또는 그 링크를 제공합니다. 앱은 링크로 충분합니다.
   - JMdict 프로젝트: https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project
   - 라이선스: https://www.edrdg.org/edrdg/licence.html
3. **문구**: 패키지가 DB의 `meta`에서 읽어 `info.attribution`, `info.projectUrl`, `info.licenseUrl`로 줍니다.
   > This application uses the JMdict dictionary files. These files are the property of the Electronic Dictionary
   > Research and Development Group, and are used in conformance with the Group's licence.
4. **같은 조건**: 변환한 DB 파일은 CC BY-SA 4.0으로 배포하고, 그 데이터에 저작권을 주장하지 않습니다.
   앱 코드는 공개하지 않아도 되고 상업적 사용도 됩니다.
5. **정기 갱신(4절)**: 최신판으로 데이터를 정기적으로 갱신하는 절차가 있어야 합니다. 예로 웹 사전은 최소 월 1회입니다. 지키지 않으면 위반입니다.
6. **앱의 표기 위치**: 홈 오른쪽 위 정보 버튼 → **정보 화면**(`app/lib/features/about/about_screen.dart`).
   DB의 `info.attribution`, JMdict 프로젝트·라이선스 링크(글자로 보이고 복사 버튼, 외부 브라우저 패키지는 넣지 않음),
   DB 판(JMdict 날짜, 만든 날, 원본 sha256)을 보여 줍니다. 사전이 없으면 그 사실을 보여 줍니다.
   Flutter 라이선스 페이지(`showLicensePage`)에도 JMdict 항목을 등록합니다(`registerDictionaryLicense`).
7. **모의 측정 데이터**: 이 절의 측정에 쓴 JLPT 목록(Waller CC BY, stephenmk CC BY-SA)은 측정용이었습니다. 2026-11-13부터는 같은 목록이 기본 단어장으로 앱에 들어가고, 출처 표기는 15.5절에 있습니다.

## 9. 남은 문제

1. **데이터 갱신 방식 결정(라이선스 의무)** — 도구는 생김(12절), 정기 운영 방식은 결정 남음
   - 지금: 다시 빌드하는 명령 한 줄 `python3 tools/dict/build_app_asset.py`, 판은 정보 화면과 `app/assets/dict/jmdict-full-lean.edition.json`에 보임
   - **결정(2026-11-05): 나중에 자동화로 처리한다.** 예: CI가 최신 JMdict로 DB를 다시 빌드한다. 구체적인 방식은 사전을 앱에 붙이는 단계에서 정한다.
   - 서버가 없으면: 앱을 출시할 때마다 최신 JMdict로 다시 빌드하는 절차(CI 작업)
   - 또는 앱 안에서 정적 호스팅(GitHub 릴리스 등)의 DB를 받는 방식
   - 둘 중 무엇을 쓸지는 그 단계에서 정합니다.
2. **앱 크기**(해결: gzip asset으로 실음, debug APK +12.2 MB, `docs/verification.md` 8.3): 설치 후 30.5 MB(gzip 12.2 MB)입니다. gzip asset을 풀어 쓰면 디스크 약 42 MB를 씁니다. 첫 실행 때 내려받으면 30.5 MB지만 네트워크가 필요합니다.
3. **core 쪽 합의** — 해결(7절 표대로 적용)
   - 포트 확장(`checkPair`, `fixHeadword`, 품사 힌트)
   - `CapturedEntry.ocrHeadword`
   - 새 `IssueKind`(사전에 없음)
   - `DictionaryPairCorrector`
   - 규칙 보정기를 좁히는 일(7.3)
   - 모두 core 쪽에서 정할 일입니다.
4. **교재 표본이 작음**: 사전이 쓰이는 줄이 59줄 중 5줄(빠진 표제어 2, 규칙 보정 3)뿐입니다. 사진이 더 모이면 같은 스크립트로 다시 잽니다(`--data`, `--truth`).
5. **동음이의어**: 문맥 없이 1순위는 82–84%입니다. 후보 3개 이상을 보여 주고 학습자가 고르게 합니다.
   검토 화면은 후보 5개를 칩으로 보여 줍니다. 예: 합성 세트의 `日`(ひ)은 `火` 다음 2위입니다.
6. **다루지 않는 경우**
   - 읽기 자체가 틀린 경우(측정에서 59/59 맞음)
   - 읽기에 가타카나가 섞인 사전 항목(`ハ長調【ハちょうちょう】`을 히라가나 읽기로 찾지 못함)
   - 세 단어 이상 합성어와 촉음화(`学`+`校`=`がっこう`)
   - OCR이 글자를 빼거나 더한 경우(글자 수가 같은 바꿈만 다룸)
7. **합성어 확인은 약한 확인**: 헷갈리는 글자로 바뀐 표기도 두 단어로 나뉘면 통과합니다(`二短調`). 보정기에서 OCR 원문을 우선하는 순서로 보완했습니다(7.3, 적용됨).
8. **영어 뜻 나누기**: 뜻은 `; `로 이어 저장해서, 뜻 문장 안에 `; `가 있으면 잘못 나뉩니다(드묾). 권고 판에는 뜻이 없습니다.

## 10. 다시 돌리는 방법

```bash
# 데이터 (원본이 없으면 EDRDG에서 https로 받음, 약 25초). 이 보고서의 판으로 고정하려면 sha256을 줌
python3 tools/dict/build_jmdict_db.py --matrix \
    --expect-sha256 7f6dc7a4a50411e5a99c35969f28740e174714f04708ea84d50d6bdc09a001ed
# 앱 asset (app/assets/dict/, git 제외)
python3 tools/dict/build_app_asset.py --expect-sha256 7f6dc7a4a50411e5a99c35969f28740e174714f04708ea84d50d6bdc09a001ed
# 배포 전 검사: asset과 판 정보 JSON이 맞는지 (두 사전 모두, 12.2절)
python3 tools/dict/asset_check.py
# release 빌드가 돌리는 검사: 위 검사 + JMdict 35일 기한, 실패하면 고치는 명령을 알려 줌 (12.2·12.4절)
python3 tools/dict/asset_check.py --release
# 최신판으로 갱신 (조건부 요청 → 빌드 → 정확도 관문 → 채택, 12.1절)
python3 tools/dict/refresh.py --dry-run
# 테스트 DB
python3 tools/dict/build_jmdict_db.py --only tools/dict/test_forms.txt --glosses first \
    --sql packages/dict_jmdict/test/fixtures/mini_jmdict.sql
# 패키지
(cd packages/dict_jmdict && dart pub get && dart analyze && dart test)
# 효과 측정: 단어 추출기 점수표 (실제 JMdict·한국어 뜻 사전, docs/extraction.md 7절)
(cd packages/jmdict_block && dart run tool/eval_extract_dict.dart --db <JMdict SQLite> --glossary <한국어 뜻 사전 SQLite> \
    --fixtures ../core/test/fixtures/synthetic)
```
(4·5절의 측정 도구 `tools/dict/eval_dict.py`는 2026-11-06에 걷어냈습니다.)

| 경로 | 내용 |
|---|---|
| `tools/dict/build_jmdict_db.py` | JMdict XML → SQLite(판본 선택, 크기표, 테스트용 SQL 덤프) |
| `tools/dict/build_app_asset.py` | 앱 asset(full-lean gzip + 판 표시 파일), `--check`. 테스트 `tools/dict/test_build_app_asset.py` |
| `tools/dict/asset_check.py` | 배포 전 검사(크기·sha256·판 정보 필드·DB 안 meta), release 빌드 검사 `--release`. 테스트 `tools/dict/test_asset_check.py` |
| `tools/dict/refresh.py` | 정기 갱신(12절). 테스트 `tools/dict/test_refresh.py` |
| `tools/dict/test_forms.txt` | 테스트 DB에 넣을 JMdict 표기 목록 |
| `packages/dict_jmdict/lib/` | 패키지(`jmdict_dictionary.dart`, `form_lookup.dart`, `priority.dart`, `models.dart`) |
| `packages/dict_jmdict/test/` | 단위 테스트와 테스트 DB |
| `packages/jmdict_block/` | core `Lexicon` 포트 어댑터, 실제 사전 점수표 `tool/eval_extract_dict.dart` |

## 11. 한국어 뜻 사전 (한국어기초사전 일본어 대역어 역색인, 2026-11-05)

JMdict는 영어 뜻뿐이라, 사진에 한국어 뜻이 없거나 읽지 못했을 때 채울 데이터가 없습니다.
한국어 뜻의 출처 순서는 ① 사진 속 한국어 → ② **한국어기초사전 역색인(이 절)** → ③ 위키낱말사전 보조 사전(13절, ②가 뜻을 하나도 못 줄 때만) → ④ 기기 번역(넣지 않음, 13.7절)입니다. ②가 엉뚱한 첫 뜻을 주는 낱말은 뜻 보정(16절)이 ②의 첫 뜻 앞에 이 앱이 쓴 뜻을 둡니다.
지금은 ②만 넣었고, 가로줄 틀 흐름에서 **뜻 칸이 비었을 때만** 씁니다.

### 11.1 출처와 판

| 항목 | 값 |
|---|---|
| 원본 | 국립국어원 한국어기초사전 전체 내려받기, JSON (zip 안에 JSON 11개) |
| 받는 곳 | https://krdict.korean.go.kr/download/downloadPopup 에서 JSON 내려받기의 `seq`를 읽고 `https://krdict.korean.go.kr/dicBatchDownload?seq=<seq>` (로그인 없음, `seq`는 판마다 바뀜). 스크립트는 내려받지 않습니다 |
| 판 (파일 머리말 `creationDate`) | 2026-10-19 |
| 크기, sha256 | 84,498,237 bytes, `c8f9ffbf7e9be1f1ec86fa29e4160a75eee8044fc081c27788dadf3ceb66d34e` |
| 규모 | 표제어 56,555, 일본어 대역어가 있는 뜻 75,144. 그중 단어(`lexicalUnit` 단어) 뜻 67,030개를 색인, 색인 키 104,102개 |
| 라이선스 | CC BY-SA 2.0 KR (https://creativecommons.org/licenses/by-sa/2.0/kr/). 출처 표시·동일조건. 변환한 DB도 같은 조건으로 배포 |
| 앱 표기 | 「한국어기초사전, 국립국어원, CC BY-SA 2.0 KR, 2026-10-19판을 가공함」 (판 날짜는 판 정보 JSON에서 읽음) |

오픈 API(하루 5만 건)는 일본어로 거꾸로 찾을 수 없고 서버 없는 앱에도 맞지 않아 쓰지 않습니다.

### 11.2 색인 규칙 (`tools/dict/build_ko_glossary.py`)

- 대역어 `しょくどう【食堂】。レストラン` → (食堂, しょくどう) 짝은 0번 자리, 가나 낱말 レストラン은 1번 자리.
  `【】` 안·밖의 `・`는 대안(`ただ【只・唯】`, `そん・むら【村】`), `【】` 안이 가나면 가나 낱말 둘(`たばこ【タバコ】`),
  읽기 없는 한자 표기(`着手する`)는 표기만으로 색인합니다. 닫는 괄호가 `」`인 오기(`いちばん【一番」`)도 짝으로 읽습니다.
- 한자 표제어는 **읽기와 한자 표기를 함께** 맞춥니다. 食堂/しょくどう에 식도(食道)가 걸리지 않습니다. 읽기를 모르면 표기만으로 찾습니다.
- 키 정규화(앱 블록과 같은 규칙, 시험 표 `tools/dict/testdata/ko_glossary_keys.json`을 Python·Dart 테스트가 같이 읽음):
  공백·탭·`〜`·`…` 제거 → 끝말 `する`·`だ`·`な` 떼기(`だ`·`な`는 한자 뒤에서만, `する`는 한자 뒤나 가나 두 글자 이상 뒤) →
  다른 괄호 부분 제거 → 가타카나를 히라가나로. `有名だ`↔`有名`, `勉強する`↔`勉強`, `ただ`·`まだ`는 그대로.
- 뗀 끝말은 따로 남깁니다(`ja.ending`). 표제어와 끝말이 같은 대역어를 앞에 둡니다(有名だ → 유명하다가 유명보다 앞).
- `(対訳語無し)`만 있는 뜻(2,421개)과 단어가 아닌 항목(관용구·구·문법 표현·속담)은 뺍니다.
- 순위: ① 맞은 방식(한자 표제어+읽기 일치 / 가나 표제어의 가나 대역어가 먼저, 표기만 일치 / 가나 표제어가 한자 대역어의 읽기로만 일치는 뒤)
  → ② 대역어 안 자리 → ③ 끝말 일치 → ④ 기초사전 등급(초급 > 중급 > 고급 > 없음) → ⑤ 뜻 번호 → 파일 순서.
- **뜻 묶음** = 한 뜻(sense)의 한국어 표제어 + 그 뜻의 유의어(`SenseRelation` 유의어) 가운데 **같은 일본어로도 걸리는** 낱말.
  앞 묶음에 이미 나온 낱말의 뜻은 건너뜁니다(한 낱말의 여러 뜻이 같은 대역어를 가질 때 한 번만). 예: ただ → 「다만, 단지, 오직」/「단」/「그저」 …
- 사전에 없는 한자 표제어가 `お`·`ご`·`御`로 시작하면 그것을 떼고 한 번 더 찾습니다(お皿 → 皿). 사전에 `お`째 있으면 그대로 씁니다.
- **한국어 품사**(스키마 2, 2026-11-06): 뜻마다 그 표제어의 `partOfSpeech`를 `sense.pos` 정수로 둡니다(0 없음·품사 없음, 1 명사 … 14 어미, 표 `tools/dict/testdata/ko_pos_codes.json`을 Python·Dart 테스트가 같이 읽음).
  조회에 품사 힌트를 주면 그 갈래의 뜻을 ① 다음에 앞으로 옮깁니다(걸러 내지 않음, 11.4절). 같은 원본·같은 판이며 색인 키·뜻은 스키마 1과 같습니다.

### 11.3 판본 크기

| 판본 | SQLite | gzip | 내용 |
|---|---|---|---|
| **lean (기본, 앱 asset, 스키마 2)** | **9.5 MB** (9,478,144) | **3.7 MB** (3,664,720) | 한국어 낱말·등급·뜻 번호·유의어·품사 + 일본어 키 |
| (스키마 1, 2026-11-05 빌드) | 9.4 MB (9,379,840) | 3.6 MB (3,635,596) | 품사 없음 |
| full | 13.6 MB (13,578,240) | 5.0 MB (5,023,830) | lean + 한국어 뜻풀이 |
| (조사 때 시험 DB) | 19.3 MB | 6.9 MB | 뜻풀이와 대역어 원문 포함 |

뜻풀이는 지금 쓰는 곳이 없어 lean을 기본으로 했습니다(뜻 묶음 후보를 고를 때 뜻풀이를 보여 줄 필요가 생기면 full로 바꿉니다).
iOS prod release `Runner.app`은 36.1 MB입니다(11절 기록 때 JMdict만 넣고 32.4 MB, docs/verification.md 14절).

### 11.4 포트와 블록

- core 포트 `KoreanGlossary` (`packages/core/lib/src/ports/korean_glossary.dart`): `lookup(headword, readings:, limit:)` → `KoreanSense` 목록
  (낱말 목록, 출처 `GlossarySource.krdict`/`wiktionary`, 등급, 뜻 번호, `text` = `다만, 단지`), `sources` → `GlossarySourceInfo`(발행처·라이선스·판, `attribution`).
  데이터가 없으면 `EmptyKoreanGlossary`. 기존 `Dictionary` 포트는 그대로입니다.
- 포트의 품사 힌트(2026-11-06): `lookup(..., pos: PartOfSpeech?)` — 책이 낱말을 찍은 품사(사진 배지, 없으면 JMdict 품사). 블록은 그 갈래의 한국어 낱말 뜻을 「맞은 방식」 다음 열쇠로 앞에 둡니다.
  갈래: 명사(명사·의존 명사·대명사·수사), 용언(일본어 동사·い형·な형 → 한국어 동사·형용사·보조 동사·보조 형용사, 在る → 있다(형용사)처럼 엇갈리는 짝이 흔함), 부사(접속사 포함), 관형사, 감탄사, 조사.
  접사·어미·품사 없음은 내리지 않습니다(する → -하다). 맞는 뜻이 없으면 힌트 없는 순서 그대로이고 빠지는 뜻은 없습니다.
- 블록 `packages/krdict_block`: `KrdictGlossary.open(path)` (읽기 전용, `PRAGMA user_version` 2 또는 1·테이블·`meta` 확인, 아니면 `KrdictFormatException`. 1(품사 없는 옛 asset)이면 품사 힌트를 무시하고 지금까지의 순서),
  `lookupSync`, `close()` 뒤 조회는 `StateError`. sqlite3 제약은 다른 패키지와 같은 `">=3.4.0 <3.6.0"`.
- 보정기 `KoreanMeaningFiller` (core `capture/correctors/korean_meaning_filler.dart`): `DictionaryPairCorrector` 뒤, `MissingFieldFlagger` 앞.
  뜻 칸이 비었을 때만 1순위 묶음으로 채우고 `meaning:inferred`(note `사전 뜻: 한국어기초사전`)를 남깁니다.
  사진에서 읽은 뜻(잘린 뜻 포함)은 바꾸지 않고, 표제어가 비었거나 「사전에 없음」·의심인 항목은 채우지 않습니다.
  `standardCorrectors(dictionary, glossary: …)`에 glossary를 줄 때만 체인에 들어갑니다(주지 않으면 기준 점수를 잰 체인 그대로).

### 11.5 측정 (2026-10-19판, lean, 데스크톱 arm64)

| 측정 | 결과 |
|---|---|
| JLPT 목록(open-anki-jlpt-decks)에서 뜻 1개 이상 | N5 **674/718 (93.9%)**, N4 **596/668 (89.2%)**, N3 **1,981/2,140 (92.6%)** |
| 교재 정밀도 표본 74단어(단어장 5쪽 + 실기기 1쪽의 정답, 로컬 전용) | 뜻이 나옴 69/74 (93.2%). **1순위 묶음에 정답 낱말 47/74 (63.5%)**, **3순위 안 58/74 (78.4%)** |
| 같은 표본, 느슨한 일치(`하다`·`되다` 붙음, 띄어쓰기) | 1순위 48/74 (64.9%), 3순위 안 59/74 (79.7%) |
| 조회 시간 | 한 번 0.02–0.3 ms, 교재 한 쪽(12–15단어) 약 3–5 ms. 캡처 파이프라인 전체(보정기 포함) 쪽당 약 2 ms |

- 조사 때의 느슨한 일치(93%)와 비교: 읽기+한자를 함께 맞추고 단어만 남긴 뒤 N5는 같은 수준, N4는 낮습니다.
  N4 목록에는 `運動`·`うんどうする`처럼 표기에는 없는 `する`가 읽기에만 붙은 항목이 많아, 읽기가 맞지 않아 빠집니다(교재 표기와는 다름).
- **2026-11-06 다시 잰 것**(스키마 2, 추출기가 채우는 뜻과 같은 순서 `meaningSensesOf`: 품사 힌트 + 한자음 일치, docs/extraction.md 4.5절):
  같은 74단어에서 1순위 47 → **54 (73.0%)**, 3순위 안 58 → 61, 5순위 안(칩 범위) 61 → **63 (85.1%)**. 품사 힌트만이면 1순위 48·3순위 안 60·5순위 안 63.
  품사 힌트를 등급 다음에 두면 효과가 없고(47), 등급 열쇠를 빼면 1순위가 45로 줄어 등급은 그대로 둡니다. 측정은 docs/verification.md 24절.
- 정밀도에서 틀린 경우의 갈래(낱말은 로컬 메모): 정답과 뜻은 같지만 다른 낱말(숫자 한자의 고유어·한자어, 「~ 무렵」·「~ 동안」),
  등급이 낮은 쉬운 낱말이 앞서는 경우(부사 뜻이 명사 뜻보다 앞), 다의어(가나 낱말), 한국어에서 구로 옮기는 말(사전에 단어 항목 없음).
- 캡처 점수(보정기 켬): 합성 31 → **32/35**(뜻 33 → 34, 빈 뜻 1개가 맞게 채워짐), 합성 ML Kit형 16/18 그대로(빈 뜻 없음),
  교재 Vision 55 → **56/59**(빈 뜻 1개가 맞게 채워짐), 교재 ML Kit 51/59 그대로(빈 뜻 없음). 여분 0, 조용한 오류 수 그대로.

측정 명령(교재 데이터는 로컬 전용 폴더에서 읽음, `--verbose`는 교재 낱말을 찍으므로 저장소에 넣지 않음):

```bash
gzip -dc app/assets/dict/ko-glossary.sqlite.gz > /tmp/ko.sqlite
cd packages/krdict_block
dart run tool/measure_glossary.dart coverage  --db /tmp/ko.sqlite --jlpt <n5.csv·n4.csv·n3.csv 폴더>
dart run tool/measure_glossary.dart precision --db /tmp/ko.sqlite --gt "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/general/ground_truth.json" --gt <다른 정답 파일>
# (뜻 채움 효과를 틀 파이프라인으로 재던 capture 명령은 2026-11-06에 걷어냄. 효과는 단어 추출기 점수표로 봄)
```

### 11.6 앱

- asset: `app/assets/dict/ko-glossary.sqlite.gz`, `ko-glossary.edition.json` (git 제외, JMdict와 같은 폴더).
  JMdict와 같은 방식으로 첫 실행·새 판일 때 앱 캐시 폴더로 풀어 엽니다(`app/lib/adapters/bundled_glossary.dart`, 풀기 공용 코드 `unpacked_asset.dart`).
  asset이 없거나 열지 못하면 `EmptyKoreanGlossary`로 동작하고 체인에 채우기가 없습니다.
- 캡처는 두 사전이 다 열린 뒤 보정기 체인을 만듭니다(그 전에는 첫 페이지가 사전 없이 해석될 수 있었음. JMdict에도 같이 적용).
- release 빌드: 두 asset이 없으면 Android `preProdReleaseBuild`와 iOS 빌드 단계가 실패합니다.
- 정보 화면에 「한국어 뜻 사전」 카드(출처 문구, 라이선스·사전 링크, 판 날짜·만든 날·판본)와, 라이선스 페이지에 `한국어기초사전` 항목을 더했습니다.
- 판 정보 JSON의 크기·`sqlite_sha256`을 앱이 풀 때 대조합니다(2026-11-06, 12.3절). 처음에는 없던 장치입니다.

### 11.7 다시 만드는 방법

```bash
# 앱 asset (원본 zip은 저장소 밖에 둠). 이 절의 판으로 고정하려면 sha256을 줌
python3 tools/dict/build_ko_glossary.py --source <krdict_json.zip> \
    --expect-sha256 c8f9ffbf7e9be1f1ec86fa29e4160a75eee8044fc081c27788dadf3ceb66d34e
python3 tools/dict/build_ko_glossary.py --source <krdict_json.zip> --sizes   # 두 판본 크기
# 테스트 DB (지어낸 견본 tools/dict/testdata/krdict_sample.json → packages/krdict_block/test/fixtures/mini_krdict.sql)
python3 tools/dict/build_ko_glossary.py --sample-sql
python3 -m unittest discover -s tools/dict -p 'test_*.py'
(cd packages/krdict_block && dart pub get && dart analyze && dart test)
```

### 11.8 남은 문제

1. **다의어·같은 뜻 안의 낱말 순서**: 가나 낱말과 뜻이 여럿인 한자 낱말, 같은 뜻의 낱말 여럿(되돌아가다/돌아오다 같은 꼴)은 문맥 없이는 가리지 못합니다.
   채운 뜻은 「추정」으로 보이고 다음 묶음 최대 4개가 검토 화면의 「뜻 후보」 칩입니다(2026-11-06). 74단어 표본에서 1순위를 놓친 20개 중 9개가 이 갈래이고 그중 7개는 칩 안에 있습니다.
2. ~~등급 순위의 한계~~ → 품사 힌트(11.2·11.4절)와 한자음 일치(docs/extraction.md 4.5절)로 고쳤습니다(2026-11-06, 74단어 1순위 47 → 54). 등급은 그대로입니다.
3. **빠지는 말**: 한국어에서 구로 옮기는 말(사전에 단어 항목이 없음), 숫자·조수사, 오쿠리가나가 다른 표기, 경어·호칭(사전에 다른 낱말로 올라 있음). 74단어 표본에서 1순위를 놓친 20개 중 9개가 이 갈래입니다(칩으로도 못 구함). 기초사전이 아예 비는 5개 중 3개를 위키낱말사전 보조 사전(13절)이 메웁니다.
4. **갱신**: 기초사전은 판이 바뀌면 같은 명령으로 다시 빌드합니다. 갱신 의무 조항은 없지만 JMdict 갱신과 같이 `tools/dict/refresh.py`로 묶었습니다(12절).

## 12. 정기 갱신과 무결성 검사 (2026-11-06)

EDRDG 라이선스 4절은 데이터를 정기적으로 갱신하는 절차를 요구합니다(8절 5). 그 절차를 도구로 만들고,
빌드 때와 앱 실행 때 asset이 판 정보와 맞는지 확인하는 장치를 더했습니다. 검증 숫자는 `docs/verification.md` 23절, release 빌드 검사는 25절입니다.

### 12.1 갱신 도구 `tools/dict/refresh.py`

```bash
python3 tools/dict/refresh.py [--assets app/assets/dict] [--work tools/dict/.cache/refresh] \
    [--krdict-source <한국어기초사전 JSON zip>] [--dry-run]
```

| 단계 | 하는 일 |
|---|---|
| 1. JMdict 확인 | `If-Modified-Since: <판 정보의 source_last_modified>`로 조건부 요청. 304이거나 같은 파일(sha256)이 오면 바뀌지 않음 |
| 2. 한국어기초사전 확인 | 사이트가 스크립트 요청을 막으므로 **사람이 브라우저로 받은 zip**을 `--krdict-source`로 줌. sha256이 판 정보와 같으면 바뀌지 않음. 주지 않으면 「수동: 내려받기 창의 '올린 날짜' 확인」 안내만 |
| 3. 변화 없음 | 「변화 없음」, 어떤 파일도 바꾸지 않음(종료 0) |
| 4. 내려받기 확인 | 받은 크기 = Content-Length, gzip 끝까지 풀림(CRC), `JMdict created` 날짜 있음. 아니면 종료 2, 아무것도 바꾸지 않음 |
| 5. 후보 만들기 | `--work/candidate/`에 바뀐 사전만 다시 빌드(안 바뀐 쪽은 지금 파일 그대로), `asset_check`로 확인 |
| 6. 정확도 관문 | 같은 코드로 지금 asset과 후보를 각각 단어 추출기 점수표(`packages/jmdict_block/tool/eval_extract_dict.dart`)에 돌려 비교: 합성 3세트(항상) + 로컬 기록 세트(비공개 폴더가 있을 때). 찾음·읽기·뜻·문장·높음이 줄거나 여분·중복·높음인데 틀림·여분인데 높음이 늘면 미달. 그다음 새 asset으로 `jmdict_block`의 로컬 하한 테스트(`SHIORI_JMDICT_DB`·`SHIORI_KO_GLOSSARY_DB`) |
| 7. 채택 | 통과하면 `--assets`의 바뀐 사전만 교체(옛 판 정보 먼저 지우고 gzip → 판 정보 마지막). `--dry-run`이면 후보만 남김. 미달이면 채택하지 않고 종료 1 |
| 보고 | `--work/report.md`(사람용), `report.json`. 교재 세트는 숫자만 |

- 종료 코드: 0 = 변화 없음·채택·후보, 1 = 관문 미달, 2 = 내려받기·빌드 실패.
- 판이 매일 바뀌어 작은 차이로 관문에 걸릴 수 있습니다. 그때는 보고서의 세트별 차이를 보고 사람이 정합니다(넣기로 하면 `build_app_asset.py`를 직접 씁니다).
- 걸리는 시간(Apple Silicon 데스크톱, 2026-11-06판 시험): 내려받기·빌드·관문 합쳐 약 43초.
- 앱은 네트워크를 쓰지 않습니다. 내려받기는 이 개발 도구만 합니다.

### 12.2 배포 전 검사

```bash
python3 tools/dict/asset_check.py [--dir app/assets/dict] [--max-age-days N | --release]
python3 tools/dict/build_app_asset.py --check      # JMdict만
python3 tools/dict/build_ko_glossary.py --check    # 한국어 뜻 사전만
```

- 판 정보의 필드(공통 `variant`·`built_on`·`gzip_bytes`·`sqlite_bytes`·`sqlite_sha256`, JMdict `source_sha256`·`jmdict_created`·`license`,
  한국어 `sources[]`·`attribution`), gzip 크기, 끝까지 풀리는지, 푼 크기·sha256, DB 안 `meta`가 판 정보와 같은지(원본 sha256·JMdict 날짜, 기초사전 판·판본).
- 어긋난 것마다 한 줄, 하나라도 있으면 종료 1. `--max-age-days N`(기본 꺼짐)은 `built_on`이 N일보다 오래된 asset을 실패로 봅니다.
- **release 빌드에 묶여 있습니다.** Android `checkReleaseDictionary`(`preProdReleaseBuild`가 의존)와 iOS Runner 셸 단계
  「Release checks (flavor, dictionary)」(`Release*` 구성)가 `python3 tools/dict/asset_check.py --release`를 돌리고, 실패하면 빌드를 멈춥니다.
  debug·profile 빌드는 돌리지 않습니다(개발 흐름과 폰 설치 `--profile`을 막지 않게). 자세한 규칙은 `docs/architecture.md` 5.2절입니다.
- `--release`는 두 사전이 판 정보와 맞는지 보고, **JMdict만** `built_on`이 `RELEASE_MAX_AGE_DAYS`(35일, `asset_check.py` 한 곳)보다 오래되면 실패로 봅니다.
  한국어 뜻 사전은 나이를 보지 않습니다(12.4절). `--max-age-days`와 함께 쓸 수 없습니다.
- 실패하면 어긋난 것마다 한 줄 뒤에 고치는 명령을 찍습니다. 판 정보와 어긋남 → 그 사전의 빌드 명령(`build_app_asset.py` / `build_ko_glossary.py --source <krdict JSON zip>`),
  JMdict가 오래됨 → `python3 tools/dict/refresh.py`. 어긋남에 `refresh.py`를 안내하지 않는 것은 `refresh.py`가 지금 asset이 검사에 실패하면 바로 멈추기 때문입니다.
  ```
  jmdict-full-lean: built_on 2026-09-27 is 40 days old (limit 35)
  ko-glossary: ok
  error: The dictionary assets cannot ship in a release (python3 tools/dict/asset_check.py --release).
    Too old (JMdict, limit 35 days): refresh with: python3 tools/dict/refresh.py
  ```
- python3은 PATH에서 찾습니다. 없으면 「python3 is not on PATH; the release dictionary check (tools/dict/asset_check.py) needs it.」로 빌드를 멈춥니다(건너뛰지 않음).

### 12.3 앱 실행 때 검증

| 때 | 확인 | 어긋나면 |
|---|---|---|
| 처음 실행·새 판(풀 때) | gzip 크기 → 백그라운드 isolate에서 푼 크기 → sha256. 맞을 때만 파일을 씀 | 파일·표시를 남기지 않고 `UnpackedAssetMismatch`(어긋난 항목·기대값·실제값). 다음 실행에서 다시 풂 |
| 평소 실행 | 표시가 같고 파일 크기 = `sqlite_bytes` | 다시 풂(푼 파일은 읽기 전용으로 열어 크기가 바뀌지 않음) |

- Dart의 gzip 풀기는 잘린 스트림에 오류를 내지 않습니다(앞 절반만 있는 파일이 절반 크기로 풀림). 그래서 크기·sha256이 그 경우를 잡습니다.
- 매번 sha256을 하지 않는 이유: 30 MB를 매번 읽고 수백 ms를 쓰는데, 읽기 전용 파일이 크기는 그대로 내용만 바뀌는 일은 드물고 그때는 SQLite 열기·조회 오류로 다시 풉니다.
- 사전이 열리지 않은 원인: `missing`(빌드에 asset 없음, 개발 빌드) / `damaged`(판 정보와 다름·판 정보를 읽지 못함) / `failed`(그 밖: 파일 쓰기 실패 등).
  `damaged`·`failed`면 캡처·검토·정보 화면에 「사전을 열지 못했어요」와 「다시 시도」가 보입니다(문구는 `app/lib/shared/dictionary_notice.dart` 한 곳). 다시 시도는 열리지 않은 사전만 다시 엽니다.
  검토 화면의 단어는 읽을 때 만들어지므로, 사전 없이 읽은 쪽은 다시 시도가 성공해도 그대로입니다. 그때 검토 화면은 「사전을 열었어요. 이 쪽은 사전 없이 읽었으니, 사전으로 읽으려면 페이지를 다시 등록해 주세요」로 바뀝니다.
- sha256은 `package:crypto`(dart-lang, BSD-3-Clause)로 계산합니다.

### 12.4 「정기」를 돌리는 방식 (2026-11-06 결정)

**결정: 안 A.** 매달 로컬에서 `python3 tools/dict/refresh.py`를 직접 돌리고, 달력 알림으로 잊지 않게 합니다. 로컬 예약(B)·원격 CI(C)는 만들지 않습니다.
빠뜨렸을 때의 안전장치로, release 빌드가 오래된 JMdict를 막습니다(12.2절).

| 사전 | release에서 보는 것 | 이유 |
|---|---|---|
| JMdict | 판 정보와 맞는지 + `built_on`이 **35일** 이내 | EDRDG 라이선스가 정기 갱신을 요구합니다(8절 5). 판이 매일 바뀌므로 매달 돌리면 `built_on`이 늘 새로 찍힙니다. 35일 = 한 달 + 며칠의 여유 |
| 한국어 뜻 사전 | 판 정보와 맞는지만 | 기초사전은 판이 드물게 바뀝니다. 원본이 그대로면 `refresh.py`는 「변화 없음」으로 끝나 `built_on`이 바뀌지 않으므로, 나이로 막으면 매달 같은 원본을 다시 빌드해야 하는 수고만 생깁니다 |

- debug·profile 빌드는 나이도 어긋남도 보지 않습니다(어긋난 asset은 앱이 풀 때 거부합니다, 12.3절).
- 기한은 `tools/dict/asset_check.py`의 `RELEASE_MAX_AGE_DAYS` 한 곳에서 바꿉니다. Xcode·Gradle은 `--release`만 부릅니다.

검토했던 안:

| 안 | 방식 | 장점 | 단점 |
|---|---|---|---|
| A | 로컬에서 매달 `refresh.py`를 손으로 돌림 + 달력 | 기반 시설 없음, 로컬 기록 세트로 관문까지 돎 | 잊을 수 있음 |
| B | 로컬 예약(launchd, 월 1회, `--dry-run`)과 알림 | 잊지 않음 | 그 컴퓨터가 켜져 있어야 함, 채택은 사람이 |
| C | 원격 CI 예약 | 사람·기계와 무관 | 로컬 기록 세트로 관문 불가, asset 배포 경로를 새로 정해야 함 |


## 13. 위키낱말사전 보조 사전 (2026-11-07)

기초사전 역색인(11절)이 **뜻을 하나도 주지 못하는** 낱말만, 위키낱말사전에서 한국어 뜻을 가져옵니다. 기초사전이 뜻을 주는 낱말은 결과가 그대로입니다.
조사(원천 비교·라이선스·기기 번역)는 `research/meaning/README.md`, 측정은 `docs/verification.md` 31절에 있습니다.
효과: 74단어 표본 1순위 54 → **56**, 5순위 안 63 → **65**. JLPT N5–N3 중 기초사전이 비는 252낱말에서 131개를 채우고, 눈으로 본 1순위 정확도는 122/131(93%)입니다.

### 13.1 출처와 판

| 원천 | 쓰는 것 | 받는 곳 | 판 (덤프) | 크기, sha256 |
|---|---|---|---|---|
| 한국어 위키낱말사전 | 일본어 항목의 한국어 뜻풀이 | https://kaikki.org/kowiktionary/raw-wiktextract-data.jsonl.gz (wiktextract) | 2026-11-01 | 28,335,452 bytes, `09d515e5f601058d0548c5cc712bf8c20b13ea6d68e5a075476ae43eb24de250` |
| 영어 위키낱말사전 | 영어 뜻마다 번역표에 함께 있는 일본어·한국어 낱말 | https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz (wiktextract) | 2026-10-01 | 3,082,476,978 bytes, `5ff2c072f8099f2d2ce484bd6957bf179f046d2ad37bc36555edf8bb84cb5291` |

- 라이선스: 위키낱말사전 본문은 CC BY-SA 4.0과 GFDL 이중 라이선스이고 **CC BY-SA 4.0**을 고릅니다(위키미디어 이용 약관 7조 "Reusers may comply with either license or both"). wiktextract 코드는 MIT.
  만든 DB는 CC BY-SA 4.0으로 배포합니다. 기초사전 DB(CC BY-SA 2.0 KR)와 **다른 파일**이라 두 라이선스가 한 DB에 섞이지 않습니다.
- 앱 표기: 「위키낱말사전, 한국어 위키낱말사전 기여자, CC BY-SA 4.0, 2026-11-01판을 가공함」, 「위키낱말사전, 영어 위키낱말사전(Wiktionary) 기여자, CC BY-SA 4.0, 2026-10-01판을 가공함」(판 날짜는 판 정보 JSON에서 읽음).
- 영어판 원자료는 약 3 GB라 저장소 밖에 두고, `tools/dict/wikt_en_rows.py`가 읽으면서 필요한 행만 남깁니다(행 파일 첫 줄에 원자료 sha256·크기·덤프 날짜).
  빌드는 `--expect-en-sha256`으로 그 원자료 sha256을, `--expect-kowikt-sha256`으로 한국어판 파일을 확인합니다.

### 13.2 색인 규칙 (`tools/dict/build_wikt_glossary.py`)

- 한국어판 뜻풀이 → 낱말: 괄호 주석·끝 마침표를 떼고 쉼표로 나눕니다. 일본어가 섞인 조각, 설명(공백 3개 이상), 낱말 쓰임 설명(「어간의 하나」·「다음 단어를 만듦」)은 버립니다.
  읽기: 가나 표기 칸(옛 표기 archaic·historical·obsolete 제외)과, 낱말 위 루비를 끼워 만든 전체 읽기(오쿠리가나 낱말 포함).
- 영어판 행 → 그 행의 일본어 낱말마다 한국어 낱말(앞 괄호 주석 제거, 한글이 없거나 한자가 든 괄호 제거, 선택 괄호는 엶, 괄호 안의 `/`·`,`로는 나누지 않음, 일본어 글자가 남은 조각은 버림). 읽기: 가나 `alt`.
- 키는 기초사전과 같은 규칙(11.2절 `keys_and_ending`). **키마다 한 원천**: 한국어판에 그 키가 있으면 한국어판 뜻만, 없을 때만 영어판.
- **기초사전이 답하는 키는 뺍니다**: 기초사전 asset(판 정보와 맞는지 확인)의 키, 그리고 가나 키는 기초사전 한자 짝의 읽기. 판 정보에 그 기초사전 SQLite의 sha256(`krdict_sqlite_sha256`)을 적습니다.
- 스키마는 기초사전과 같은 schema 2 lean이라 같은 블록(`KrdictGlossary`)이 엽니다. 뜻 묶음 하나 = 낱말마다 `sense` 행(낱말들은 `synonyms`), `sense.source` 1(위키낱말사전), `sense_no` = 그 키 안 묶음 순번, 등급·품사 없음.
  순위는 맞은 방식(한자+읽기 / 읽기 없는 한자 / 가나) → 묶음 순번입니다.
- 같은 입력과 같은 빌드 날이면 바이트가 같습니다.

### 13.3 판본 크기

| 파일 | SQLite | gzip | 키 · 뜻 행 |
|---|---|---|---|
| `wikt-glossary.sqlite.gz` | 4.1 MB (4,079,616) | 1.5 MB (1,461,627) | 23,463 (한국어판 2,998 · 영어판 20,465) · 35,755 |

앱 asset 합계에 gzip 1.5 MB가 더해집니다(기초사전 3.7 MB, JMdict 11절 표).

### 13.4 앱과 추출기

- core `FallbackKoreanGlossary(primary, fallback)`: 주 사전 결과가 비지 않으면 그대로, 비면 보조 사전 결과. `sources`는 둘을 이어 붙임.
- `GeneralExtractor(meaningFallback:)`: **사진에 뜻이 없는 사전 낱말을 채울 때만**, 그 낱말의 모든 표기(`(お)X` → `(お)X`·`おX`·`X`)가 기초사전에 없을 때 같은 표기 순서로 보조 사전에 묻습니다
  (기초사전의 `おX`가 보조 사전의 `X`에 가려지지 않게). 짝짓기 근거·신뢰도 정리·못 읽은 표제어 되살리기·사진 뜻의 후보 칩은 기초사전만 씁니다.
  채운 뜻은 지금처럼 신뢰도 중간(높음 아님)이고 검토 화면 근거에 `사전 뜻: 위키낱말사전`(기초사전은 `사전 뜻`)으로 보입니다. 순서 규칙(docs/extraction.md 4.5절)은 보조 사전 뜻에도 같게 씁니다.
- 앱: `assets/dict/wikt-glossary.sqlite.gz`·`wikt-glossary.edition.json`. 기초사전과 함께 풀어 엽니다(`bundled_glossary.dart`, `BundledGlossary.wiktionary`).
  없거나 못 열면 기초사전만으로 돌고 로그 한 줄(`wiktionary not available: …`)을 남깁니다. 정보 화면은 asset이 없는 빌드와 asset을 열지 못한 경우를 나눠 보여 줍니다. `wiktionaryGlossaryProvider` → `generalExtractorProvider`의 `meaningFallback`.
- 정보 화면: 「한국어 뜻 사전」 아래 「위키낱말사전」 카드(출처 두 줄, CC BY-SA 4.0 링크, 한국어판·영어판 링크 글, 만든 날). 라이선스 페이지에 `위키낱말사전` 항목.

### 13.5 release 검사

- `tools/dict/asset_check.py --release`는 보조 사전도 봅니다: 없음·깨짐·판 정보 어긋남, 그리고 **곁의 기초사전 asset과 `krdict_sqlite_sha256`이 다르면** 실패하고 만드는 명령을 알려 줍니다. 나이 제한은 없습니다(고정 판).
- 일반 실행(`asset_check.py`)은 보조 사전이 있으면 같이 보고, 없으면 「not built」 한 줄만 찍고 실패하지 않습니다(debug 빌드는 없이 돎).
- 기초사전을 다시 빌드하면(`refresh.py`) 보조 사전도 다시 만들어야 합니다. release 검사가 이를 잡습니다. `refresh.py`는 보조 사전을 만들지 않습니다.

### 13.6 다시 만드는 방법

```bash
# 영어판 행 (원자료는 저장소 밖, 받으면서 걸러도 됨)
curl -s https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz \
    | python3 tools/dict/wikt_en_rows.py --dump 2026-10-01 --out <en-rows.jsonl> --expect-sha256 5ff2c072f8099f2d2ce484bd6957bf179f046d2ad37bc36555edf8bb84cb5291
# 보조 사전 asset (기초사전 asset이 --krdict-dir에 있어야 함, 기본 app/assets/dict)
python3 tools/dict/build_wikt_glossary.py --kowikt <kowiktionary raw-wiktextract-data.jsonl.gz> --kowikt-dump 2026-11-01 \
    --expect-kowikt-sha256 09d515e5f601058d0548c5cc712bf8c20b13ea6d68e5a075476ae43eb24de250 \
    --en-rows <en-rows.jsonl> --expect-en-sha256 5ff2c072f8099f2d2ce484bd6957bf179f046d2ad37bc36555edf8bb84cb5291 --built-on 2026-11-07
python3 tools/dict/build_wikt_glossary.py --check
# 테스트 DB (지어낸 견본 tools/dict/testdata/wikt_sample_*.jsonl → packages/krdict_block/test/fixtures/mini_wikt.sql)
python3 tools/dict/build_wikt_glossary.py --sample-sql
```

### 13.7 넣지 않은 것

- 기기 번역: iOS Translation은 iOS 18 이상(앱 최소 16.2)이고 시뮬레이터에서 돌지 않으며, Android ML Kit 번역은 앱이 모델을 직접 내려받아 「앱이 네트워크를 쓰지 않음」과 어긋납니다(`research/meaning/README.md` 4절).
- 일본어 위키낱말사전 번역표·역색인: 정확도가 더 낮고(80~83%) 더 채우는 양이 적습니다.
- 「칩 보조」(기초사전 뜻 뒤에 보조 사전 뜻을 후보로 덧붙임): 74단어에서 이득이 없어 넣지 않았습니다.

## 14. Tatoeba 예문 (2026-11-12)

사진에 예문이 없던 낱말의 학습 카드에, 그 낱말의 JMdict 항목에 붙은 Tatoeba 문장 하나를 보여 줍니다. 사진 예문이 있으면 언제나 사진 예문이 먼저입니다.
원천 조사(채움·번역·적합도·라이선스)는 `research/examples/README.md`, 측정과 테스트는 `docs/verification.md` 34절에 있습니다.

### 14.1 출처와 판

| 원천 | 쓰는 것 | 받는 곳 | 판 | 라이선스 |
|---|---|---|---|---|
| Tatoeba | 일본어 문장, 원형 낱말 색인(Tanaka 코퍼스 B줄), 그 문장의 한국어·영어 번역 연결, 문장 태그 | https://downloads.tatoeba.org/exports/ (주간 내보내기) | 2026-11-07 내보내기 | CC BY 2.0 FR |

- Tatoeba는 최신판만 내려 줍니다. 그래서 받은 파일 7개의 sha256을 판 정보(`files`)에 적고, `--expect-sha256 이름=값`으로 다른 파일이면 빌드를 멈춥니다.
- 이번 판 sha256:

| 파일 | sha256 |
|---|---|
| `jpn_sentences_detailed.tsv.bz2` | `14e7b047fca3721291bc16c4e9a3b5f967ebdb9b34f704aff9a8b50d0d1d1501` |
| `jpn_indices.tar.bz2` | `fa00e74f515c1564f0bea62f02ac9091e0cef34619edfe4cae26b08da7e181d1` |
| `jpn-kor_links.tsv.bz2` | `52f4da341dcd2d6cb437f01f4c7ad93195392dbf94c26b44a452733dc42c51ec` |
| `kor_sentences_detailed.tsv.bz2` | `9d8373a2edebacafb8b1a4ab484f9059f446e4ad60d90f2efb0041268d3af4d8` |
| `jpn-eng_links.tsv.bz2` | `383e72a90aa9415b7e84844227878171500bf4b570c03f8288624166f52cd6e8` |
| `eng_sentences.tsv.bz2` | `1a2d75ac07aa5d035bff4e2bf053139dfd3b1f1645f6fd3d76fc852cc9ef6020` |
| `jpn_tags.tsv.bz2` | `a3994981faa946d81fdfa1ddc23ad5933cc4416a397d3fae626f61d778869919` |

- 라이선스: CC BY 2.0 FR. 동일조건이 없어 다른 asset·앱 코드와 섞여도 조건이 번지지 않습니다.
  Tatoeba FAQ가 요구하는 표기("write somewhere that some/all of your sentences are from Tatoeba, with a link to https://tatoeba.org, and mention that Tatoeba's data is released under CC-BY 2.0 FR")를 정보 화면과 라이선스 페이지에 둡니다.
- 녹음(Tatoeba 오디오)은 라이선스가 제각각이라 쓰지 않습니다. 소리는 기기 안 VOICEVOX가 만듭니다.

### 14.2 고르는 규칙 (`tools/dict/build_examples.py`)

- 문장을 색인이 가리키는 **JMdict 항목마다** 붙입니다. 색인은 낱말을 원형으로 적으므로(`汚す{汚して}`) 활용형 문장도 항목으로 이어집니다.
  색인이 읽기(`空(から)`)나 항목 번호(`が(#2028930)`)를 주면 그것으로 좁힙니다. 가나 낱말은 가나 항목 → 보통 가나로 쓰는 항목 → 상용 읽기 순으로 고릅니다(core `kanaEntries`와 같은 순서).
  항목은 앱의 JMdict asset(판 정보와 맞는지 확인)에서 읽습니다.
- 읽기가 둘 이상인 항목에서는 문장이 쓰는 읽기를 행에 적습니다(색인의 읽기, 없으면 가나 표기). 모르거나 읽기가 하나면 `''`.
- 카드에 올리는 문장: 6~30자이고 가나가 있고, 한글·라틴 글자·나열 기호·주석 표시가 없음. Tatoeba 부적합 태그(`@needs native check`, 고어, 사투리 등)와 민감 낱말 목록(34개)에 걸리지 않음.
- 항목·읽기마다 1문장, 순서:
  1. 그 문장의 한국어 직접 번역이 있음(영어를 거친 한국어는 쓰지 않음)
  2. 색인의 검증 표시 `~`
  3. 영어 번역이 있음
  4. 빈도 상위 낱말(nf 10 이하)에 없는 한자가 적음 — 조사 때는 JLPT 목록을 앱에 넣지 않던 때라 빈도 상위 낱말로 대신 씀
  5. 문장으로 끝남, 14자에 가까움, 문장 번호가 작음
- 번역: 한국어가 있으면 한국어만, 없을 때만 영어. 둘 다 없을 수 있습니다.
- 같은 입력과 같은 빌드 날이면 바이트가 같습니다(gzip mtime 0).

### 14.3 판본 크기

| 파일 | SQLite | gzip | 행 · 항목 | 번역 |
|---|---|---|---|---|
| `examples.sqlite.gz` | 3.4 MB (3,383,296) | 1.7 MB (1,671,255) | 28,060 · 27,067 | 한국어 1,231 · 영어 26,648 · 없음 181 |

스키마 1(`PRAGMA user_version`): `example(entry, reading, sentence, ja, ko, en, surface)`, 기본 키 `(entry, reading)`, `meta`(판·라이선스·`jmdict_created`).

### 14.4 앱

- 조회: 카드를 띄울 때 `cardExampleOf`(core)가 표제어 → `Lexicon`(JMdict) → 항목 번호(한자 표기는 카드 읽기로 좁힘) → 예문 asset 순서로 찾습니다.
  카드 읽기와 같은 행이 먼저, 다음은 `''` 행입니다. 다른 읽기의 행만 있으면 보여 주지 않습니다. **저장하지 않으므로 저장 스키마는 그대로**입니다.
- 블록: `packages/example_block`의 `TatoebaExamples`(core 포트 `ExampleSentences`). 앱은 `assets/dict/examples.sqlite.gz`·`examples.edition.json`을 다른 사전처럼 캐시 폴더에 풀고 크기·sha256을 대조해 엽니다(`bundled_examples.dart`).
  없거나 못 열면 로그 한 줄을 남기고 사진 예문만 보여 줍니다.
- 카드: 예문 자리에 문장, 아래에 번역(한국어, 또는 기울인 영어 — 뜻을 열 때 보임), 그 아래 작은 글씨 「예문: Tatoeba」(영어면 「예문: Tatoeba · 영어 번역」). 색인의 표기(`汚して`)가 있으면 그 글자를 강조합니다.
- 소리: 사진 예문과 같은 요청(`SentenceSpeech`, 엔진 추정 + 카드 낱말 악센트구 고정, `docs/pronunciation.md` 4절).
- 정보 화면 「예문」 아래 Tatoeba 카드(출처 줄, CC BY 2.0 FR 링크, tatoeba.org, 내보낸 날·만든 날), 라이선스 페이지 `Tatoeba` 항목.

### 14.5 release 검사

- `asset_check.py --release`가 예문 asset도 봅니다: 없음·깨짐·판 정보 어긋남이면 실패하고 만드는 명령을 알려 줍니다. 나이 제한은 없습니다.
- 일반 실행은 있으면 같이 보고, 없으면 「examples: not built」 한 줄만 찍습니다(debug 빌드는 없이 돎).
- JMdict 항목 번호(`ent_seq`)는 판이 바뀌어도 유지되므로 JMdict를 갱신해도 예문 asset을 다시 만들 필요는 없습니다(판 정보에 만들 때의 `jmdict_created`만 적음).

### 14.6 다시 만드는 방법

```bash
# Tatoeba 내보내기 (약 42 MB, 저장소 밖 폴더)
cd <폴더>
for f in per_language/jpn/jpn_sentences_detailed.tsv.bz2 jpn_indices.tar.bz2 per_language/jpn/jpn-kor_links.tsv.bz2 \
         per_language/kor/kor_sentences_detailed.tsv.bz2 per_language/jpn/jpn-eng_links.tsv.bz2 \
         per_language/eng/eng_sentences.tsv.bz2 per_language/jpn/jpn_tags.tsv.bz2; do
  curl -O https://downloads.tatoeba.org/exports/$f; done
# 예문 asset (JMdict asset이 --jmdict-dir에 있어야 함, 기본 app/assets/dict)
python3 tools/dict/build_examples.py --tatoeba-dir <폴더> --tatoeba-export 2026-11-07 \
    --expect-sha256 jpn_indices=fa00e74f515c1564f0bea62f02ac9091e0cef34619edfe4cae26b08da7e181d1
python3 tools/dict/build_examples.py --check
# 테스트 DB (지어낸 문장 tools/dict/testdata/tatoeba_sample/ → packages/example_block/test/fixtures/mini_examples.sql)
python3 tools/dict/build_examples.py --sample-sql
```

### 14.7 넣지 않은 것

- 위키낱말사전 예문(한국어판은 번역이 있지만 채움 24%·적합도 24/30), JMdict 예문판(Tatoeba의 일부), 영어를 거친 한국어 번역(30개 중 3개 틀림), 기기 번역.

## 15. 기본 단어장 (JLPT 대비 N5~N1, 2026-11-13 · 2026-11-14 보충)

교재가 없는 학습자도 바로 시작할 수 있게, 레벨별 단어 목록을 앱에 넣었습니다. 사용자가 「기본 단어장」에서 단어장을 고르면 보통 재생목록 하나와 단어들로 들어갑니다.
카드 내용(뜻·품사·예문·악센트·발음)은 교재에서 찍은 단어와 같은 장치로 채웁니다. 앱은 네트워크를 쓰지 않습니다(목록은 앱 안의 파일).
일본어능력시험(JLPT) 주최 측은 2010년 개편 뒤 어휘 목록을 공개하지 않습니다(jlpt.jp FAQ). 앱과 문서는 이 목록을 「공식」이라고 부르지 않습니다.

### 15.1 출처와 판

| 원천 | 쓰는 것 | 받는 곳 | 판 | 라이선스 |
|---|---|---|---|---|
| Jonathan Waller, JLPT Resources | N5~N1 단어 목록(원본) | https://www.tanos.co.uk/jlpt/ (2026-11 현재 사이트가 내려가 있어 웹 아카이브로 확인) | 레벨 쪽 2019-12 이후 내용 같음 | 「Use my data!」 쪽(https://www.tanos.co.uk/jlpt/sharing/): 팔지 않는 내용은 Creative Commons "BY", 상업·비상업 모두 가능, 출처 표기 |
| Stephen Kraus, yomitan-jlpt-vocab | 같은 목록에 JMdict 항목 번호를 붙이고 드문 표기·어긋난 행을 고친 판 `original_data/n5.csv`~`n1.csv` | https://github.com/stephenmk/yomitan-jlpt-vocab | 커밋 `b062d4e38c4bdd0950ae1d4ec55f04b176182e03` (2025-08-26) | CC BY-SA 4.0 |
| JMdict | 표기·읽기·우선순위·빈도대·「보통 가나」 표시 | 2.1절 | 앱 asset과 같은 원본(`JMdict_e.gz`, sha256 `5af39046…`, JMdict 2026-11-06) | CC BY-SA 4.0 |

| 목록 파일 | sha256 |
|---|---|
| `n5.csv` | `07dc6f197b51cc076c65c3c9f23218d10c2b67f76545f5c1c4d9e3750495533a` |
| `n4.csv` | `a14dcc7fdc02259b22331a486c6ff66df74c16472c8aeb5a0ebe7e5fa8ee8eb4` |
| `n3.csv` | `bd4d68c59cfee861351e1bdf9d99818e434392201eabbed4d3657225fe53a3ac` |
| `n2.csv` | `42a4413326e857d701dc9659b2711637ab612304a339fe0d09f4f0f042d3a214` |
| `n1.csv` | `7a58f0584e9ec2b0299ccb9b109f3bd03e08b90d129a714307c0a1cb72f07b32` |

- 앱 파일(`app/assets/decks/jlpt.json`)은 이 목록과 JMdict를 가공한 것이라 **CC BY-SA 4.0**으로 배포합니다(앱 안에만 들어가고, 사전 asset처럼 git에는 넣지 않음). 한국어 뜻·예문은 파일에 넣지 않고(기초사전 CC BY-SA 2.0 KR 등 다른 라이선스 데이터와 한 파일에 섞지 않음), 추가할 때 앱 사전으로 채웁니다.
- 예외는 **보충 뜻**(424개 — N5~N3 48, N2·N1 376 — 저장소 밖 비공개 폴더의 `decks/supplement.tsv`): 앱 사전이 뜻을 하나도 주지 못하는 단어에 이 프로젝트가 직접 쓴 한국어 뜻입니다. 근거는 그 단어의 JMdict 영어 뜻(CC BY-SA 4.0)과 목록의 영어 뜻(CC BY)뿐이고, 한국어 사전(기초사전·위키낱말)의 문구는 옮기지 않았습니다. 모든 행을 사람이 검수했고(`reviewed` 열), 검수 표시가 없는 행이 있으면 빌드가 멈춥니다. 앱은 사전에 뜻이 없을 때만 씁니다.
- 함께 본 다른 후보와 넣지 않은 이유: 日本語教育語彙表(연구·교육 이용 한정, 재배포 자제), VDRJ(이용 조건 없음), BCCWJ 어휘표(재배포 불가), open-anki-jlpt-decks·jlpt-word-list(MIT지만 출처 사슬에 조건 불명 단계가 있고 다른 자료가 섞임), 옛 출제기준(공개 허락 없음).

### 15.2 만드는 규칙 (`tools/decks/build_decks.py`)

- JMdict 항목 번호가 없는 행(한자 한 글자 행 14개)과 지금 JMdict에 없는 항목은 뺍니다.
- **보이는 표기**: 목록의 가나는 그대로, 목록의 한자가 그 항목의 상용 표기면 그대로, 드문 한자 표기는 항목이 「보통 가나로 씀」이면 읽기로(此の → この), 아니면 같은 한자의 상용 표기로(오쿠리가나만 다를 때: 戸締り → 戸締まり), 그 밖은 그대로. 읽기는 목록이 준 읽기와 같은 항목 읽기.
- **조회 표기**(`l`): 보이는 표기의 한자를 모두 가진 그 항목의 상용 한자 표기가 다르면 적습니다(たいへん → 大変, 話合い → 話し合い). 다른 한자의 표기(軍 → 戦)는 적지 않습니다.
- **한 단어는 한 번, 가장 쉬운 레벨에만**: 앱의 단어 키(`wordKey`)와 JMdict 항목 번호 둘 다로 거릅니다(川·河, こちら·こっち는 한 단어). N5부터, 같은 레벨에서는 목록 순으로 먼저 나온 것이 남습니다.
- **예외 — 한자로 다시 나오는 낱말**: 쉬운 레벨에서 가나로만 나온 항목이 더 높은 레벨에서 한자 표기로 나오면, 그 레벨에 한자 표기로 한 번 넣습니다(いちばん은 N5, 一番은 N1; ねだん은 N4, 値段은 N3). 읽기는 그 행의 읽기입니다(みんな는 N5, 皆 みな는 N3). 표기가 달라 앱의 단어 키도 다르므로 **앱에서는 다른 단어**입니다: 두 단어장을 다 넣으면 いちばん·一番 두 장이 생기고 학습 기록도 따로입니다(높은 레벨이 요구하는 것은 한자 읽기). 교재에서 찍은 一番이 이미 있으면 그 단어와 기록을 이어 씁니다. 같은 레벨 안의 한자 표기, 한자에서 다른 한자(早い·速い), 한자에서 가나, 같은 항목의 두 번째 한자 표기는 지금처럼 뺍니다.
- **보충 뜻표**(`decks/supplement.tsv`): 열 level·entry·headword·meaning·reviewed(그 밖의 열은 무시). 검수 표시가 빈 행, 같은 단어 두 번, 뜻이 빈 행, 단어장에 없는 단어의 행이 있으면 빌드가 멈춥니다.
- **항목 번호 지정표**(`decks/entry-overrides.tsv`, 없어도 됨, 2026-11-14): 원목록이 같은 가나의 다른 JMdict 항목에 이어 놓은 행에 한해, 사람이 정한 항목 번호를 맨 먼저 씁니다(ボタン → 牡丹이 아니라 釦, これ·それ·あれ → 감탄사가 아니라 대명사, こと → 조사가 아니라 事). 열 level·entry·headword·fixed·reviewed, 검사는 보충 뜻표와 같고 고칠 항목이 JMdict에 없거나 행의 가나로 읽히지 않거나 원래 항목과 같으면 멈춤. 판 정보에 행 수와 sha256(`entry_overrides_rows`·`_sha256`). 품사 배지와 뜻 조회의 품사 힌트가 그 항목을 따릅니다.
- **조회 표기 지정표**(`decks/lookup-overrides.tsv`, 없어도 됨): 위 규칙의 조회 표기로 물으면 기초사전이 엉뚱한 첫 뜻을 주는 단어에 한해, 사람이 정한 조회 표기를 씁니다(열 level·entry·headword·lookup·reviewed, 검사는 보충 뜻표와 같고 조회 표기가 보이는 표기와 같아도 멈춤). 지금 4행: 한자로 다시 나온 N1 단어를 같은 항목의 쉬운 레벨 단어가 뜻을 찾은 표기로 묻습니다 — 色々 → いろいろ(색색 → 갖가지), お祖父さん → おじいさん(영감 → 할아버지), その外 → その他(밖 → 기타), 苛々 → いらいら(좌불안석 → 안달복달). 판 정보에 행 수와 sha256을 적습니다.
- **순서**(새 단어를 고르는 순서): 항목의 JMdict 빈도대(nf, 낮을수록 자주 씀) → 상용 항목 → 목록 순. 원목록은 가나 순(あいうえお)이라 그대로 두면 あ로 시작하는 단어부터 배우게 됩니다.
- 파일: JSON 한 줄에 단어 하나(`{"h":표기,"r":읽기,"e":항목,"l":조회 표기,"m":보충 뜻}`), 판 정보 `jlpt.edition.json`(원자료 커밋·sha256, JMdict 판, 보충표 sha256, 레벨별 수, 뺀 수, 파일 크기·sha256). 같은 입력이면 바이트가 같습니다.

### 15.3 크기와 단어 수

| 레벨 | 원 행 | 단어장 | 단어장 이름 |
|---|---|---|---|
| N5 | 684 | 663 | JLPT N5 대비 |
| N4 | 640 | 628 (한자로 다시 나온 낱말 1) | JLPT N4 대비 |
| N3 | 1,730 | 1,650 (33) | JLPT N3 대비 |
| N2 | 1,812 | 1,741 (5) | JLPT N2 대비 |
| N1 | 3,427 | 3,088 (123) | JLPT N1 대비 |
| 합 | 8,293 | **7,770** (162) | |

파일 378 KB(386,782바이트). 사전 asset처럼 **git에 넣지 않고** 빌드 전에 만듭니다(단어 목록 자체를 공개 저장소에 두지 않음). 뺀 행: 항목 번호 없음 14, 중복 509. 한자로 다시 나온 낱말의 표기가 다른 항목 단어와 키가 같아진 2개(N3 未だ ↔ N1 未 ひつじ, N3 等 など ↔ N1 等)는 앱 규칙대로 먼저 나온 쪽만 남습니다.

### 15.4 앱에서

- core: `parseBuiltinDecks`(파일 검사: 형식·판·모르는 키·빈 값·한 단어장 안 중복), `deckDraft`(추가할 때 단어마다 그 JMdict 항목의 품사, 뜻은 추출기가 사전 낱말을 채우는 함수 `meaningSensesOf`로 조회 표기 → 보이는 표기 → 항목의 다른 한자 표기 순, 기초사전 → 위키낱말 → 보충 뜻; 뜻이 없는 단어는 넣지 않고 수를 돌려줌), `LibraryService.addDeck`(이름이 같은 재생목록이 있으면 거기에, 없으면 새로; 규칙은 `addDraft` 그대로).
- 가나로 쓰는 단어는 교재 단어처럼 읽기를 비워 저장합니다. 그래서 카드 예문 조회(`cardExampleOf`)가 읽기가 없으면 표제어를 읽기로 씁니다(발음 `wordSpeechFor`와 같은 규칙, 교재에서 찍은 가나 단어에도 적용).
- 저장 스키마(v5)와 백업 형식(판 1)은 그대로입니다. 단어장과 재생목록의 연결은 저장하지 않고 이름으로 찾습니다.
- 「빠진 단어 채우기」는 앱 안의 파일을 다시 읽어 그 재생목록에 없는 단어만 더합니다(네트워크 없음). 이미 있는 단어의 뜻·학습 기록은 그대로입니다.

### 15.5 출처 표기

- 정보 화면 「기본 단어장」 절: 두 원천(저자·이름·라이선스), 목록과 라이선스 링크, 목록 판, 「일본어능력시험 주최 측이 낸 목록이 아니에요」.
- 라이선스 페이지: `JLPT Resources (Jonathan Waller)`, `yomitan-jlpt-vocab (Stephen Kraus)`.
- 단어장 화면 바닥: 「단어 목록 출처」와 두 원천, 같은 안내 문장.

### 15.6 측정 (실제 asset, 앱과 같은 조회 경로)

| 레벨 | 뜻 | 그중 뜻 없어 빠짐 | 예문 | 악센트 |
|---|---|---|---|---|
| N5 | 100% | 0 | 98.8% | 88.2% |
| N4 | 100% | 0 | 98.7% | 88.2% |
| N3 | 100% | 0 | 98.1% | 94.7% |
| N2 | 99.8% | 3 | 87.8% | 90.8% |
| N1 | 98.5% | 46 | 80.0% | 95.1% |

- 보충 뜻 424개로 N5~N3은 100%, N2·N1은 99.8 · 98.5%입니다(보충 없이 N2 94.5 · N1 89.4%).
- N2·N1에서 뜻을 넣지 않은 49개는 검수에서 뺀 목록 행입니다: 한자 한 글자 접사(問 もん, 傑 けつ), 드문 읽기(昼飯 ちゅうはん, 歪む いがむ), 표기와 읽기가 어긋남(予言 かねごと), 흔한 말과 헷갈리는 드문 말(悪日 あくび). 앱은 뜻이 없는 단어를 넣지 않으므로 보충표에서 빼는 것만으로 빠집니다.
- 보충 뜻 초안 방법의 정확도(이미 사전 뜻이 있는 N2·N1 60개에 같은 방법을 써 본 결과): 첫 뜻이 그 낱말 뜻으로 맞음 60/60, 앱 사전의 첫 뜻은 55/60.
- 뜻 정확도(레벨마다 무작위 30개를 원목록 영어 뜻과 대조, 엄격: 첫 뜻이 그 낱말 뜻인가): N5 28 · N4 28 · N3 27 · N2 27 · N1 29 → **139/150 (93%)**. 틀린 꼴은 기초사전 역색인의 뜻 순서(どの → 아무, 優しい → 부드럽다, くれる → 달다)와 외래어·쓰임이 넓은 낱말(フリー → 프리랜서).
- 영어 대역어로 뜻 순서를 다시 매기는 방법은 고쳐지는 만큼 망가져(いくら → 아무리, 殺人 → 타살) 넣지 않았습니다.
- 추가 시간(뜻 채우기 + 저장, SQLite 파일 DB): iPhone 17 Pro Max 시뮬레이터 debug 빌드에서 N1만 약 0.35초, 다섯 단어장 차례로 약 0.5초. Mac AOT 0.32초·0.35초. N1만 넣은 DB 0.9 MB, 다섯 단어장 2.2 MB. 실기기 profile 빌드로 재는 방법은 `app/integration_test/deck_add_timing_test.dart` 머리말(iOS 시뮬레이터는 profile 빌드를 지원하지 않음).

### 15.7 다시 만드는 방법

원자료는 저장소 밖 비공개 폴더(`$SHIORI_PRIVATE_DIR`, 기본 `<repo>/.private`)의 `decks/`에 둡니다.

| 위치 | 내용 |
|---|---|
| `decks/yomitan-jlpt-vocab/` | 목록 저장소의 git 클론(커밋 `b062d4e…`). 빌드가 커밋을 git에서 읽음 |
| `decks/supplement.tsv` | 보충 뜻(열: level, entry, headword, meaning, reviewed — 검수자 표시가 모든 행에 있어야 함) |
| `decks/lookup-overrides.tsv` | 조회 표기 지정(열: level, entry, headword, lookup, reviewed), 없으면 지정 없음 |
| `decks/entry-overrides.tsv` | 항목 번호 지정(열: level, entry, headword, fixed, reviewed), 없으면 지정 없음 |
| `tools/dict/.cache/refresh/download/JMdict_e.gz` | JMdict 원본(12절 갱신 도구의 내려받기, 저장소 안이지만 git 제외) |

```bash
# 원자료 (한 번)
git clone https://github.com/stephenmk/yomitan-jlpt-vocab "$SHIORI_PRIVATE_DIR/decks/yomitan-jlpt-vocab"
git -C "$SHIORI_PRIVATE_DIR/decks/yomitan-jlpt-vocab" checkout b062d4e38c4bdd0950ae1d4ec55f04b176182e03
# 앱 asset (app/assets/decks/, git 제외). 기본 경로를 쓰면 --built-on만
python3 tools/decks/build_decks.py --built-on 2026-11-14 \
    --expect-jmdict-sha256 5af39046e9579fd5e14d07a048fccce422b8df0d940ba8c086439e5a7617eab6 \
    --expect-sha256 n5=07dc6f197b51cc076c65c3c9f23218d10c2b67f76545f5c1c4d9e3750495533a
# 판 정보와 대조 + 원자료가 판 정보와 같은 입력이면 다시 빌드해 바이트 비교(없으면 안내 후 건너뜀)
python3 tools/decks/build_decks.py --check
python3 -m unittest discover -s tools/decks -p 'test_*.py'
```

- JMdict를 갱신해도 항목 번호는 유지되므로 단어장을 다시 만들 필요는 없습니다. 다시 만들면 판 정보의 JMdict 판이 바뀝니다.
- `asset_check.py`가 `--decks-dir`(기본 `app/assets/decks`)를 봅니다. 일반 실행은 없으면 「decks: not built」만 찍고, `--release`는 없거나 판 정보와 다르면 실패합니다(Xcode·Gradle release 단계).
- 저장소 안 테스트는 지어낸 작은 단어장만 씁니다. 실제 단어장으로 재는 B2(`packages/jmdict_block/test/builtin_decks_local_test.dart`)는 asset이 있을 때만 돕니다.

### 15.8 남은 문제

1. 한자로 다시 나온 낱말 162개 중 첫 뜻이 가나 단어와 다른 것은 23개입니다. 한자 쪽이 틀린 4개는 조회 표기 지정표로 고쳤고, 나머지는 둘 다 맞거나 한자 쪽이 낫습니다. 쉬운 레벨 가나 단어의 사전 뜻이 어긋난 것(できるだけ → 양껏, かもしれない → -을라)은 뜻 보정(16절)으로 고칩니다.
2. 한자에서 다른 한자로 다시 나온 표기 113개(早い·速い, 川·河)는 지금도 쉬운 레벨의 표기 하나만 넣습니다.
3. 원목록의 영어 뜻 자체가 틀린 행이 있습니다(せめて "offense"). 앱은 영어 뜻을 쓰지 않아 카드에는 영향이 없습니다.
4. 앱 사전이 갱신돼 보충 뜻 단어에 사전 뜻이 생기면 그 보충 행은 쓰이지 않습니다. 실제 asset으로 도는 로컬 테스트(F4)가 그런 행을 알립니다.

## 16. 뜻 보정(시오리 보정) (2026-11-14)

한국어기초사전 역색인(11절)은 낱말의 엉뚱한 뜻을 첫 뜻으로 주는 일이 있습니다(本 → 그루, あそこ → 고기, いる → 보다, できるだけ → 양껏).
그런 낱말에 한해, 이 프로젝트가 직접 쓴 짧은 뜻을 사전의 첫 뜻 앞에 둡니다. 판정·검수 과정과 숫자는 `docs/verification.md` 45절에 있습니다.

### 16.1 데이터와 라이선스

| 항목 | 값 |
|---|---|
| 원본 | 저장소 밖 비공개 폴더의 `meaning/overrides.tsv`(열 level·headword·reading·entry·meaning·reviewed, 그 밖의 열은 무시). 모든 행을 사람이 검수(`reviewed`에 검수자, 덮지 않을 행은 `skip`) |
| 근거 | 그 낱말의 JMdict 영어 뜻(CC BY-SA 4.0)뿐. 한국어 사전(기초사전·위키낱말)의 문구는 옮기지 않음(보충 뜻표 15.1절과 같은 조건) |
| 앱 파일 | `app/assets/dict/meaning-overrides.json`·`meaning-overrides.edition.json`(git 제외, 사전 asset과 같은 폴더) |
| 라이선스 | CC BY-SA 4.0(JMdict에서 나온 데이터). 기초사전 DB(CC BY-SA 2.0 KR)와 다른 파일 |

### 16.2 만드는 규칙 (`tools/dict/build_meaning_overrides.py`)

- 행의 뜻은 행의 표제어와, 같은 JMdict 항목의 한자 표기 중 그 읽기로 읽히는 것에 닿습니다. 가나로 쓴 낱말의 행은 그 항목의 한자 표기 모두에, 한자 낱말의 행은 같은 한자의 표기에만 닿습니다(戸締り → 戸締まり, 翔る → 駆ける는 아님: 다른 한자는 다른 결의 뜻일 수 있음). 한자 낱말의 행은 가나에 닿지 않습니다(같은 가나의 다른 낱말을 덮지 않게).
- 행 자신의 표제어가 다른 행이 항목으로 닿는 표기보다 앞섭니다(いらいら 행이 苛々에 닿아도 苛々 행이 있으면 그 뜻).
- 기초사전 색인과 같은 단위(표기 + 읽기)라서, 덮어쓰기가 사전보다 넓게 걸리지 않습니다.
- 빌드가 멈추는 경우: 검수 표시가 빈 행, 열이 없음, 빈 뜻, 뜻에 일본어 글자, 40자보다 긴 뜻, JMdict에 없는 항목, 항목에 없는 읽기·표기, 같은 표제어·읽기의 행 둘에 다른 뜻.
- 파일: JSON 한 줄에 한 행(`{"f":표기들,"r":읽기,"m":뜻}`), 읽기·표기 순. 판 정보에 행 수·건너뛴 수·표의 sha256·JMdict 판·파일 크기와 sha256. 같은 입력이면 바이트가 같고, 표의 행 순서는 결과를 바꾸지 않습니다.
- `--check`: 판 정보와 대조하고, 표와 JMdict가 판 정보와 같으면 다시 빌드해 바이트를 비교합니다.

### 16.3 앱에서

- core `OverriddenKoreanGlossary(사전, 표)`: (표기, 읽기)가 표에 있으면 표의 뜻을 첫 묶음으로(출처 `GlossarySource.shiori`, 이름 「시오리 보정」), 그 뒤에 사전의 묶음을 같은 글을 뺀 순서 그대로 둡니다. 읽기를 모르는 조회(교재에 읽기가 없음)는 표기만으로 찾습니다. 표에 없는 낱말은 사전의 답 그대로입니다. 거꾸로 찾기(못 읽은 표제어 되살리기)는 사전 그대로입니다.
- `orderMeaningSenses`(docs/extraction.md 4.5절)의 한자음 일치·부정 부사·예문 번역 규칙은 표의 뜻을 밀어내지 않습니다.
- 앱은 기초사전을 열 때 표 파일을 읽어(판 정보의 크기·sha256 대조) 기초사전을 감쌉니다. 한 곳에서 걸리므로 **기본 단어장 추가, 교재 사진의 뜻이 빈 사전 낱말, 단어 고치기·추가의 「사전:」 제안**에 모두 쓰입니다. 짝짓기 신호도 고친 뜻의 낱말을 봅니다. 표가 없거나 맞지 않으면 로그 한 줄을 남기고 사전 그대로 돕니다.
- 이미 저장된 단어의 뜻은 바꾸지 않습니다. 단어 고치기의 「사전에서 다시 찾기」가 고친 뜻을 「사전:」 제안으로 보여 주고, 사용자가 고르면 바뀝니다. 이때 그 단어의 읽기로 항목을 고릅니다(頭 あたま·とう처럼 읽기가 여럿인 한자 낱말).
- 검토 화면 근거는 「사전 뜻: 시오리 보정」, 정보 화면 「한국어 뜻 사전」 아래에 「시오리 보정」 카드(낱말 수, 근거, 라이선스, 만든 날).
- release: `asset_check.py --release`가 표 파일도 봅니다(없음·판 정보 어긋남이면 실패, `--overrides-dir` 기본은 사전 폴더). 일반 실행은 있으면 대조, 없으면 「not built」 한 줄.

### 16.4 다시 만드는 방법

```bash
# 앱 파일 (JMdict asset이 --jmdict-dir에 있어야 함, 기본 app/assets/dict)
python3 tools/dict/build_meaning_overrides.py --built-on 2026-11-14
python3 tools/dict/build_meaning_overrides.py --check
python3 -m unittest discover -s tools/dict -p 'test_*.py'
```

### 16.5 남은 문제

1. 표는 기본 단어장 N5~N1 단어를 판정해 만들었습니다. 교재에만 나오는 낱말의 엉뚱한 첫 뜻은 그대로입니다.
2. 기초사전이 갱신돼 첫 뜻이 바뀌어도 표의 뜻이 앞섭니다. 갱신할 때 표의 행이 아직 필요한지 다시 판정합니다.

