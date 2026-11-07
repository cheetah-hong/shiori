# 뜻 사전에 없는 말 — 보조 원천과 기기 번역 조사

- 날짜: 2026-11-07 (KST), MacBook arm64 · macOS 26.3.1 · Python 3.11
- 질문: 사진에 뜻이 없는 낱말 가운데 한국어 뜻 사전(한국어기초사전 역색인, `docs/dictionary.md` 11절)이 **뜻을 하나도 주지 못하는** 낱말을 무엇으로 채울 수 있는가.
  지금 순위는 건드리지 않고 「뜻 사전이 비었을 때만 보조」로 쓴다는 전제로 쟀다.
- 원천 데이터, 교재 쪽 낱말, 낱말이 찍히는 상세 출력은 저장소에 없다. 비공개 폴더 `$SHIORI_PRIVATE_DIR/meaning/`(기본 `<repo>/.private/meaning/`)에 있다.
  이 문서에는 숫자만 적는다.
- 이 조사 뒤 「한국어판 → 영어판, 뜻 사전이 빌 때만, 별도 asset」 안으로 구현했다: `docs/dictionary.md` 13절, `docs/verification.md` 31절.
  측정 도구의 뜻풀이 규칙은 빌드 도구 `tools/dict/build_wikt_glossary.py`에서 가져다 쓴다.

## 0. 결론

1. **위키낱말사전 두 갈래가 쓸 만하다.**
   - 한국어 위키낱말사전의 일본어 항목(`kowikt`): 뜻 사전이 빈 JLPT 낱말에서 1순위 정확도 **100/107 (93%)**
   - 영어 위키낱말사전의 번역표 경유(`enwikt_tr`): 같은 기준 **83/96 (86%)**
   - 두 원천을 이 순서로 쓰면 뜻 사전이 빈 JLPT N5–N3 낱말 252개 중 **150개(60%)**를 채우고, 눈으로 본 정확도는 **136/150 (91%)**다.
   - 일본어 위키낱말사전의 번역표·역색인은 더 부정확하고(80~83%) 더 채우는 양이 적다.
2. **교재 표본(74단어)의 엄격 일치 효과는 작다.** 1순위 54 → 56, 5순위 안 63 → 65.
   - 1순위를 놓친 「구로 옮기는 말·사전에 없음」 9개 가운데 뜻 사전이 아예 비는 것은 5개뿐이다. 보조 방식이 닿는 곳도 이 5개다.
   - 나머지 4개는 뜻 사전에 다른 뜻이 있다. 그중 둘은 이미 뜻이 맞고 교재와 낱말만 다르다(1절).
3. **기기 번역은 「앱이 직접 네트워크를 쓰지 않음」과 양쪽 플랫폼에서 함께 맞출 수 없다.**
   - iOS Translation: 모델을 시스템이 받아 원칙과 맞는다. 다만 iOS 18 이상이 필요하고(앱 최소 16.2), 처음에 내려받기 동의 화면이 뜨며, 시뮬레이터에서는 동작하지 않는다.
   - Android ML Kit 번역: 앱 프로세스가 모델을 받고 사용 통계를 보낸다. 일→한은 영어를 거친다.
   - 낱말 하나를 번역했을 때의 품질은 재지 못했다(4절).
4. **라이선스는 앱 동봉이 가능하다.** 위키낱말사전 본문은 CC BY-SA 4.0과 GFDL 이중 라이선스이고, CC BY-SA 4.0 쪽을 고른다.
   지금 싣고 있는 JMdict(CC BY-SA 4.0)·Kanjium(CC BY-SA 4.0)과 같은 조건이다. 별도 asset 파일로 두면 기초사전 DB(CC BY-SA 2.0 KR)와 섞지 않는다(3절).

## 1. 1순위를 놓친 「구로 옮기는 말·사전에 없음」 9개의 갈래

교재 표본은 `docs/verification.md` 24절의 74단어이고, 지금 코드로 다시 조회했다(1순위 54, 5순위 안 63 재현).

| 갈래 | 수 | 보조 방식(사전이 비었을 때만)이 닿는가 |
|---|---|---|
| 뜻 사전에 표제어 없음, 한국어로는 구 | 4 | 닿음 |
| 뜻 사전에 표제어 없음, 한국어 한 낱말 | 1 | 닿음 |
| 표제어 있음, 뜻 갈래가 교재와 다름(다의어의 다른 뜻 / 1순위 갈래 틀림) | 2 | 닿지 않음 |
| 표제어 있음, 뜻은 맞고 교재가 다른 낱말·구로 씀 | 2 | 닿지 않음(엄격 일치만 놓침) |
| 고유명사·숫자 | 0 | — |

**74단어 밖(전 세트 15개, 검토 초안 항목 874개)**
- 사전으로 채운 뜻은 451개(서로 다른 175낱말)다. 1순위를 눈으로 보면 다음과 같다.
  - 맞음 147낱말(항목 384)
  - 뜻 갈래 틀림 15낱말(42)
  - 구로 옮겨야 맞음 2낱말(6)
  - OCR 조각 11낱말(19)
  - 이 451개는 「비었을 때만 보조」 방식에서는 바뀌지 않는다. 그래서 이 방식으로 새로 채워지는 수는 0이다.
- 뜻이 아예 없는 항목은 49개(서로 다른 26낱말)다.
  - 뜻 사전에 없는 낱말 8
  - 구로 옮기는 말 5
  - 숫자+조수사 3
  - 고유명사 2
  - 문법 표현 1
  - OCR 조각 7
- 9개와 같은 갈래(표제어 없음·구)는 이 26낱말 중 13낱말(항목 26)이다.

## 2. 원천별 측정

| 원천 (`gap_sources.py` 이름) | 판 | 74단어 1순위 · 5순위 안 | 9개 중 뜻을 줌 · 교재 낱말과 일치 | 세트 빈 뜻 49개 중 채움 | JLPT 빈 252개 중 채움 · 눈으로 본 1순위 정확도 | asset(전체 / 빈 키만, gzip) | 라이선스 · 앱 |
|---|---|---|---|---|---|---|---|
| (지금) 한국어기초사전 | 2026-10-19 | 54 · 63 | — | — | — | 3.66 MB | CC BY-SA 2.0 KR · 사용 중 |
| 한국어 위키낱말사전 일본어 항목 `kowikt` | kaikki `ko-extract` 2026-10-30 | 56 · 65 | 4 · 2 | 13 | 107 · 100/107 (93%) | 345 KB / 158 KB | CC BY-SA 4.0 + GFDL · **가능** |
| 영어 위키낱말사전 번역표 경유 `enwikt_tr` | kaikki English 2026-10-30 (enwiktionary 2026-10-01) | 56 · 65 | 7 · 3 | 13 | 96 · 83/96 (86%) | 1.28 MB / 795 KB | 같음 · **가능** |
| 일본어 위키낱말사전 번역표 `jawikt_tr` | kaikki `ja-extract` 2026-10-30 | 55 · 64 | 3 · 1 | 2 | 23 · 19/23 (83%) | 184 KB | 같음 · 가능 |
| 일본어 위키낱말사전 한국어 항목 역색인 `jawikt_rev` | 같음 | 55 · 64 | 3 · 1 | 16 | 88 · 71/88 (81%) | 674 KB | 같음 · 가능 |
| 한국어 위키낱말사전 한국어 항목 번역표 `kowikt_tr` | `ko-extract` | 54 · 63 | 0 · 0 | 2 | 3 · 3/3 | 25 KB | 같음 · 가능 |
| **`kowikt` → `enwikt_tr` 순서** | | **56 · 65** | **7 · 3** | **21** | **150 · 136/150 (91%)** | **— / 941 KB** | |
| 다섯 원천 모두 | | 56 · 65 | | 25 | 174 · 151/174 (87%) | | |

**표 읽는 법**
- 「74단어」: 엄격 일치(검토 화면 채점과 같은 낱말 일치)로 셌다.
  - 사전이 빈 5개 중 엄격 일치가 2개다. 눈으로 보면 하나 더 맞다(뜻은 맞고 교재가 다른 낱말).
  - 「칩 보조」(뜻 사전 묶음 뒤에 5개까지 보탬)도 재 보았다. 숫자가 「비었을 때만」과 같아서 이득이 없다.
- 「JLPT 빈 252개」
  - open-anki-jlpt-decks의 N5 718·N4 668·N3 2,140 낱말 중 지금 뜻 사전이 뜻을 하나도 주지 못하는 것이다(N5 44, N4 49, N3 159).
  - 목록에서 읽기에만 붙은 `する`는 떼고 조회했다.
  - 정확도는 낱말마다 첫 묶음을 사람이 보고 그 낱말의 한국어 뜻으로 맞는지 판정한 값이다.
- 「세트 빈 뜻 49개」: `kowikt` → `enwikt_tr`로 21개를 채운다.
  - 문맥상 맞음 17, 틀림 1
  - OCR 조각에 뜻이 붙은 것 3. 조각은 원래 여분이고 뜻이 붙어도 신뢰도는 오르지 않는다.
- 「asset」: 원천의 모든 키를 앱과 같은 방식(키 + 읽기 + 낱말, 키 색인)의 SQLite로 만든 크기다.
  「빈 키만」은 뜻 사전에 없는 키만 남긴 크기다(보조로만 쓸 때).

**자주 틀리는 꼴(원천의 성질)**
- `kowikt`
  - 읽기가 거의 없다(일본어 항목 13,633개 중 표기·읽기 칸(forms)이 있는 것 474). 그래서 같은 한자의 다른 읽기를 가리지 못한다(예: 「한 달」로 읽는 낱말에 「일월」).
  - 낱말 쓰임을 설명하는 뜻풀이(「어간의 하나」)가 있어 거른다.
- `enwikt_tr`: 영어 뜻 하나에 걸린 일본어·한국어 낱말을 모두 잇는다. 그래서 영어가 넓은 뜻이면 엇나간다(예: 「지역 단위」 영어 뜻에 걸린 다른 나라 행정 단위).
- `jawikt_*`: 일본어 위키낱말사전의 한자 항목은 대개 「가나 항목 참조」뿐이다. 같은 소리의 다른 낱말로 잘못 이어지기 쉽다.
  - 가나 항목이 하나뿐이거나 그 한자를 적은 경우만 따라가게 했다.
  - 한국어 항목 역색인에는 한자 음 낱말(「청」, 「소조」)이 섞인다.

## 3. 라이선스 (원문 확인 2026-11-07)

**위키낱말사전**
- 위키미디어 이용 약관 7조: "Creative Commons Attribution-ShareAlike 4.0 International License ("CC BY-SA 4.0"), and GNU Free Documentation License ("GFDL") … Reusers may comply with either license or both."
  - https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use
- kaikki: "This data is made available under the same licenses as Wiktionary - both CC-BY-SA and GFDL."
  - https://kaikki.org/kowiktionary/index.html
- wiktextract 코드는 MIT다.
- CC BY-SA 4.0을 고르면 GFDL의 전문 동봉 의무를 지지 않는다.
- 표기: 출처 링크(위키낱말사전 또는 그 안정된 사본), 라이선스 이름과 링크(약관 7조 7·8항). 지금 정보 화면의 사전 카드와 같은 꼴이다.

**동일조건**
- CC BY-SA 4.0 §4(b)에 따라 원천을 담은 데이터베이스는 개작물이 된다. 그래서 만든 DB 파일을 CC BY-SA 4.0으로 배포한다.
- 앱 코드에는 번지지 않는다. JMdict와 같은 근거이고, EDRDG도 "Software using these files does not have to be under any form of open-source licence."라고 적는다.
- 기초사전(CC BY-SA 2.0 KR)과 **한 DB로 합치면** 그 DB도 동일조건 문제가 된다.
  - 2.0 KR의 2차적 저작물은 원래 판 또는 같은 내용의 장래 판으로만 낼 수 있다(2.0 KR §4(2), CC 호환 안내). 4.0으로 낼 수 있다고 읽히지만 해석이다.
  - **별도 asset 파일**로 두면 이 문제가 생기지 않는다.

**쓸 수 없거나 실익이 없는 원천**

| 원천 | 이유 |
|---|---|
| Wikidata 어휘소 | CC0. 일→한 연결이 수백 건뿐이다 |
| MUSE | CC BY-NC 4.0. 일·한 쌍도 없다 |
| OPUS 정렬 사전 ja-ko | 연구용 또는 비상업이거나 라이선스 표기가 없다 |
| hdTrans | AGPL-3.0. 앱 전체를 공개해야 한다 |
| 라이선스 표기가 없는 GitHub 일·한 목록 | 앱 불가 |
| 일본어 WordNet | 한국어 WordNet 쪽 라이선스를 확인하지 못했다 |
| FreeDict, JMdict 다른 언어 | 한국어가 없다 |
| Tatoeba | 문장 데이터(CC BY 2.0 FR)라 뜻 사전이 아니다 |

**참고**
- CC 위키는 App Store의 FairPlay DRM이 CC 라이선스의 기술적 보호 조치 금지에 걸릴 수 있다고 적는다("Further research on this issue would be welcome").
- 정해진 해석은 없다. 지금 싣고 있는 CC BY-SA 데이터 모두에 같은 문제가 있다.
- https://wiki.creativecommons.org/wiki/4.0/Technical_protection_measures

## 4. 기기 번역 (공식 문서 인용, 2026-11-07)

| | iOS Translation (`TranslationSession`) | Android ML Kit 온디바이스 번역 |
|---|---|---|
| 최소 판 | iOS 18.0 (`translationTask`) | Android API 23 |
| 모델을 받는 주체 | 시스템. "These models are shared with all apps on the system, including the Translate app." 처음에는 사용자 동의 화면이 뜬다. iOS 26의 `init(installedSource:target:)`는 설치된 언어만 쓰고 내려받기를 시작하지 못한다 | **앱**. "must be managed manually using the RemoteModelManager API". APK에 동봉할 수 없다(번역은 Dynamically downloaded만 지원) |
| 모델 크기 | 문서에 없음 | "Language models are around 30MB" |
| 번역 처리 | "processed on the user's device" | 기기 안. 다만 "The ML Kit APIs also send metrics … to Google." |
| 「앱이 직접 네트워크를 쓰지 않음」 | **맞음**(받는 것은 시스템) | **어긋남**(모델 내려받기와 사용 통계) |
| 일→한 | 지원("any combination"). 직접인지 영어 경유인지는 문서에 없음 | 영어 경유("English is used as an intermediate translation") |
| 시뮬레이터 | 동작하지 않음("These translation APIs don't function in the simulator.") | — |
| Flutter | 플랫폼 채널 또는 서드파티 패키지가 필요 | `google_mlkit_translation` |

- Android 12+의 `TranslationManager`는 제조사 번역 서비스가 있어야 한다. 없으면 null이다.
- 출처:
  - https://developer.apple.com/videos/play/wwdc2024/10117/
  - https://developer.apple.com/documentation/translation/translationsession
  - https://developers.google.com/ml-kit/language/translation
  - https://developers.google.com/ml-kit/tips/installation-paths
  - https://developers.google.com/ml-kit/android-data-disclosure
- **품질은 재지 못했다.** 이 Mac에서 `LanguageAvailability`는 ja→ko를 `supported`(설치 안 됨)로 답했다. 언어 모델은 시스템 설정에서 사람이 내려받아야 한다.

## 5. 다시 재는 방법

```bash
cd research/meaning/tools
P=${SHIORI_PRIVATE_DIR:-../../../.private}/meaning
# 원천 (합계 약 92MB 저장, 영어판은 내려받으며 걸러 9MB만 남김)
curl -o $P/raw/ko-extract.jsonl.gz https://kaikki.org/dictionary/downloads/ko/ko-extract.jsonl.gz
curl -o $P/raw/ja-extract.jsonl.gz https://kaikki.org/dictionary/downloads/ja/ja-extract.jsonl.gz
curl -s --compressed https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl \
    | python3 en_pivot_rows.py $P/work/en_pivot.jsonl
# 측정 (덤프 JSON은 실제 사전으로 지금 순서를 뽑은 로컬 파일, 형식은 measure_gap.py 머리말)
python3 measure_gap.py $P/work/current.json --kowikt $P/raw/ko-extract.jsonl.gz \
    --jawikt $P/raw/ja-extract.jsonl.gz --en-pivot $P/work/en_pivot.jsonl [--gap <낱말…>] [--detail <로컬 파일>]
python3 -m unittest discover -s . -p 'test_*.py'
```

- 영어판 후처리 파일(`kaikki.org-dictionary-English.jsonl`, 압축 전송 534MB)은 kaikki가 "DEPRECATED"로 표시했다.
- 구현 때는 원자료 `raw-wiktextract-data.jsonl.gz`(3.1GB)나 한국어판 일본어 파일(`kaikki.org/kowiktionary/일본어/`)을 고정 판으로 쓰는 것을 검토한다.
