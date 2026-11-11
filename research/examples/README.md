# 사진에 예문이 없던 낱말의 예문 — 공개 예문 원천 조사

- 날짜: 2026-11-11 (KST), MacBook arm64 · Python 3.9 (Xcode 동봉)
- 질문: 사진에서 예문을 읽지 못한 낱말(단어 목록 쪽만 찍은 경우 등)의 학습 카드에 어떤 공개 예문을 보여 줄 수 있는가.
  앱에 넣을 수 있는지(라이선스), 얼마나 채우는지, 한국어 번역이 얼마나 있는지, 학습자에게 맞는지, 지금 예문 소리 경로로 읽히는지, asset이 얼마나 커지는지를 쟀다.
- 원천 데이터, 교재 쪽 낱말, 판정 표본은 저장소에 없다. 비공개 폴더 `$SHIORI_PRIVATE_DIR/examples/`(기본 `<repo>/.private/examples/`)에 있다. 이 문서에는 숫자만 적는다.
- 이 조사 뒤 「Tatoeba만, 한국어 번역이 없으면 영어 번역」으로 구현했다: `docs/dictionary.md` 14절, `docs/verification.md` 34절.

## 0. 결론

1. **Tatoeba가 거의 모든 낱말을 채운다.**
   - JLPT N5–N3 3,526낱말 중 3,413개(96.8%)
   - 사진에 예문이 없던 교재 낱말 82개 중 73개
   - 눈으로 본 적합도는 29/30이다.
   - 일본어 문장마다 원형 낱말 색인(Tanaka 코퍼스 「B줄」)이 붙어 있다. 그래서 활용형으로 쓰인 문장도 활용 되돌리기 없이 찾는다.
2. **한국어 번역은 적다.**
   - Tatoeba에서 일본어 문장을 한국어로 직접 옮긴 쌍은 666문장뿐이다.
   - 고른 예문에 직접 번역이 붙는 낱말은 JLPT의 22%다(N5 48%, N4 27%, N3 11%).
   - 영어 번역을 거친 한국어까지 치면 45%다. 다만 이 경우 30개 중 3개가 틀린 번역이었다.
   - 한국어 위키낱말사전 예문은 모두 한국어 번역이 있다. 하지만 24%만 채우고 적합도는 24/30이다.
3. **앞에 둘 원천은 둘 중 하나다.**
   - 한국어 위키낱말사전 → Tatoeba 순서: JLPT 97.1%를 채우고 36%에 직접 한국어 번역이 붙는다.
   - Tatoeba 한 원천: 적합도가 더 높다.
4. **라이선스는 둘 다 앱에 넣을 수 있다.**
   - Tatoeba: CC BY 2.0 FR. 동일조건이 없고, 앱 어딘가에 출처·링크·라이선스를 한 번 적으면 된다.
   - 위키낱말사전: CC BY-SA 4.0. 지금 싣는 보조 사전과 같은 조건이다.
5. **소리와 크기**
   - 지금 예문 소리 경로(엔진 추정 + 카드 낱말 악센트구 고정)로 그대로 읽힌다.
     카드 낱말이 문장에 그대로 나와 악센트를 고정할 수 있는 비율은 62.9%다. 사진에서 읽은 예문(60.4%)과 비슷하다.
   - asset은 JMdict 낱말 전체에 낱말당 1문장이면 gzip 약 1.3MB, 2문장이면 약 2.0MB다.

## 1. 원천

| 원천 | 판 (받은 날 2026-11-11) | 규모 | 한국어 번역 | 라이선스 | 앱 |
|---|---|---|---|---|---|
| **Tatoeba** 일본어 문장 + 원형 색인 | 주간 내보내기 2026-11-07 (`per_language/jpn/*`, `jpn_indices.tar.bz2`) | 일본어 248,970문장, 그중 색인 있는 것 149,855 | 일→한 직접 연결 2,262쌍(색인 있는 문장 중 666문장), 영어를 거친 한국어 2,455문장 | CC BY 2.0 FR. 일부 언어만 CC0이고 일본어 CC0 문장은 2개 | **가능** |
| **JMdict 예문** (`JMdict_e_examp.gz`) | JMdict 2026-11-11 | 예문 32,434 (뜻마다 고른 Tatoeba 문장) | Tatoeba 연결로 395 | 파일은 CC BY-SA 4.0(EDRDG), 문장은 Tatoeba | 가능. 다만 Tatoeba의 부분집합이다 |
| **한국어 위키낱말사전** 일본어 항목 예문 `kowikt` | kaikki `ko-extract` 2026-10-30 (뜻 조사 때 받음) | 쓸 수 있는 예문 3,116 (JMdict 항목 2,953개에 붙음) | 거의 전부 | CC BY-SA 4.0 + GFDL | **가능** |
| **영어 위키낱말사전** 일본어 항목 예문 `enwikt` | kaikki 원자료 enwiktionary 2026-10-01 (뜻 조사 때 받음) | 10,746 (항목 9,460) | 없음(영어) | 같음 | 가능 |
| **일본어 위키낱말사전** 예문 `jawikt` | kaikki `ja-extract` 2026-10-30 | 8,686 (항목 5,640) | 없음(번역 없음) | 같음 | 가능 |
| JEC Basic Sentence Data (교토대) | 받지 않음 | 5,304문장(일·영·중) | 없음 | CC BY 3.0 | 가능. 규모가 작고 낱말 색인이 없어 재지 않았다 |

**판정에 쓴 원문**
- Tatoeba 내려받기 화면: "These files are released under CC BY 2.0 FR"
  - https://tatoeba.org/en/downloads
- Tatoeba 이용 약관
  - "Creative Commons Attribution 2.0 France license (CC-BY 2.0 FR) for the use of textual sentences."
  - "The BY mention implies a single restriction on the use, reuse, modification and distribution of the sentence: a condition of attribution."
  - https://tatoeba.org/en/terms_of_use
- Tatoeba FAQ(상업적 이용)
  - "write somewhere that some/all of your sentences are from Tatoeba, with a link to https://tatoeba.org, and mention that Tatoeba's data is released under CC-BY 2.0 FR"
  - 녹음은 "a wider range of licenses"라서 쓰지 않는다. 소리는 앱 안의 VOICEVOX가 만든다.
  - https://en.wiki.tatoeba.org/articles/show/faq
- Tanaka 코퍼스(Tatoeba 일본어 문장의 뿌리)의 품질 경고
  - "cannot be regarded as containing natural or representative examples of text in either language"
  - "The sentences were typed in by students … While many have been corrected some still remain."
  - 색인의 `~`는 "a good and checked example of the usage of the word"다.
  - https://www.edrdg.org/wiki/Tanaka_Corpus.html, https://www.edrdg.org/wiki/Sentence-Dictionary_Linking.html
- 위키낱말사전 라이선스 원문은 `research/meaning/README.md` 3절에 있다.

**동일조건**
- CC BY 2.0 FR에는 동일조건이 없다. Tatoeba 문장만 담은 asset은 앱 코드나 다른 asset과 섞여도 조건이 번지지 않는다.
- 위키낱말사전 예문을 넣으면 그 DB는 CC BY-SA 4.0이 된다. 지금 보조 사전처럼 **별도 asset 파일**로 둔다.
- JMdict 예문 파일을 원천으로 쓰면 CC BY-SA 4.0 파일의 일부를 가져오는 것이 된다. 같은 문장은 Tatoeba에서 직접 받을 수 있으므로 Tatoeba를 쓴다.

## 2. 측정

낱말 목록
- **JLPT**: open-anki-jlpt-decks N5 718 · N4 668 · N3 2,140(뜻 조사와 같은 목록과 같은 읽기 방식). JMdict 항목에 붙는 것은 715 · 657 · 2,136개다.
- **세트**: 15세트 검토 초안(뜻 조사 때 지금 추출기로 뽑은 덤프. 그 뒤 추출기 코드는 바뀌지 않았다)에서 예문 없이 나온 서로 다른 표제어다.
  - 로컬 교재 세트 82개(정답에 있는 낱말 76, 나머지는 OCR 조각)
  - 합성 세트 105개

낱말과 예문은 JMdict 항목 번호로 잇는다.
- 낱말 쪽: 표기 → 항목. 읽기로 좁힌다. 가나로만 쓴 낱말은 가나 항목 → 보통 가나로 쓰는 항목 → 상용 읽기 순으로 고른다.
- Tatoeba 쪽: 색인의 원형(읽기, `#번호`) → 항목.
- 문장 속 읽기가 낱말 읽기와 다르면(辛い를 つらい로 읽은 문장) 뺀다.

**카드에 올릴 수 있는 예문**
- 6~30자이고 가나가 있다.
- 한글·라틴 글자·나열 기호·주석 표시가 없다.
- 민감한 낱말 목록에 걸리지 않는다.
- Tatoeba의 부적합 태그(`@needs native check`, 고어, 사투리 등)가 없다.

**고르는 순서**
1. 그 문장의 한국어 직접 번역이 있음
2. 검증 표시 `~`
3. 영어를 거친 한국어
4. N5–N3 낱말에 없는 한자가 적음
5. 문장으로 끝남
6. 14자에 가까움

### 2.1 채움과 번역 (고른 첫 예문 기준)

| 원천 | JLPT 채움 (N5 · N4 · N3) | 합 | 한국어 직접 | 한국어(영어 경유 포함) | 영어 | 교재 세트 82 | 합성 세트 105 |
|---|---|---|---|---|---|---|---|
| Tatoeba | 709 · 649 · 2,055 | **3,413 (96.8%)** | 778 (22.1%) | 고를 수 있는 것 1,595 (45.2%) | 3,394 | **73** | 100 |
| JMdict 예문 | 689 · 632 · 1,956 | 3,277 (92.9%) | 27 | 97 | 3,277 | 71 | 95 |
| kowikt | 384 · 195 · 260 | 839 (23.8%) | 838 | 838 | 0 | 19 | 47 |
| enwikt | 377 · 289 · 760 | 1,426 (40.4%) | 0 | 0 | 1,425 | 31 | 49 |
| jawikt | 278 · 221 · 525 | 1,024 (29.0%) | 0 | 0 | 0 | 25 | 29 |
| **kowikt → Tatoeba** | 710 · 650 · 2,065 | **3,425 (97.1%)** | **1,271 (36.0%)** | 1,864 (52.9%) | 2,570 | 73 (한국어 41) | 101 (한국어 63) |
| Tatoeba → kowikt | 710 · 650 · 2,065 | 3,425 (97.1%) | 790 (22.4%) | 1,864 (52.9%) | 3,394 | 73 (한국어 30) | 101 (한국어 44) |

**표 읽는 법**
- 「합」의 비율은 목록 3,526낱말에 대한 비율이다.
- 「한국어 직접」은 고른 첫 예문에 그 문장의 한국어 번역이 있는 낱말 수다.
- 「영어 경유 포함」은 쓸 수 있는 예문 중 하나라도 한국어가 있는 낱말 수다.
- 교재 세트 82개 중 4개는 JMdict 항목에 붙지 않는다(정답 낱말 2, OCR 조각 2). 정답에 있는 낱말만 세면 Tatoeba가 76개 중 71개를 채운다.
- 학습자 수준 어림: Tatoeba가 고른 예문의 94.5%(3,226/3,413)는 N5–N3 낱말에 없는 한자를 쓰지 않는다. 길이의 중앙값은 15자다.
  - 사진에서 읽은 예문(조각 포함)의 중앙값은 11자다.

### 2.2 눈으로 본 적합도 (원천마다 JLPT에서 무작위 30)

| 원천 | 적합 | 틀리는 꼴 |
|---|---|---|
| Tatoeba | **29/30** | 문어투 격언 1. 교과서 같은 문장이 많고 일부는 딱딱하다 |
| Tatoeba 영어 경유 한국어(번역만 판정) | 27/30 | 다른 문장의 번역이 붙음(속담 2개), 뜻이 바뀐 번역 1. 느슨한 번역이 4개 더 있다 |
| JMdict 예문 | 28/30 | 어색한 문장 1, 약자 나열 1 |
| enwikt | 27/30 | 다른 한자 낱말 1, 어색한 문장 1, 다른 뜻 1. 30개 중 7개는 「…する」 꼴의 구 |
| kowikt | 24/30 | 잘린 문장, 고유명사 구, 다른 낱말·다른 뜻, 문법 표현. 한국어 번역은 맞다 |
| jawikt | 20/30 | 낱말 나열 5, 같은 소리 다른 낱말 2, 속어 뜻 1 등. 번역이 없다 |

- 첫 측정에서는 가나 낱말 하나에 같은 소리 한자 낱말 수십 개의 예문이 붙었다(`こう`에 稿·項).
  읽기가 다른 쓰임도 섞였다(辛い). 위 규칙으로 고친 뒤의 숫자다.
- **부적절한 내용 거르기**는 세 겹이다.
  1. Tatoeba 태그
  2. 민감 낱말 목록(34개)
  3. 「검증 표시 우선」
  - 색인 있는 Tatoeba 문장 중 길이·글자 조건을 맞는 140,303개에서 태그로 377개(0.3%), 낱말 목록으로 564개(0.4%)가 빠진다. 이 30개 표본에는 거를 문장이 없었다.
  - 목록은 거친 거름이다. 구현 때는 고른 결과(낱말당 1~2문장)를 한 번 훑어보는 단계를 두는 것을 권한다.

## 3. 한국어 번역이 없을 때

- 원천의 한국어 직접 번역 비율: Tatoeba 고른 예문 22%. kowikt를 앞에 두면 36%.
  - 낮은 급일수록 높다: N5 71%, N4 45%, N3 21%(kowikt → Tatoeba).
- 가능한 표시
  - (a) 일본어만 보여 준다. 지금 카드의 예문 번역 칸을 비운다.
  - (b) 영어 번역을 보여 준다. Tatoeba는 99%에 영어가 있다.
  - (c) 영어를 거친 한국어를 보여 준다. 표본 30개 중 3개가 틀렸으므로 「번역(영어 경유)」처럼 따로 표시해야 한다.
- 기기 번역은 다시 조사하지 않았다(`research/meaning/README.md` 4절).
  - iOS Translation은 iOS 18 이상이 필요하다(앱 최소 16.2).
  - Android ML Kit은 앱이 모델을 받고 통계를 보내므로 「앱이 네트워크를 쓰지 않음」 원칙과 맞지 않는다.

## 4. 소리 (지금 예문 경로)

- VOICEVOX core 0.17.1, Nemo 女声4 ノーマル(스타일 10003), 1.0배, Mac에서 Python 바인딩으로 확인했다.
- Tatoeba가 고른 예문 12개(무작위 8, 전각 숫자 2, 낫표 2)를 합성했다.
  - 모두 오류 없이 읽혔다. `６月`→ロクガツ, `２人`→フタリ, `6対6`→ロク/タイロク.
  - 길이는 1.8~4.8초, 만드는 데 0.4~0.9초다.
  - 낫표로 시작하는 문장은 Open JTalk가 「첫 박 짧은 쉼」 경고를 내지만 WAV는 정상으로 만들어진다.
  - 귀로 듣지는 않았다. 박 수와 악센트구 나눔만 확인했다.
- 앱은 카드 낱말이 문장 안에 표기 그대로 나오고 더 긴 한자·가타카나 말의 일부가 아닐 때만 그 악센트구를 Kanjium 값으로 고친다(`packages/voicevox_block` `speech_plan.dart`).
  - 그 조건을 맞추는 비율: Tatoeba가 고른 JLPT 예문 **2,147/3,413 (62.9%)**, 사진에서 읽은 예문 113/187 (60.4%, 로컬 세트의 낱말·예문 쌍).
  - 나머지(활용형, 가나로 쓴 한자 낱말)는 교재 예문과 같이 엔진 추정으로 읽는다.

## 5. asset 크기

SQLite(낱말 항목 번호, 일본어, 한국어, 영어, 원천, 문장 번호, 작성자) + 번호 색인, `gzip -9`. 작성자 칸은 FAQ상 필요 없어 상한이다.

| 원천 | 범위 | 항목 | 낱말당 1문장 (영어 없음 / 있음) | 낱말당 2문장 (영어 없음 / 있음) |
|---|---|---|---|---|
| Tatoeba | 예문 있는 JMdict 항목 전부 | 27,064 | 1.26 MB / 1.95 MB | 1.96 MB / 3.03 MB |
| Tatoeba | JLPT N5–N3만 | 3,327 | 0.16 MB / 0.23 MB | 0.29 MB / 0.43 MB |
| kowikt → Tatoeba | 전부 | 27,330 | 1.30 MB / 1.98 MB | 1.99 MB / 3.01 MB |
| JMdict 예문 | 전부 | 24,836 | 1.12 MB / 1.76 MB | 1.19 MB / 1.88 MB |

- 풀린 SQLite는 2.5~6.0 MB다.
- 지금 앱 asset(음성 모델 75 MB, JMdict 12 MB)에 비하면 작다.

## 6. 다시 재는 방법

```bash
# 저장소 루트에서
P=${SHIORI_PRIVATE_DIR:-$PWD/.private}
mkdir -p $P/examples/raw/tatoeba $P/examples/work
# Tatoeba (약 42 MB)
(cd $P/examples/raw/tatoeba && for f in per_language/jpn/jpn_sentences_detailed.tsv.bz2 per_language/jpn/jpn-kor_links.tsv.bz2 \
         per_language/jpn/jpn-eng_links.tsv.bz2 per_language/jpn/jpn_tags.tsv.bz2 \
         per_language/kor/kor_sentences_detailed.tsv.bz2 per_language/eng/eng_sentences.tsv.bz2 \
         per_language/eng/eng-kor_links.tsv.bz2 jpn_indices.tar.bz2; do
  curl -O https://downloads.tatoeba.org/exports/$f; done)
# JMdict 예문판 (13 MB)
curl -o $P/examples/raw/JMdict_e_examp.gz https://www.edrdg.org/pub/Nihongo/JMdict_e_examp.gz
# 영어 위키낱말사전 일본어 항목 (뜻 조사 때 받은 원자료에서 거름)
gzip -dc $P/meaning/wikt/raw-en-2026-10-01.jsonl.gz | grep -F '"lang_code": "ja"' | gzip > $P/examples/work/enwikt-ja-entries.jsonl.gz
# 측정 (약 1분, --assets는 몇 분 더). 한국어판·일본어판 위키낱말사전, JLPT 목록, 추출기 덤프는 뜻 조사의 비공개 폴더에서 읽음
cd research/examples/tools
SHIORI_PRIVATE_DIR=$P python3 measure_examples.py --samples $P/examples/work/samples --assets $P/examples/work/assets
python3 -m unittest discover -s . -p 'test_*.py'
```

- Tatoeba와 EDRDG는 최신판만 내려 준다. 판을 고정하려면 받은 파일의 sha256을 기록한다.
