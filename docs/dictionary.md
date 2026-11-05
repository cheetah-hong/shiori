# 사전 블록(JMdict) 결과 보고

- 날짜: 2026-11-05 (KST)
- 결과물
  - `packages/dict_jmdict/`: 순수 Dart 패키지, 테스트, README
  - `tools/dict/`: 데이터 빌드 스크립트, 효과 측정 스크립트
  - 이 문서
- core(`packages/core`)와 `app/`은 건드리지 않았습니다. 어댑터와 포트 확장은 7절에 제안으로만 적습니다.
- 교재 측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했습니다(4절).

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

| 메서드 | 구분 | 하는 일 |
|---|---|---|
| `lookupByReading(kana, {limit, requireKanji, prefer})` | 기본 | 표제어 후보와 순위 근거(`priority`, `rankReason`) |
| `hasPair(headword, reading)` | 기본 | 짝이 그대로 있는가 |
| `checkPair(headword, reading)` | 추가 | 교재 표기 차이를 허용한 짝 확인 → `PairMatch` |
| `suggestHeadword(ocrText, reading, {limit, prefer})` | 기본 | 헷갈리는 글자 표(기준 보정기와 같은 목록, 양방향)와 가나 문자 바꾸기로 사전에 있는 짝만 순위대로 |
| `lookupByHeadword(headword)` | 추가 | core 포트의 `byHeadword`용 |
| `info` | 추가 | 출처, 날짜, sha256, 라이선스, 표기 문구 |

- **의존성**: `sqlite3: ^3.8.0` 하나뿐입니다(dart:ffi, 빌드 훅으로 SQLite 동봉). Flutter와 core에는 의존하지 않습니다. 루트 workspace 파일은 만들지 않았습니다.
- **검증**
  - `dart analyze`: 문제 없음
  - `dart test`: 63개 모두 통과
  - 라인 커버리지: 96.2%(462/480)
- **테스트 DB**: `test/fixtures/mini_jmdict.sql`(JMdict 89개 항목, SQL 텍스트 47 KB)
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

## 7. core `Dictionary` 포트에 맞출 어댑터 (코드 스케치)

core는 읽기만 했습니다(`packages/core/lib/src/ports/dictionary.dart`, `capture/correctors/*`, `app/lib/app/blocks.dart`).
아래는 제안이며, 포트와 core를 고칠지는 core 쪽에서 따로 정합니다.

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

### 7.4 Flutter 탑재 (방법만, 이번에 하지 않음)

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
6. **모의 측정 데이터**: JLPT 목록(Waller CC BY, stephenmk CC BY-SA)은 측정에만 쓰고 앱에 넣지 않으므로 표기 의무가 없습니다.

## 9. 남은 문제

1. **데이터 갱신 방식 결정(라이선스 의무)**
   - **결정(2026-11-05): 나중에 자동화로 처리한다.** 예: CI가 최신 JMdict로 DB를 다시 빌드한다. 구체적인 방식은 사전을 앱에 붙이는 단계에서 정한다.
   - 서버가 없으면: 앱을 출시할 때마다 최신 JMdict로 다시 빌드하는 절차(CI 작업)
   - 또는 앱 안에서 정적 호스팅(GitHub 릴리스 등)의 DB를 받는 방식
   - 둘 중 무엇을 쓸지는 그 단계에서 정합니다.
2. **앱 크기**: 설치 후 30.5 MB(gzip 12.2 MB)입니다. gzip asset을 풀어 쓰면 디스크 약 42 MB를 씁니다. 첫 실행 때 내려받으면 30.5 MB지만 네트워크가 필요합니다.
3. **core 쪽 합의 필요**
   - 포트 확장(`checkPair`, `fixHeadword`, 품사 힌트)
   - `CapturedEntry.ocrHeadword`
   - 새 `IssueKind`(사전에 없음)
   - `DictionaryPairCorrector`
   - 규칙 보정기를 좁히는 일(7.3)
   - 모두 core 쪽에서 정할 일입니다.
4. **교재 표본이 작음**: 사전이 쓰이는 줄이 59줄 중 5줄(빠진 표제어 2, 규칙 보정 3)뿐입니다. 사진이 더 모이면 같은 스크립트로 다시 잽니다(`--data`, `--truth`).
5. **동음이의어**: 문맥 없이 1순위는 82–84%입니다. 후보 3개 이상을 보여 주고 학습자가 고르게 합니다.
6. **다루지 않는 경우**
   - 읽기 자체가 틀린 경우(측정에서 59/59 맞음)
   - 읽기에 가타카나가 섞인 사전 항목(`ハ長調【ハちょうちょう】`을 히라가나 읽기로 찾지 못함)
   - 세 단어 이상 합성어와 촉음화(`学`+`校`=`がっこう`)
   - OCR이 글자를 빼거나 더한 경우(글자 수가 같은 바꿈만 다룸)
7. **합성어 확인은 약한 확인**: 헷갈리는 글자로 바뀐 표기도 두 단어로 나뉘면 통과합니다(`二短調`). 보정기에서 OCR 원문을 우선하는 순서로 보완합니다(7.3).
8. **영어 뜻 나누기**: 뜻은 `; `로 이어 저장해서, 뜻 문장 안에 `; `가 있으면 잘못 나뉩니다(드묾). 권고 판에는 뜻이 없습니다.

## 10. 다시 돌리는 방법

```bash
# 데이터 (원본이 없으면 EDRDG에서 https로 받음, 약 25초). 이 보고서의 판으로 고정하려면 sha256을 줌
python3 tools/dict/build_jmdict_db.py --matrix \
    --expect-sha256 7f6dc7a4a50411e5a99c35969f28740e174714f04708ea84d50d6bdc09a001ed
# 테스트 DB
python3 tools/dict/build_jmdict_db.py --only tools/dict/test_forms.txt --glosses first \
    --sql packages/dict_jmdict/test/fixtures/mini_jmdict.sql
# 패키지
(cd packages/dict_jmdict && dart pub get && dart analyze && dart test)
# 효과 측정 (기준 해석기: --prototype DIR, 기본은 tools/reference, 없으면 research/ocr/prototype)
# 교재 데이터는 비공개 폴더 $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3 에서 읽음 (SHIORI_PRIVATE_DIR 기본값 <repo>/.private)
python3 tools/dict/eval_dict.py --fetch-jlpt --verbose
# 저장소에 있는 합성 세트로 돌리기 (--data는 tools/reference/parse_eval.py로 넘어감)
python3 tools/dict/eval_dict.py --data packages/core/test/fixtures/synthetic
```

| 경로 | 내용 |
|---|---|
| `tools/dict/build_jmdict_db.py` | JMdict XML → SQLite(판본 선택, 크기표, 테스트용 SQL 덤프) |
| `tools/dict/test_forms.txt` | 테스트 DB에 넣을 JMdict 표기 목록 |
| `tools/dict/eval_dict.py` | 효과 측정(기준 해석기 + Dart 패키지 호출) |
| `packages/dict_jmdict/lib/` | 패키지(`jmdict_dictionary.dart`, `confusables.dart`, `spelling.dart`, `priority.dart`, `kana.dart`, `models.dart`) |
| `packages/dict_jmdict/test/` | 단위 테스트 63개와 테스트 DB |
| `packages/dict_jmdict/tool/query_batch.dart` | 측정용 일괄 호출 도구 |
