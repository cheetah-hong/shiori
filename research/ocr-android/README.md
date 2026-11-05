# Android ML Kit OCR 실측: Apple Vision과 같은 사진, 같은 채점기

- 날짜: 2026-11-05 (KST). 교재 5쪽, 단어 59개. Apple Vision 측정(`research/OCR_TEST.md`)과 같은 입력이다.
- **측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했다.**
  - 판독 원본, fixture, 점수 파일에는 교재 본문이 들어 있다. 그래서 로컬 전용 데이터 폴더 `$SHIORI_PRIVATE_DIR/textbook/ocr-android/`(`SHIORI_PRIVATE_DIR` 기본값은 `<repo>/.private`)에만 둔다.
  - 이 문서에 나오는 `raw/`, `work/`, `fixtures*/`, `variants/`, `scores*.txt`, `compare.txt`, `ablation.txt`는 모두 이 데이터 폴더 안의 경로다.
  - 문서에 든 글자 예는 합성 세트(`packages/core/test/fixtures/synthetic/`)의 단어로 바꾼 같은 형태의 예다.
- 엔진: Google ML Kit text recognition v2, **번들 모델**
  - `com.google.mlkit:text-recognition-japanese:16.0.1`
  - `com.google.mlkit:text-recognition-korean:16.0.1`
  - 둘 다 2026-11-05 기준 최신이고, 모델이 APK 안에 들어간다.
- 기기: Android 에뮬레이터(arm64, API 36.1, 1코어, RAM 2GB). **처리 시간은 실제 기기 성능이 아니다.**

## 0. 결론

| | Apple Vision | ML Kit, 원래 해석기 | ML Kit, 보정 후 (조각 단위) |
|---|---|---|---|
| 찾음 | 59/59 | 41/59 | **59/59** |
| 줄 전체가 맞음 | **52/59** | 11/59 | **38/59** |
| 예문 일·한 | 12/12 · 12/12 | 1/12 · 1/12 | 12/12 · 12/12 |
| 조용한 오류(항목 기준 / 칸 기준) | 1 / 1 | 2 / 11 | 1 / 2 |

표의 분모는 모두 정답 기준(단어 59개, B형 예문 12개)이다. 기준 채점기는 찾은 단어만 분모로 센다(원래 해석기의 예문은 `1/6`으로 출력). 칸 기준 조용한 오류 11은 `scores_rules_off_strict.txt`에 있다.

1. 원래 해석기를 ML Kit 결과에 그대로 쓰면 **11/59**만 맞는다. 단어도 41개밖에 찾지 못한다. ML Kit는 Vision과 줄을 나누는 방식이 달라서, ★를 읽기에 붙이고 작은 번호 줄을 놓친다.
2. 엔진별 보정 규칙 18개를 넣고, Line을 칸 경계에서 자른 "조각" 단위를 쓰면 **38/59**가 된다. 단어는 59개를 모두 찾고, 예문도 일·한 12/12로 모두 맞는다.
3. 남은 21줄 중 **13줄은 ★ 표시만 틀린 경우**다. ML Kit가 ★ 30개 중 13개를 아예 출력하지 않는다. ★를 제외하면 51/59로, Vision의 52/59와 거의 같다.
4. 보정 규칙을 Vision 결과에 켜도 점수가 변하지 않는다(52/59). 그래서 엔진과 상관없이 한 해석기에 함께 둘 수 있다.
5. 판단: **Android에서도 기기 OCR로 단어 등록이 된다.** 다만 다음 세 가지를 받아들여야 한다.
   - ★(중요 표시)는 Android에서 절반 가까이 빠진다.
   - 一·十처럼 획이 아주 적은 한자 표제어는 "표제어 없음"으로 표시된다.
   - 보정 규칙이 5쪽에 맞춰져 있다. 같은 사진을 다른 경로로 디코딩해도 새로운 잡음이 나온다(6절).

## 1. 방법

1. **입력 이미지:** `tools/prepare_images.py`로 만든다. `make_fixture.py`와 같은 방식이다(PIL `exif_transpose` 뒤 추가 회전, RGB, JPEG 품질 92).
   - 사진과 `pages.json`(쪽 → 사진 파일, 추가 회전)은 비공개 폴더 `$SHIORI_PRIVATE_DIR/textbook/photos/`에서 읽는다. 다른 곳에 있으면 `--photos DIR`로 준다.
   - 결과는 데이터 폴더의 `work/images/upright/`에 둔다.
2. **판독 앱:** `mlkit_probe/`. Kotlin으로 썼고 화면은 없다.
   - 진입점은 Instrumentation이다. `adb shell am instrument -w`로 실행하면 판독이 끝날 때까지 기다린다. 테스트 라이브러리는 필요 없다.
   - 사진 한 장을 Japanese recognizer와 Korean recognizer로 한 번씩, 모두 두 번 판독한다.
   - ML Kit 결과 계층 전체를 원본 JSON(`raw/<입력>-<방식>/<page>.<lang>.raw.json`)으로 저장한다. 블록 > 줄 > 요소 > 글자, 각각의 픽셀 상자·신뢰도·각도·언어가 들어 있다.
   - 처리 시간과 메모리는 `timing.json`에 남긴다.
3. **사진 넣기와 결과 빼기:** 앱의 외부 저장소(`/sdcard/Android/data/dev.nihongo.mlkitprobe/files/in|out`)에 `adb push`/`pull`한다.
   - 입력 폴더는 앱이 먼저 만들어야 한다(`-e action prepare`).
   - `adb shell mkdir`로 만든 폴더는 소유자가 `shell`이라 앱이 읽지 못한다. 처음에 이 문제를 겪고 고쳤다.
4. **fixture 변환:** `tools/raw_to_fixture.py`가 Vision과 같은 형식으로 바꾼다.
   - 형식: `{"engine":"mlkit","langs":["ja"],"ms":N,"lines":[{t,c,x,y,w,h}]}`
   - 좌표: `boundingBox`(축 정렬 상자)를 회전 적용 후 이미지 크기로 나눈다. 0~1 값이고 기준점은 왼쪽 위, 소수 넷째 자리까지 쓴다.
   - **`Text.Line.getConfidence()`는 제공된다.** 그래서 c=1.0으로 대신 쓴 줄은 없다. `getAngle()`도 제공된다.
5. **채점:**
   - 원래 점수는 기준 해석기 `research/ocr/prototype/parse_eval.py`를 고치지 않고 돌린다(`scores.txt`).
   - 보정은 복사본 `parse_eval_mlkit.py`에서 시험한다. 규칙마다 이름이 있고 하나씩 끌 수 있다.
   - **규칙을 모두 끄면 기준 해석기와 출력이 한 글자도 다르지 않다.** `tools/score_all.sh`가 실행할 때마다 이를 확인한다.
   - "칸 기준 조용한 오류"(`--strict`)를 따로 센다. 핵심 칸(표제어·읽기·뜻)이 틀렸는데 **그 칸**에 표시가 없는 경우다. 기준 채점기는 항목에 아무 표시나 있으면 표시된 것으로 센다. 예를 들어 `pos:inferred` 하나만 붙어도 표시된 것으로 친다.

## 2. 점수표

### 2.1 칸별 비교 (단어 59개)

| 칸 | Vision | ML Kit 원래 (Line) | ML Kit 보정 후 (Line) | ML Kit 보정 후 (조각) |
|---|---|---|---|---|
| 찾음 | 59 | 41 | 59 | 59 |
| 표제어 | 57 | 31 | 52 | 52 |
| 읽기 | 59 | 37 | 58 | **59** |
| 품사 | 59 | 21 | 55 | 55 |
| 뜻 | 57 | 36 | 58 | 58 |
| ★ | 56 | 26 | 46 | 46 |
| **줄 전체** | **52** | **11** | **37** | **38** |
| 예문(일), B형 12개 | 12 | 1 | 12 | 12 |
| 예문(한), B형 12개 | 12 | 1 | 12 | 12 |
| DAY·제목·쪽, 5쪽 | 5 | 1 | 2 | 2 |
| 조용한 오류(항목 기준) | 1 | 2 | 1 | 1 |
| 조용한 오류(칸 기준) | 1 | 11 | 2 | 2 |

- ML Kit 원래 점수의 칸별 숫자는 찾은 41개 안에서 센 값이다. 칸 기준 조용한 오류 11은 `scores_rules_off_strict.txt`(규칙을 모두 끈 보정 해석기, 기준과 같은 출력 + 칸 기준 수)에서 나온다.
- 같은 보정 규칙을 Vision 결과에 켜면 52/59, 조용한 오류 1로 그대로다(`scores_mlkit_on_vision.txt`).

### 2.2 쪽별 (ML Kit 보정 후, 조각)

| 쪽 | 형식 | 단어 | 찾음 | 표제어 | 읽기 | 품사 | 뜻 | ★ | 줄 전체 (Vision) | 예문 일·한 | DAY·제목·쪽 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | A | 15 | 15 | 10 | 15 | 12 | 14 | 14 | 8 (12) | - | DAY 숫자를 못 읽음 |
| 13 | A | 16 | 16 | 15 | 16 | 15 | 16 | 10 | 9 (15) | - | 맞음 |
| 69 | A | 16 | 16 | 16 | 16 | 16 | 16 | 10 | 10 (15) | - | 맞음 |
| 157 | B | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 (5) | 6·6 | 제목의 가운데 점(·)이 빠짐 |
| 185 | B | 6 | 6 | 5 | 6 | 6 | 6 | 6 | 5 (5) | 6·6 | 제목 한 글자를 잘못 읽음 |

### 2.3 남은 21줄 (보정 후, 조각)

| 원인 | 줄 | 쪽별 | 화면 표시 |
|---|---|---|---|
| ★를 출력하지 않음 | 13 | 12쪽 1, 13쪽 6, 69쪽 6 | 없음(부가 정보) |
| 획이 아주 적은 한자 표제어를 출력하지 않음 | 5 | 12쪽 4, 13쪽 1 | "표제어 없음" |
| 표제어 한자를 모양이 비슷한 한자로 오인 | 2 | 12쪽 1, 185쪽 1 | **없음(조용한 오류)** |
| 뜻 끝 낱말 누락(뜻이 쉼표로 끝남) | 1 | 12쪽 1 | "뜻 확인 필요" |


## 3. Vision과 다른 점 (`compare.txt`)

### 상위 3개

1. **★를 다루는 방식이 다르다.**
   - 정답에서 ★가 붙은 단어는 30개다.
   - Vision은 그중 26개를 ★ 한 글자짜리 줄로 따로 읽었다.
   - ML Kit는 따로 읽은 경우가 0개다. 17개는 옆 글자에 붙였고(`★かわ`, `乗り換える*のりかえる` 같은 형태), 13개는 출력하지 않았다.
   - ★가 붙으면 읽기 칸이 "가나만 있는 줄"이 아니게 된다. 그러면 원래 해석기가 그 줄을 버린다. **원래 점수에서 단어 18개를 못 찾은 주원인**이다.
   - ★를 `*`로 읽는 경우도 있다(5개).
2. **품사 배지를 자주 출력하지 않는다.** 단어 59개 기준이며, 글자 맞추기로 센 대략값이다.
   - Vision은 배지를 거의 다 읽었다. 뜻과 함께 읽은 것 42개, 따로 한 줄로 읽은 것 10개다.
   - ML Kit는 띄어 읽은 것이 27개다. 나머지는 `동`을 `8`로 읽은 것 5개(5개 모두 `동`), 뜻에 붙여 읽은 것 2개(`명산`, `명3, 셋` 같은 형태)이고, **20개는 출력하지 않았다.**
3. **줄을 묶는 방식이 다르다. ML Kit는 칸을 넘어 합치고, 작은 줄은 놓친다.**
   - 합치는 예: 표제어+★+읽기(`乗り換える*のりかえる` 같은 형태), 읽기+옆 글자(`ひかる で` 같은 형태), 번호+표제어, 예문+앞의 떠돌이 글자(예문 맨 앞에 다른 칸의 글자 하나가 붙음)
   - 번호 줄의 높이는 Vision 0.0073, ML Kit 0.0059다. B형의 작은 번호 줄은 6개 중 3개만 읽었다.
   - 줄 수는 Vision의 0.54~0.98배다. 예: p069 일본어 판독 90줄 → 49줄

### 그 밖의 차이

- **신뢰도:** Vision은 0.3·0.5·1.0 세 값만 낸다. ML Kit는 연속값이고 중앙값이 0.65다. ML Kit 신뢰도는 쓸모가 있다. 한 판독이 다른 언어 줄을 읽은 쓰레기 줄을 거를 수 있다.
  - 한국어 판독이 일본어 줄을 읽은 쓰레기 줄 28개: c 중앙값 0.36
  - 일본어 판독이 한글 번역 줄을 읽은 가짜 일본어 줄: c 0.13~0.23
  - 진짜 예문: c ≥ 0.55
- **상자 좌표:** 같은 글자의 줄 149개(일본어)를 맞대어 보았다. 위치 차이는 거의 없다(x +0.0017, 세로 중심 -0.0006). ML Kit 상자가 조금 더 꽉 맞는다(높이 0.85배, 폭 0.89배). 좌표계는 같게 맞춰졌다.
- **헷갈리는 글자:**
  - 번호의 0 → `O`·`D`. 번호 바로 뒤의 체크박스 → `O`(`1212O` 같은 형태)
  - 쉼표 → 마침표 (`자연. 몸`, `싸다. 포장하다` 같은 형태)
  - 히라가나 → 가타카나·큰 글자 (`のリかえる`처럼 り를 リ로, 작은 っ를 큰 つ로)
  - 한자 오인 (표제어 한자를 모양이 비슷한 한자로 읽음, 2개)
  - 체크박스 가장자리 → `|` (`|揺れる` 같은 형태)
- **체크박스(□□□):** Vision은 `ロロロ`·`■口口`로 읽었다. ML Kit 일본어 판독은 대부분 출력하지 않는다. 잡음은 줄지만, 번호가 빠졌을 때 체크박스로 줄을 찾는 규칙(`research/OCR_TEST.md` 규칙 2)은 쓸 수 없다.
- **후리가나:** 둘 다 읽는다. ML Kit는 후리가나 여러 개를 폭 0.21짜리 긴 줄로 잇기도 한다. 이런 줄은 예문으로 오인될 수 있다.
- **방향:** ML Kit는 옆으로 누운 글자도 읽는다. 이때 `Line.angle`이 -90°로 나온다(6절).

## 4. 보정 규칙 (`parse_eval_mlkit.py`)

- 점수 변화는 전체 규칙에서 **그 규칙 하나만 뺐을 때 줄 전체가 얼마나 떨어지는지**다(`ablation.txt`).
- 순서대로 하나씩 더한 표도 같은 파일에 있다.
- 모든 규칙은 Vision 결과의 점수를 바꾸지 않는다.
- "왜 (근거)" 칸의 글자 예는 합성 세트 단어로 바꾼 같은 형태의 예다. `parse_eval_mlkit.py` 머리말의 규칙 설명과 같다.

| 규칙 | 무엇을 | 왜 (근거) | 줄 전체 변화 Line / 조각 | 다른 칸 |
|---|---|---|---|---|
| `id_ocr` | 번호의 O·o·D → 0, 번호 뒤에 붙은 O 허용 | 번호 숫자를 `O`·`D`로 읽음, 번호 바로 뒤 체크박스를 `O`로 읽음(`1212O`) | -1 / -1 | 표제어 -3, 칸 기준 조용한 오류 +3 |
| `star_split` | ★·`*`를 따로 떼어 ★ 줄로 만듦(글자 수 비례 위치) | 3절 1번(`★かわ`, `乗り換える*のりかえる`) | **-13** / -5 | 찾음 -1, 읽기 -15(Line) |
| `reading_token` | 읽기는 띄어쓰기 앞 첫 토막만 | `ひかる で` → `ひかる` | 0 / 0 | 읽기 -1, 조용한 오류 +1 (Line) |
| `kata_lookalike` | 히라가나 읽기 안의 リ·ヘ·ベ·ペ → 히라가나 | `のリかえる` → `のりかえる` | -1 / -1 | 읽기 -1 |
| `keep_anchored` | A형: 번호를 읽은 줄은 읽기가 없어도 남김(읽기 없음 표시) | ML Kit가 번호는 읽고 읽기(가나 단어의 `–` 포함)를 놓친 줄 | -1 / -1 | 찾음 -1~-2 |
| `row_ids` | A형: 번호를 못 읽은 줄이 이어져도 가장 가까운 읽힌 번호에서 거리만큼 더하고 빼서 채움 | 기준 구현은 맨 위에 빈 번호가 둘 이어지면 같은 번호를 두 번 줄 수 있음 | 0 / 0 | 이 5쪽에는 해당 없음, 잠재 버그 방지 |
| `entry_fallback` | B형: 번호 줄을 못 읽으면 표제어·읽기 줄로 항목을 찾고 번호를 순서로 채움, 위쪽 안내 문구 제외 | B형 번호 6개 중 3개만 읽힘 | -4 / -4 | 찾음 -5, 예문 일 -7·한 -8 |
| `sentence_geom` | B형 예문·번역: 앞에 떠돌이 글자가 붙은 긴 줄 허용, 가나만 있는 줄(후리가나) 제외, 높이 기준을 쪽 중앙값으로 제한 | 앞에 떠돌이 글자가 붙은 예문 줄, 열보다 왼쪽(x 0.292)에서 시작하는 번역 줄, 긴 후리가나 줄 | 0 / 0 | 예문 일 -9·한 -5 |
| `sentence_conf` | B형 예문 줄은 c ≥ 0.4 | 가짜 일본어 줄(c 0.13~0.23) | 0 / 0 | 예문 일 -1 |
| `entry_reading` | B형 읽기: 가나가 있어야 하고, 예문 바로 위(후리가나 자리)는 아님 | `★` 조각이나 예문 위의 후리가나를 읽기로 집음 | -2 / -2 | 읽기 -2 |
| `bar_noise` | 표제어·읽기 앞의 `\|` 제거 | `\|揺れる`, `\| ゆれる` | -2 / -2 | 표제어 -2 |
| `pos_8` | 배지 `8` → 동 | 5개 모두 동(Vision에는 없음) | -4 / -4 | 뜻 -5 |
| `pos_glued` | 붙은 배지 분리. 숫자 앞이면 항상, 한글 앞이면 위아래 3줄의 배지 x 위치와 0.012 안일 때만 | `명3, 셋`, `명산` (뜻이 원래 배지 글자로 시작하면 그대로 둠) | -2 / -2 | 뜻 -3 |
| `pos_infer` | 배지를 못 읽으면 한자+う단 오쿠리가나 → 동, 한자만 → 명. `pos:inferred` 표시 | 배지 미출력 20개 | **-9** / -9 | 품사 -17. 추정 17개 모두 맞음(표본에 명·동만 있음) |
| `low_conf` | c < 0.2 줄 버림(★ 한 글자는 예외) | 다른 언어를 읽은 쓰레기 줄 | 0 / 0 | 예문 한 -2 |
| `meta_day` | DAY 숫자는 DAY 글자 바로 옆의 1~2자리만 | 기준 해석기가 큰 DAY 숫자를 못 읽으면 옆에 있는 단어 번호(`0013` 같은 형태)를 DAY 번호로 씀 | 0 / 0 | 틀린 DAY 번호 대신 "없음" |
| `ko_period` | 한글 사이 `. ` → `, ` (제목·뜻) | `자연. 몸`, `싸다. 포장하다` | 0 / 0 | 뜻 -1, DAY·제목 -1 |
| `meaning_cut` | 쉼표로 끝나는 뜻은 `meaning:suspect` 표시 | 뜻의 마지막 낱말이 빠져 `7,`처럼 쉼표로 끝남 | 0 / 0 | 칸 기준 조용한 오류 +1 |

> `meta_day`는 기준 해석기의 숨은 버그를 고친다. Vision도 큰 DAY 숫자를 못 읽으면 같은 문제가 생긴다. 기준 해석기 원본(`research/ocr/prototype/parse_eval.py`)은 고치지 않았다.

## 5. 결과 단위: Line, Element, 조각

| 단위 | 원래 해석기 | 보정 해석기 | 비고 |
|---|---|---|---|
| Line (`fixtures/`) | 11/59 | 37/59 | 처음 계획한 기본 단위 |
| Element (`fixtures_element/`) | 10/59 | 28/59 | 뜻·꼬리말·번역이 낱말로 쪼개짐. 예문(한) 2/12, 뜻 47 (`scores_mlkit_element.txt`) |
| **조각** (`fixtures_segment/`) | 13/59 | **38/59** | 읽기 59/59. 보정에 기대는 정도가 가장 적음 |

**조각**은 Line을 다음 두 곳에서 자른 것이다. 잘린 조각에는 글자(Symbol) 상자로 정확한 위치를 준다.

- **Element 사이 간격 > 1.1 × 줄 높이:** 5쪽에서 잰 값이다. 꼬리말과 뜻 안의 낱말 간격은 0.98 이하, 표의 칸 사이 간격은 1.22 이상이다.
- **★ 기호 앞뒤**

나머지 값은 다음과 같이 정한다.

- 세로 범위: 원래 줄 상자를 쓴다(해석기의 높이 기준이 줄 상자로 맞춰져 있다).
- 신뢰도: 조각 안 글자 신뢰도의 평균이다.

자를 필요가 없는 줄은 Line과 똑같이 나간다.

## 6. 회전 처리 실험 (`variants/summary.txt`)

같은 사진을 기기에 넣는 방법만 바꿨다. 줄 전체 숫자는 보정 해석기 기준이다.

| 입력 | 방식 | InputImage | 디코드 | 찾음 | 줄 전체 |
|---|---|---|---|---|---|
| 세운 JPEG | `fromBitmap(bmp, 0)` | 3024×4032, 0° | 47ms | 59 | 37 (조각 38) |
| 세운 JPEG | `fromFilePath` | 3024×4032, 0° | 82ms | 59 | 37 (조각 38) |
| 원본, EXIF 6인 3쪽만 | `fromFilePath` | **3024×4032, 0°** (ML Kit가 EXIF를 적용해 픽셀을 돌림) | 293ms | 28/28 | 14 |
| 원본, EXIF 6인 3쪽만 | `fromBitmap(bmp, EXIF 각도)` | 4032×3024, 90° | 44ms | 28/28 | 17 |
| 원본, EXIF 없이 옆으로 찍힌 2쪽 | 모든 방식 | 4032×3024, 0° | - | **0~1/31** | 0 |
| 원본 5쪽 + **각도로 자동 세우기** | `fromBitmap(bmp, EXIF)` | - | 44ms | **59** | 36 |
| 원본 5쪽 + 각도로 자동 세우기 | `fromFilePath` | - | 285ms | 59 | 34 |

- `fromFilePath`는 EXIF 회전을 적용한다. 결과 상자는 세운 좌표로 온다.
- `fromBitmap(bmp, 90)`도 상자를 세운 좌표로 준다. 다만 **`Line.angle`은 원래 비트맵 기준(-90°)**이다.
- EXIF 없이 옆으로 찍힌 사진을 ML Kit는 읽기는 한다. 줄 각도가 -90°이고 상자는 누운 좌표다. 그래서 해석기가 실패한다.
- 그래서 **"첫 판독의 `Line.angle` 중앙값 + 넘긴 회전값"이 ±90°나 180°면, 상자를 그만큼 돌리면 된다.** 다시 판독할 필요는 없다(`raw_to_fixture.py --auto-rotate`). Vision에서는 이 방법이 안 됐다(`research/OCR_TEST.md` 4절). ML Kit에서는 된다.
- 주의할 점이 있다. **같은 쪽도 디코드 경로가 다르면 점수가 ±4줄 흔들린다.** 원본 입력에서는 새 잡음도 나왔다.
  - 번호 숫자가 표제어 뒤에 붙음
  - 괄호(`「`)가 표제어 앞에 붙음
  - 읽기 뒤에 다른 칸의 글자가 붙음
  - 그 결과 칸 기준 조용한 오류가 6~10개로 늘었다(`variants/summary.txt`). 보정 규칙이 세운 입력 5쪽에 맞춰져 있기 때문이다.

## 7. 처리 시간과 메모리 (에뮬레이터, 실제 기기 아님)

| 항목 | 값 |
|---|---|
| 첫 호출(모델 로드 포함) | 일본어 550ms, 한국어 348ms (나중에 다시 돌렸을 때 375·262ms. 실행마다 흔들림) |
| 한 번 판독(이후, 중앙값) | 일본어 182ms, 한국어 192ms |
| 두 판독을 동시에 넣었을 때 | 379ms (순차 합 374ms와 같음. 에뮬레이터가 1코어라 이득 없음) |
| 상주 메모리(RSS) | 시작 109MB → 일본어 모델 뒤 258MB(+149) → 한국어 뒤 320MB(+63), 최대 408MB |
| 참고: Apple Vision (Mac, accurate) | 한 번 판독 430~700ms |

## 8. APK 용량 (R8 축소 release, `assembleRelease -Pprobe.abiSplits=true`)

| 구성 | arm64 APK 안 크기 | 비고 |
|---|---|---|
| 네이티브 `libmlkit_google_ocr_pipeline.so` | 11.06MB | 일본어·한국어가 함께 쓰는 하나. 압축 없이 저장됨, 내려받을 때 압축하면 약 4.4MB |
| 모델: 일본어(Jpan + Hani) | 1.25MB | |
| 모델: 한국어(Kore) | **0.52MB** | 일본어 앱에 한국어를 더하는 비용 |
| 모델: 공용(검출기, 배치, Latn, langid) | 1.27MB | |
| dex(R8 뒤) | 0.51MB | ML Kit·Play 서비스 기본 라이브러리 |
| **arm64 APK 합계** | **15.1MB** | 압축 전송으로 약 8.0MB. universal APK는 45.1MB(ABI 4개) |

- 번들 모델로 동작한 것을 logcat에서 확인했다. 판독 프로세스가 앱의 `base.apk!/lib/arm64-v8a/libmlkit_google_ocr_pipeline.so`를 불러왔고, 모델 내려받기는 없었다.
- 확인할 일: ML Kit가 Google `datatransport` 작업을 예약했다. 사용 통계 전송으로 보인다. 교재 글자가 전송된다는 근거는 없지만, "서버 없음"이라고 안내하려면 확인해야 한다(10절).

## 9. 뼈대 Kotlin 채널에 대한 권고

app/ 코드는 만지지 않았다. 아래는 문서로만 남기는 권고다.

1. **돌려줄 단위는 "조각"이 좋다.** 형식은 지금처럼 `OcrPage`의 `lines[{t,c,x,y,w,h}]`를 유지한다.
   - Line을 그대로 보내면 표제어·★·읽기가 한 줄에 섞인다. 그러면 Dart 쪽에서 글자 수 비례로 추정해 잘라야 한다(`star_split`). 그렇게 하면 칸이 넓게 떨어진 줄에서 위치가 틀린다.
   - Element만 보내면 뜻과 꼬리말이 쪼개진다(28/59).
   - 조각 알고리즘은 `tools/raw_to_fixture.py`의 `runs()`·`segments()`로, 약 40줄이다.
     - Element를 차례로 보다가 앞 Element와의 간격이 `1.1 × 줄 높이`를 넘으면 새 조각을 시작한다.
     - `★ * ☆ ＊` 글자는 단독 조각으로 만든다.
     - 조각의 x 범위는 Symbol 상자의 합집합, y 범위는 Line 상자로 한다. c는 Symbol 신뢰도의 평균이다.
   - 대안: 채널이 Line + Element + Symbol 상자를 모두 넘기고 Dart 어댑터에서 자르는 방법도 있다. Dart 쪽에서 시험하기 쉽지만, 채널로 넘기는 데이터가 쪽당 수십 KB로 늘어난다.
2. **좌표 정규화:** `boundingBox`를 회전 적용 후 크기로 나눈다. `fromBitmap(bmp, 90 또는 270)`이면 너비와 높이를 바꿔서 나눈다. 0~1 값이고 왼쪽 위가 기준이다. 시계 방향 90° 돌리기는 `[l,t,r,b] → [H−b, l, H−t, r]`이다.
3. **신뢰도:** `Line`·`Element`·`Symbol` 모두 `getConfidence()`가 있다. Vision과 달리 연속값이고 쓸모가 있다. 다만 엔진마다 눈금이 다르다. 그래서 문턱값(0.2, 0.4)은 ML Kit 전용 보정기에만 둔다.
4. **회전 처리:**
   - image_picker 파일을 `BitmapFactory`로 디코드하고, `androidx.exifinterface`의 `ExifInterface`로 각도를 읽어 `InputImage.fromBitmap(bmp, 각도)`로 넘긴다. 판독 앱은 플랫폼 `android.media.ExifInterface`를 썼다(API 24 이상의 JPEG면 충분). 앱에서는 OEM 버그를 고친 androidx 판이 안전하다.
   - `fromFilePath`도 EXIF를 적용하지만 디코드가 약 6배 느리다(285ms vs 44ms). 픽셀을 한 번 더 복사하기도 한다. 점수 차이는 흔들림 범위 안이다.
   - EXIF 없는 옆 사진에 대비한다. 일본어 판독 결과의 `Line.angle` 중앙값에 넘긴 각도를 더해서 ±90°나 180°면, 상자를 돌려서 반환한다. 문서 스캐너 블록이 들어와도 보험으로 둘 만하다.
   - 12MP 사진을 ARGB로 디코드하면 48MB다. 처리 뒤 `finally`에서 `recycle()`한다.
   - `Tasks.await`에는 시간 제한을 둔다(판독 앱은 120초). 두 판독을 동시에 넣는다면 `Tasks.whenAllComplete`로 둘 다 끝난 뒤에 비트맵을 놓는다.
5. **두 recognizer의 실행 순서:** **일본어 → 한국어 순서로 차례로 실행**하기를 권한다.
   - 1코어 에뮬레이터에서는 동시 실행 이득이 없었다(379 vs 374ms). 실제 다코어 기기에서의 이득은 재지 않았다.
   - 두 모델을 동시에 올리면 메모리가 약 210MB 늘어난다.
   - 방향 판단에 일본어 결과가 먼저 필요하다.
   - 같은 `InputImage`를 다시 쓴다.
   - recognizer 클라이언트는 한 번 만들어 재사용하고, 화면을 닫을 때 `close()`한다. 첫 호출 550ms는 모델 로드라 처음에만 든다.
6. **의존성과 용량:**
   - `text-recognition-japanese:16.0.1`, `text-recognition-korean:16.0.1`(번들)을 쓴다.
   - 배포는 **App Bundle(ABI 분할)이 필수**다. arm64 기준 약 15MB(전송 약 8MB)이고, 분할하지 않으면 45MB다.
   - R8 축소를 켠 release 빌드는 ML Kit 소비자 규칙만으로 **빌드가 성공했다.** 서명하지 않은 APK라 기기에서 실행해 보지는 않았다. 뼈대의 release 빌드에서 판독이 되는지 한 번 확인해야 한다.
7. **엔진별 보정의 자리:**
   - 기하 정리(조각, 회전)는 채널이나 Android 어댑터에 둔다. Symbol 상자가 필요하기 때문이다.
   - 글자 보정(`id_ocr`, `pos_8`, `ko_period` 등)은 Dart core의 보정기 체인에 둔다. Vision 점수를 바꾸지 않으므로 엔진 공통으로 둬도 된다.
   - `low_conf`, `sentence_conf`처럼 신뢰도 눈금에 기대는 규칙은 엔진 태그(`engine: "mlkit"`)를 보고 켠다.

반환 예 (조각 단위). p069 일본어 판독에서 Line `표제어 ★읽기` 하나가 조각 3개가 된 모습이다. 좌표·신뢰도·`ms`는 실제 값이고, 글자만 합성 세트 단어로 바꿨다.

```json
{"engine":"mlkit","langs":["ja"],"ms":167,"lines":[
  {"t":"痛い","c":0.4961,"x":0.2126,"y":0.3517,"w":0.0648,"h":0.0263},
  {"t":"★","c":0.2852,"x":0.3337,"y":0.3517,"w":0.0728,"h":0.0263},
  {"t":"いたい","c":0.7344,"x":0.4054,"y":0.3517,"w":0.0688,"h":0.0263}]}
```

## 10. 남은 문제

1. **★ 13/30 미출력:** 판독 결과만으로는 되살릴 수 없다.
   - A형 3쪽의 표제어·★ 칸만 잘라(가로 0.15~0.55) 다시 판독하면 ★가 들어간 줄이 12에서 16으로 늘었다(`compare.txt`의 crop test, `raw/crop-bitmap`). A형 3쪽의 ★ 단어는 25개다. 일부는 되살아나지만 판독을 한 번 더 해야 하고, 좌표를 되돌려 채점까지 해 보지는 않았다.
   - 다음 실험 후보는 "★ 칸 픽셀 검사" 블록이다. 번호 x + 0.19 위치의 작은 영역이 ★ 모양으로 어두운지 본다.
   - 앱에 적용됨, verification 6.7 (붉은 픽셀 비율, Android 채널 `measureStars`).
2. **획이 아주 적은 한자 표제어(一·十 등):** ML Kit는 하나도 출력하지 않는다. Vision은 一·十을 비슷한 글자(`ー`, `+`)로 읽어 보정기가 되살렸다. 잘라서 키워도 같다. "표제어 없음"으로 표시되고, JMdict 블록이 들어오면 읽기로 후보를 보여 줄 수 있다.
3. **조용한 오류:** 표제어 한자를 모양이 비슷한 한자로 읽은 2개다. 사전 블록에서 "표제어–읽기 조합이 사전에 있는가"를 검사하면 잡을 수 있다(잘못 읽은 한자와 원래 읽기를 합친 조합은 사전에 없다).
4. **규칙이 5쪽에 맞춰져 있다:** 디코드 경로만 바꿔도 새 잡음이 나오고 칸 기준 조용한 오류가 6~10개로 는다(6절). 사진을 더 모아(다른 DAY, 그림자, 굽은 쪽) 다시 재야 한다. `pos_infer`는 명·동만 있는 표본에서 맞았을 뿐이다. 형용사·부사 쪽에서 확인이 필요하다.
5. **DAY 제목:** 157쪽은 제목의 가운데 점(·)이 빠지고, 185쪽은 제목 한 글자를 잘못 읽는다. 12쪽은 큰 DAY 숫자를 못 읽는다. 같은 DAY의 다른 쪽과 맞춰 보는 보정(앱 단계)이 필요하다.
6. **검토 부담:** 맞았는데 표시된 항목이 17개다(Vision 3개). 대부분 `pos:inferred`다. 검토 화면에서는 추정 품사를 "확인 필요"가 아니라 가벼운 "추정" 표시로 다루는 편이 좋다.
7. **측정 한계:** 에뮬레이터 1코어라 실제 기기의 시간과 병렬 이득은 재지 않았다.
8. **ML Kit 사용 통계 전송:** 앱이 `com.google.android.datatransport` 작업을 예약했다. 무엇을 보내는지, 끌 수 있는지 문서로 확인해야 한다.
9. **계획과 다른 점:**
    - AVD 이름은 `Medium_Phone`이 아니라 `Medium_Phone_API_36.1`이다. 같은 `Medium_Phone.avd` 폴더이고, 이 이름으로 띄웠다.
    - JDK 25에서 AGP 9.5.0 + Gradle 9.8.2가 그대로 동작해, JDK를 따로 설치하지 않았다.

## 11. 다시 실행하기

데이터 폴더는 `$SHIORI_PRIVATE_DIR/textbook/ocr-android/`(`SHIORI_PRIVATE_DIR` 기본값 `<repo>/.private`)다. 교재 사진과 판독 결과는 저장소에 없으므로, 이 폴더가 없으면 아래 단계는 돌지 않는다(`score_all.sh`는 `textbook data not found`로 멈춘다).

```bash
cd research/ocr-android
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}   # run_probe.sh와 같은 기본값

# 0) 사진 → 세운 JPEG (데이터 폴더의 work/images/upright, work/images/orig)
#    사진과 pages.json은 $SHIORI_PRIVATE_DIR/textbook/photos/에서 읽음. 다른 곳에 있으면 --photos DIR
python3 tools/prepare_images.py

# 1) 에뮬레이터 (창 없이). AVD를 지우거나 초기화하지 않는다
"$SDK/emulator/emulator" -avd Medium_Phone_API_36.1 -no-window -no-audio -no-snapshot-save &
"$SDK/platform-tools/adb" wait-for-device

# 2) 판독 앱 빌드·설치·판독 → 데이터 폴더의 raw/<입력>-<방식>/   (첫 빌드 때 Gradle 9.8.2와 의존성을 내려받음)
tools/run_probe.sh upright bitmap parallel       # 주 측정
tools/run_probe.sh upright filepath              # 회전 처리 비교
tools/run_probe.sh orig filepath
tools/run_probe.sh orig bitmap-exif

# 3) 단위 테스트 + fixture 변환과 모든 채점. 인자는 없다.
#    기준 해석기는 research/ocr/prototype/parse_eval.py, Vision fixture와 정답은 $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/에서 읽고
#    fixture·variants·점수 파일은 모두 데이터 폴더에 쓴다
tools/score_all.sh
(cd tools && python3 -m unittest test_tools)           # 도구 단위 테스트만 (16개, 데이터 폴더 없이 돈다)
(cd mlkit_probe && ./gradlew :app:testDebugUnitTest)   # 판독 앱 JVM 테스트

# 4) 끝나면 에뮬레이터 끄기
"$SDK/platform-tools/adb" emu kill

# APK 용량 (R8 축소, ABI별)
(cd mlkit_probe && ./gradlew :app:assembleRelease -Pprobe.abiSplits=true)
```

- 2026-11-05에 비공개 데이터로 `score_all.sh`를 다시 돌려, 모든 점수 파일이 바이트 단위로 같게 나오는 것을 확인했다.

## 12. 파일

저장소 안 (`research/ocr-android/`):

| 경로 | 내용 |
|---|---|
| `mlkit_probe/` | 판독 앱(Kotlin, AGP 9.5.0, Gradle 9.8.2 wrapper). 빌드 산출물은 `.gitignore`로 제외 |
| `mlkit_probe/app/src/test/` | 판독 앱 인자 해석·JSON 숫자 처리 JVM 테스트(5개, `./gradlew :app:testDebugUnitTest`) |
| `parse_eval_mlkit.py` | 보정 해석기(규칙 18개, `--off`, `--ablation`, `--strict`). 기본 입력은 데이터 폴더의 `fixtures/`와 `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/ground_truth.json` (`--fixtures DIR`, `--gt FILE`로 바꿈) |
| `tools/prepare_images.py` | 사진 → 세운 JPEG(`work/images/upright`), 원본 복사(`work/images/orig`). 사진과 `pages.json`은 `$SHIORI_PRIVATE_DIR/textbook/photos/` 또는 `--photos DIR` |
| `tools/run_probe.sh` | 빌드 → 설치 → 넣기 → 판독 → 빼기(`raw/<입력>-<방식>/`) |
| `tools/raw_to_fixture.py` | 원본 덤프 → fixture(`line`/`element`/`segment`, `--auto-rotate`) |
| `tools/score_all.sh` | 인자 없음. 단위 테스트, 변환과 모든 채점, 규칙을 끈 출력이 기준과 같은지 확인. 결과는 데이터 폴더에 씀 |
| `tools/test_tools.py` | 변환기(조각·회전·None 상자)와 보정 규칙 함수의 단위 테스트(16개) |
| `tools/compare_engines.py` | Vision 대비 줄 수·신뢰도·좌표·★·배지 집계 → `compare.txt` |
| `.gitignore` | 사진·세운 이미지(`work/`, `*.jpg` 등)와 빌드 산출물 제외 |

비공개 데이터 폴더 (`$SHIORI_PRIVATE_DIR/textbook/ocr-android/`, 저장소에 없음):

| 경로 | 내용 |
|---|---|
| `work/images/` | 세운 JPEG(`upright/`)와 원본 복사(`orig/`) |
| `raw/` | ML Kit 원본 덤프(블록 > 줄 > 요소 > 글자)와 `timing.json` |
| `fixtures/` | **Line 단위 fixture**(처음 계획한 결과물) `p012 p013 p069 p157 p185 .{ja,ko}.json` |
| `fixtures_element/`, `fixtures_segment/` | Element 단위, 조각 단위 |
| `variants/` | 회전 처리 실험 fixture와 점수, `summary.txt` |
| `scores.txt` | **원래 점수**(기준 해석기, Line) |
| `scores_element.txt`, `scores_segment.txt` | 기준 해석기, Element·조각 |
| `scores_mlkit.txt`, `scores_mlkit_segment.txt` | **보정 후 점수**(Line·조각) |
| `scores_mlkit_element.txt` | 보정 해석기, Element |
| `scores_rules_off_strict.txt` | 규칙을 모두 끈 출력(=기준)에 칸 기준 조용한 오류 수를 더한 것 |
| `scores_mlkit_on_vision.txt` | 보정 규칙을 Vision 결과에 켠 점수(변화 없음 확인) |
| `ablation.txt` | 규칙별 기여(하나 빼기, 하나씩 더하기) |
| `compare.txt` | 엔진 차이 집계, 잘라 읽기 실험 |

> 판독 결과와 점수 파일에는 교재 본문이 들어 있어 저장소에 넣지 않는다. Apple Vision fixture와 정답도 비공개 폴더 `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/`에 있다.
