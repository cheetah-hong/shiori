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
7. **모의 측정 데이터**: JLPT 목록(Waller CC BY, stephenmk CC BY-SA)은 측정에만 쓰고 앱에 넣지 않으므로 표기 의무가 없습니다.

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
| `tools/dict/asset_check.py` | 배포 전 검사(크기·sha256·판 정보 필드·DB 안 meta). 테스트 `tools/dict/test_asset_check.py` |
| `tools/dict/refresh.py` | 정기 갱신(12절). 테스트 `tools/dict/test_refresh.py` |
| `tools/dict/test_forms.txt` | 테스트 DB에 넣을 JMdict 표기 목록 |
| `packages/dict_jmdict/lib/` | 패키지(`jmdict_dictionary.dart`, `form_lookup.dart`, `priority.dart`, `models.dart`) |
| `packages/dict_jmdict/test/` | 단위 테스트와 테스트 DB |
| `packages/jmdict_block/` | core `Lexicon` 포트 어댑터, 실제 사전 점수표 `tool/eval_extract_dict.dart` |

## 11. 한국어 뜻 사전 (한국어기초사전 일본어 대역어 역색인, 2026-11-05)

JMdict는 영어 뜻뿐이라, 사진에 한국어 뜻이 없거나 읽지 못했을 때 채울 데이터가 없습니다.
한국어 뜻의 출처 순서는 ① 사진 속 한국어 → ② **한국어기초사전 역색인(이 절)** → ③ 한국어 위키낱말사전 → ④ 기기 번역입니다.
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
3. **빠지는 말**: 한국어에서 구로 옮기는 말(사전에 단어 항목이 없음), 숫자·조수사, 오쿠리가나가 다른 표기, 경어·호칭(사전에 다른 낱말로 올라 있음). 74단어 표본에서 1순위를 놓친 20개 중 9개가 이 갈래입니다(칩으로도 못 구함). 위키낱말사전(③)이 일부를 메웁니다.
4. **갱신**: 기초사전은 판이 바뀌면 같은 명령으로 다시 빌드합니다. 갱신 의무 조항은 없지만 JMdict 갱신과 같이 `tools/dict/refresh.py`로 묶었습니다(12절).

## 12. 정기 갱신과 무결성 검사 (2026-11-06)

EDRDG 라이선스 4절은 데이터를 정기적으로 갱신하는 절차를 요구합니다(8절 5). 그 절차를 도구로 만들고,
빌드 때와 앱 실행 때 asset이 판 정보와 맞는지 확인하는 장치를 더했습니다. 검증 숫자는 `docs/verification.md` 23절입니다.

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
python3 tools/dict/asset_check.py [--dir app/assets/dict] [--max-age-days N]
python3 tools/dict/build_app_asset.py --check      # JMdict만
python3 tools/dict/build_ko_glossary.py --check    # 한국어 뜻 사전만
```

- 판 정보의 필드(공통 `variant`·`built_on`·`gzip_bytes`·`sqlite_bytes`·`sqlite_sha256`, JMdict `source_sha256`·`jmdict_created`·`license`,
  한국어 `sources[]`·`attribution`), gzip 크기, 끝까지 풀리는지, 푼 크기·sha256, DB 안 `meta`가 판 정보와 같은지(원본 sha256·JMdict 날짜, 기초사전 판·판본).
- 어긋난 것마다 한 줄, 하나라도 있으면 종료 1. `--max-age-days N`(기본 꺼짐)은 `built_on`이 N일보다 오래된 asset을 실패로 봅니다.
- release 빌드 단계(Gradle·Xcode)에는 아직 묶지 않았습니다. 배포 전에 위 명령을 직접 돌립니다.

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

### 12.4 「정기」를 돌리는 방식 (결정 남음)

| 안 | 방식 | 장점 | 단점 |
|---|---|---|---|
| A | 로컬에서 매달 `refresh.py`를 손으로 돌림 + 달력 | 기반 시설 없음, 로컬 기록 세트로 관문까지 돎 | 잊을 수 있음 |
| B | 로컬 예약(launchd, 월 1회, `--dry-run`)과 알림 | 잊지 않음 | 그 컴퓨터가 켜져 있어야 함, 채택은 사람이 |
| C | 원격 CI 예약 | 사람·기계와 무관 | 로컬 기록 세트로 관문 불가, asset 배포 경로를 새로 정해야 함 |

배포 전 검사(12.2)를 release 빌드 단계에 묶을지, `--max-age-days`(예: 35일)로 오래된 사전의 배포를 막을지도 함께 정합니다.

