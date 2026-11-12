# 검증 기록 (앱 뼈대)

- 날짜: 2026-11-05 (KST), MacBook arm64 · macOS 26.3.1
- 도구: Flutter 3.41.5 · Dart 3.11.3, Xcode 26.6, CocoaPods 1.16.2, Android SDK 36.1 (JBR 21)
- 시뮬레이터: iPhone 17 Pro, iOS 26.5. 실제 iPhone은 쓰지 않았습니다.

## 0. 테스트 데이터

- **합성 세트 (저장소):** `packages/core/test/fixtures/synthetic/`, 앱 샘플은 같은 파일의 사본 `app/assets/dev_samples/`.
  지어낸 단어 35개를 단어장 쪽(한 줄에 한 단어 `s010`·`s011`, 예문이 있는 항목 `s140`·`s147`)에 놓은 4쪽의 두 번 판독 기록과 정답(20절부터 범용 형식 `general-1`)입니다.
  (19절까지는 가로줄 틀의 정답과 Python 기준 구현 출력도 있었습니다.)
  해석·보정 규칙이 다루는 OCR 실수를 일부러 넣었습니다(체크박스 잡음, ★ 기호 잡음, 기울기, 옆 페이지 번호, 읽기 없음 `-`·`–`·`一`,
  한자 사이 가타카나, 품사 배지 오인식, 후리가나, 관련어·문형 상자, DAY 오인식 등). 만드는 법: `python3 tools/synthetic/make_pages.py`
  (`--check`는 저장소의 파일이 생성기 출력과 같은지 확인).
- **교재 세트 (로컬 전용):** 측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했습니다.
  `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/`(기본 `<저장소>/.private`)에 있을 때만 해당 테스트가 돌고, 없으면 이유를 적고 건너뜁니다.

## 1. 완료 조건

| 항목 | 명령 | 결과 |
|---|---|---|
| core 정적 분석 | `cd packages/core && dart analyze` | 문제 없음 |
| core 테스트 | `cd packages/core && dart test` | **361개 통과** (21절 반영 뒤. 20절 뒤 337개) |
| core 테스트 (교재 세트 포함) | `SHIORI_PRIVATE_DIR=<로컬 폴더> dart test` | **361개 통과** (21절 뒤. 교재 세트 테스트는 jmdict_block의 로컬 테스트로 옮겨져 core에는 남지 않음) |
| core 커버리지 | `dart run coverage:test_with_coverage -o coverage` | 줄 커버리지 **93.2%** (3665/3932줄, 21절 뒤) |
| 사전 패키지 | `cd packages/dict_jmdict && dart analyze && dart test` | 문제 없음, **11개 통과** (20절: 짝 확인·후보 질의를 걷어내 `lookupForms`·열기만) |
| 사전 블록 (어댑터) | `cd packages/jmdict_block && dart analyze && dart test` | 문제 없음, **6개 통과**, 로컬 세트 9개 건너뜀 (지정 시 15개 통과, 20절) |
| 사전 asset 스크립트 | `python3 -m unittest discover -s tools/dict -p 'test_*.py'` | **82개 통과** (네트워크 없음, 25절 뒤) |
| 한국어 뜻 사전 블록 | `cd packages/krdict_block && dart analyze && dart test` | 문제 없음, **80개 통과** (지어낸 견본 30항목, 14절. 역조회 6개, 18절) |
| 저장 패키지 | `cd packages/storage_drift && dart analyze && dart test` | 문제 없음, **154개 통과** (21절: 스키마 v4, 재생목록·설정 계약, v1~v3 비우기) |
| app 정적 분석 | `cd app && flutter analyze` | 문제 없음 |
| app 테스트 | `cd app && flutter test` (기본 flavor = dev), `flutter test --flavor dev` | **170개 통과** (21절 반영 뒤. 20절 뒤 132개) |
| iOS 채널 순수 로직 | `cd app/ios && xcodebuild test -workspace Runner.xcworkspace -scheme dev -destination 'id=<시뮬레이터>' -only-testing:RunnerTests` (11절부터 스킴 `dev`) | **5개 통과** (회전 투표·가로세로 바꿈·방향 합성, 6.4절) |
| Android 채널 순수 로직 | `cd app/android && ./gradlew :app:testDevDebugUnitTest` (JDK 21, 11절부터 flavor 이름이 붙음) | **11개 통과** (조각 자르기·회전·상자 없는 글자, 6.5절) |
| app 커버리지 | `flutter test --coverage` | 줄 커버리지 **91.4%** (2785/3048줄, 21절 반영 뒤. 20절 뒤 90.8%) |
| iOS 흐름 | `flutter drive ... integration_test/playlists_screenshots_test.dart` | 통과, 스크린샷 54~66 (21절, iPhone 17 시뮬레이터 디버그 빌드) |
| Android 빌드 | `flutter build apk --debug` (= dev flavor, `app-dev-debug.apk`) | 성공 (Kotlin ML Kit 채널 컴파일, 디버그 APK 약 186MB = 177MiB, 빌드 환경에 따라 조금 다름) |
| 합성 세트 점수표 | `cd packages/core && dart run tool/eval_extract.dart --fixtures test/fixtures/synthetic` (메모리 사전) · `cd packages/jmdict_block && dart run tool/eval_extract_dict.dart --db … --glossary … --fixtures ../core/test/fixtures/synthetic` | 실제 사전 33/35·뜻 32/33·여분 2 (20절. 가로줄 틀 점수표 `eval_capture`·기준 구현 대조는 걷어냄) |
| 합성 세트 점수표 (ML Kit형) | 위와 같은 도구 `--fixtures …/synthetic_mlkit` | 실제 사전 17/18·16/17·여분 1 (20절) |
| 합성 생성기 | `python3 tools/synthetic/make_pages.py --check` | 저장소 파일과 같음 (20절부터 정답은 범용 형식, 기준 구현 출력 없음) |
| 범용 추출 합성 생성기 | `python3 tools/synthetic/make_general_pages.py --check` | 저장소 파일과 같음 (13절) |
| 범용 추출 데이터 표 | `python3 tools/extract/build_extract_data.py --check` (Unihan zip: 캐시 또는 내려받기, sha256 고정) | 생성 파일과 같음 (13절) |
| 범용 추출 점수표 (메모리 사전) | `cd packages/core && dart run tool/eval_extract.dart` | 합성 범용 g01~g11 (`--template`·`--routed`는 20절에서 걷어냄) |
| 범용 추출 점수표 (JMdict) | `cd packages/jmdict_block && dart run tool/eval_extract_dict.dart --db <JMdict SQLite> [--glossary <한국어 뜻 사전 SQLite>]` | 13절·20절 비교표 |
| 로컬 세트 (실제 사전) | `cd packages/jmdict_block && SHIORI_PRIVATE_DIR=<로컬 폴더> dart test` (사전: `SHIORI_JMDICT_DB`·`SHIORI_KO_GLOSSARY_DB`, 없으면 앱 asset을 풀어 씀) | 15개 통과 (20절. 경로 선택 로컬 테스트는 걷어냄) |
| 높음 수·높음인데 틀림 (17·20절) | `cd packages/core && dart test test/extract/high_confidence_counts_test.dart`, 로컬: `cd packages/jmdict_block && SHIORI_PRIVATE_DIR=<로컬 폴더> dart test test/high_confidence_local_test.dart` | 합성 범용 33·단어장 25·ML Kit형 13, 교재 Vision 20·ML Kit 37·휜 쪽 6·다른 교재 8, 높음인데 틀림 전 세트 0 (하한은 20절) |
| 배포 빌드 (prod) | `flutter build apk --flavor prod --release`, `flutter build appbundle --flavor prod --release`, `flutter build ios --flavor prod --release --no-codesign` | 사전 asset과 서명 키(Android)가 있으면 **성공**, 결과물에 `dev_samples` 없음. 사전 asset이나 `key.properties`가 없으면 **분명한 메시지로 실패** (11절). 사전이 판 정보와 어긋나거나 JMdict가 35일보다 오래돼도 실패 (25절) |
| 배포 빌드 차단 (dev) | `flutter build apk --flavor dev --release`, `flutter build ios --flavor dev --release --no-codesign` (`--flavor` 없는 release도 dev) | **의도대로 실패**: dev flavor는 개발 샘플을 묶으므로 release로 빌드하지 않음 (11절) |
| 연구 도구 테스트 | `python3 -m unittest test_tools` (`research/scan/tools`, `research/ocr-android/tools`) | 27개, 16개 통과 |
| ML Kit 판독 앱 | `cd research/ocr-android/mlkit_probe && ./gradlew :app:testDebugUnitTest` | 5개 통과 |

## 2. 캡처 회귀 점수표

> **2026-11-06 걷어냄(20절).** 아래 2~12절의 가로줄 틀 점수표·기준 구현 대조는 그때의 기록입니다. 지금 회귀 기준은 단어 추출기 점수표(20절)입니다.

`dart run tool/eval_capture.dart`의 출력을 `python3 tools/reference/parse_eval.py --data <같은 폴더>`(동결한 기준 구현)와 칸 단위로 비교합니다.
**채점 칸은 표제어·읽기·품사·뜻(줄 전체 = 이 넷)과 예문입니다.** 2026-11에 ★ 칸을 걷어냈습니다(10절). 그 전 점수는 ★ 칸까지 맞아야 줄 전체로 셌고,
6절의 점수는 그 **★ 포함 옛 기준**입니다.
Dart 해석기는 6절에서 기준 구현보다 앞으로 나갔으므로, **기준 출력과 다른 칸은 모두 같은 폴더의 `intended_differences.json`에 이유와 함께 적혀 있어야 합니다.**
적히지 않은 차이도, 적혔지만 더는 생기지 않는 차이도 테스트가 실패시킵니다(`reference_parity_test.dart`). 지금 차이를 보려면
`dart run tool/reference_diff.dart [--fixtures <폴더>]`(목록 파일과 같은 모양의 JSON)를 씁니다.

| 세트 | 기준 출력과 다른 칸 | 목록 파일 |
|---|---|---|
| 합성 세트 (35단어) | **0개** | 없음 (차이가 생기면 `packages/core/test/fixtures/synthetic/intended_differences.json`) |
| 교재 세트 (59단어, 로컬) | **0개** | 없음 (차이가 생기면 `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/intended_differences.json`, 교재 글자가 들어가므로 로컬 전용) |

6절의 규칙(내용 기준 칸 위치, 약점 수정, ML Kit 규칙 18개)은 두 세트의 칸을 하나도 바꾸지 않았습니다. 바뀌는 것은 다른 이미지 틀(페이지만 자른 좌표)과
ML Kit 판독 결과뿐이고, 그 효과는 6절 점수표로 확인합니다.

### 2.1 합성 세트 (4쪽 35단어)

```
page tpl    n found head read  pos mean  row exJA exKO meta
  10 list  12    12   10   12   12   11    9    -    - ok
  11 list  12    12   12   12   12   11   11    -    - ok
 140 entry  6     6    6    6    6    6    6    6    6 ok
 147 entry  5     5    5    5    5    5    5    4    4 ok

TOTAL  headword=33/35  readings=35/35  pos=35/35  meaning=33/35  ex_ja=10/11  ex_ko=10/11  row=31/35  found=35/35
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 4
```

틀린 칸은 모두 일부러 넣은 것입니다: 읽지 못한 표제어 2개(`日`, `空`, "표제어 없음"으로 표시), 잘못 읽은 뜻 1개(`구름`→`구룸`, 조용한 오류),
읽지 못한 뜻 1개("뜻 없음"으로 표시), 읽지 못한 예문 1개. (★ 포함 옛 기준은 읽지 못한 ★ 1개까지 더해 30/35였습니다.) 자동 보정 4개(`ロ`→`口`, `タ日`→`夕日`, `光ル`→`光る`, `カ`→`力`)는 정답과 같아졌습니다.

- 회귀 테스트: `packages/core/test/capture/regression_test.dart` (합성 세트는 위 값을 정확히 단언)
- 경우별 테스트: `packages/core/test/capture/synthetic_pages_test.dart` (넣어 둔 OCR 실수마다 하나씩)

### 2.2 교재 세트 (로컬 전용, 5쪽 59단어)

```
page tpl    n found head read  pos mean  row exJA exKO meta
  12 list  15    15   13   15   15   14   12    -    - ok
  13 list  16    16   16   16   16   16   16    -    - ok
  69 list  16    16   16   16   16   15   15    -    - ok
 157 entry  6     6    6    6    6    6    6    6    6 ok
 185 entry  6     6    6    6    6    6    6    6    6 ok

TOTAL  headword=57/59  readings=59/59  pos=59/59  meaning=57/59  ex_ja=12/12  ex_ko=12/12  row=55/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 3
```

| 목표 | 결과 |
|---|---|
| 찾음 59/59 | 59/59 |
| 줄 전체 ≥ 55/59 (★ 포함 옛 기준 ≥ 52) | 55/59 |
| 예문 일·한 12/12 | 12/12 · 12/12 |
| 표시 없이 틀린 핵심 칸 ≤ 1 | 1 (한국어 OCR이 뜻 한 글자를 잘못 읽음) |

- 회귀 테스트와 기준 출력 대조는 같은 두 파일의 "recorded textbook pages (local only)" 그룹입니다.
- 기준 출력 대조: `packages/core/test/capture/reference_parity_test.dart`는 Python 기준 구현의 출력
  (`tools/reference/dump_reference.py --data <폴더>` → `reference_output.json`)과 **모든 항목의 모든 칸과 표시 코드**, 형식, DAY·제목·쪽을 하나씩 비교하고,
  다른 칸을 의도한 차이 목록과 맞춥니다(위). 합성 세트(35개)는 항상, 교재 세트(59개)는 로컬 자료가 있을 때 비교합니다.
- 이식에서 맞춘 Python 동작: 안정 정렬, 첫 최솟값, `round(x, 2)`의 짝수 반올림, `difflib.SequenceMatcher`(autojunk 포함),
  NFKC, 유니코드 `\b`·`\d`, 코드 포인트 단위 문자열 처리.
- 기준 구현과 일부러 다르게 한 곳 (두 세트의 결과에는 영향 없음, 대조 테스트로 확인. 합성 세트도 이 경우는 피해서 만들었습니다):
  1. 꼬리말 DAY 오인식 표 `ㅇ1`은 NFKC 뒤에는 `ᄋ1`이 되어 기준 구현에서 절대 맞지 않았습니다. `ᄋ1`도 넣었습니다.
  2. 맨 앞 행들의 번호가 빠졌을 때 기준 구현은 번호를 겹치게(또는 `0000`을) 만들었습니다. 다음 번호에서 거리만큼 빼서 채우고 1 미만은 비워 둡니다.
  3. 기준 구현은 이상한 숫자 문자에서 예외로 멈췄습니다. 이제는 값을 비우고 일본어 판독의 DAY로 대체합니다.

## 3. iOS 시뮬레이터 흐름 (합성 샘플 페이지)

`cd app && flutter drive -d <시뮬레이터> --driver=test_driver/integration_test.dart --target=integration_test/flow_screenshots_test.dart`

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `01_home_empty.png` | 홈, 교재 없음 |
| `02_capture.png` | 등록: 카메라·앨범, 개발용 샘플 4쪽 |
| `03_review_examples.png` | 검토: 140쪽(항목형), 예문·번역 |
| `04_home_after_save.png` | 저장 뒤 홈: 새 단어 6 |
| `05_study_card_covered.png` | 학습 카드: 표제어와 예문(형광펜), 뜻·읽기·번역 가림, `알고있음 21일 후` |
| `06_study_card_revealed.png` | 뜻·읽기 펼침 |
| `07_study_retried_card.png` | 다시 학습한 카드가 맨 뒤에서 다시: `다시 1`, `3일 후`, 진행도 5/6 |
| `08_session_done.png` | 세션 끝: 소요 시간, 새로 외운 6, 다시 학습 1번 |
| `09_home_after_study.png` | 홈: 오늘 6개 외움 |
| `10_review_flags.png` | 검토: 10쪽(목록형), 확인 필요 2(표제어 없음), 자동 보정 1(`ロ → 口`) |
| `11_entry_editor.png` | 수정 시트 |
| `12_review_fixed.png` | 두 칸을 고친 뒤 |
| `13_home_two_pages.png` | 홈: 새 단어 12, 단어 18개 |
| `14_textbook_days.png` | 교재 › DAY 01 › 단어 |
| `15_textbook_memory_levels.png` | DAY 20: 기억 단계 막대 (다시 학습한 1211은 2단계, 나머지 4단계) |

2026-11-05에 합성 샘플로 다시 찍었습니다(15장, 통과). 화면 기록 중 찾아 고친 문제 두 가지:
1. 저장 알림(스낵바)이 학습 화면까지 따라와 답 버튼을 가림 → 화면을 옮길 때 알림을 걷음(`shared/navigation.dart`), 위젯 테스트 추가
2. 키보드가 수정 시트의 `고치기` 버튼을 가림 → 버튼을 시트 머리 줄로 옮김

## 4. 실제 OCR 채널 확인 (추가, 시뮬레이터, 교재 세트)

녹화 데이터가 아니라 **앱의 Swift Vision 채널**로 교재 원본 사진 5장을 읽고 같은 채점기로 채점했습니다.
사진과 정답은 저장소 밖 로컬 전용 폴더에 둡니다. **원본 사진을 그대로 넘깁니다**: EXIF 회전값이 있는 3장(69·157·185쪽)은 채널의 EXIF 처리로,
EXIF 없이 옆으로 찍힌 2장(12·13쪽)은 채널의 회전 판별(첫 일본어 판독의 글 방향 투표, 6.4절)로 세웁니다.

```
cd app && flutter test integration_test/vision_channel_probe_test.dart -d <시뮬레이터> \
  --dart-define=SHIORI_PROBE_PHOTOS=<쪽 이름.jpg 사진 폴더> --dart-define=SHIORI_PROBE_TRUTH=<ground_truth.json>
# 틀린 단어 목록(교재 본문이 찍힘)이 필요하면 --dart-define=SHIORI_PROBE_VERBOSE=true
# 채널 출력을 판독 기록 형식으로 저장: --dart-define=SHIORI_PROBE_DUMP=<폴더>
```

2026-11-05, iPhone 17 Pro 시뮬레이터(iOS 26.5), **10절(★ 걷어냄) 반영 뒤**. 쪽마다 적용한 회전과 판독 시간을 찍습니다(교재 글자 없음).

```
engine=apple-vision   (★ 보조 판독 없음. 시작할 때 Mac 부하 평균 약 6)
p012: turned 90°, ja 116 lines 1458 ms, ko 76 lines 1442 ms, extra {orient_pass: 1926}, total 4857 ms
p013: turned 90°, ja 87 lines 1315 ms, ko 65 lines 1254 ms, extra {orient_pass: 1252}, total 3831 ms
p069: turned 0°, ja 90 lines 1390 ms, ko 78 lines 1342 ms, extra {}, total 2736 ms
p157: turned 0°, ja 67 lines 1702 ms, ko 65 lines 1539 ms, extra {}, total 3250 ms
p185: turned 0°, ja 61 lines 1551 ms, ko 47 lines 1433 ms, extra {}, total 2988 ms
TOTAL  headword=56/59  readings=59/59  pos=59/59  meaning=57/59  ex_ja=12/12  ex_ko=12/12  row=54/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 4;  flagged but actually correct: 3
```

★ 보조 판독을 걷어내기 전(6절 반영 뒤, ★ 포함 옛 기준) 같은 사진, 비슷한 Mac 부하(평균 약 6)에서 잰 값:

```
engine=apple-vision   (★ 보조 판독 켬, 그때 앱 기본값. 오류 처리 보강 뒤 다시 잼, Mac 부하 평균 약 6)
p012: turned 90°, ja 116 lines 1507 ms, ko 76 lines 1366 ms, star 1412 ms, extra {orient_pass: 1802, star_binarize: 550}, total 6678 ms
p013: turned 90°, ja 87 lines 1324 ms, ko 65 lines 1242 ms, star 1215 ms, extra {orient_pass: 1269, star_binarize: 401}, total 5455 ms
p069: turned 0°, ja 90 lines 1487 ms, ko 78 lines 1390 ms, star 1318 ms, extra {star_binarize: 419}, total 4620 ms
p157: turned 0°, ja 67 lines 1734 ms, ko 65 lines 1615 ms, star 1622 ms, extra {star_binarize: 403}, total 5378 ms
p185: turned 0°, ja 61 lines 1582 ms, ko 47 lines 1441 ms, star 1494 ms, extra {star_binarize: 364}, total 4890 ms
TOTAL  headword=56/59  readings=59/59  pos=59/59  meaning=57/59  important=59/59  ex_ja=12/12  ex_ko=12/12  row=54/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 4;  flagged but actually correct: 3
```

| 채널 구성 | 줄 전체 | ★ | 조용한 오류 | 한 장 시간 (이 측정) |
|---|---|---|---|---|
| main (12·13쪽은 미리 돌림, 기준) | 49/59 | 55/59 | 2 | 2.6~3.4초 |
| 6절, ★ 보조 판독 끔 (12·13쪽 돌리지 않음) | 51/59 | 55/59 | 1 | 2.7~4.5초 |
| 6절, ★ 보조 판독 켬 (그때 앱 기본값) | 54/59 | 59/59 | 1 | 4.6~6.7초 |
| **10절, ★ 걷어냄 (지금, ★ 칸 없는 기준)** | **54/59** | — | **1** | **2.7~4.9초** |

- 위 세 줄은 ★ 포함 옛 기준입니다. ★ 보조 판독을 걷어낸 뒤 쪽당 시간은 쪽마다 1.6~2.1초 줄었습니다
  (12쪽 6.7→4.9, 13쪽 5.5→3.8, 69쪽 4.6→2.7, 157쪽 5.4→3.3, 185쪽 4.9→3.0초). 줄어든 몫은 이진화(0.36~0.55초)와 일본어 판독 한 번(1.2~1.6초)입니다.

- 회전: 12·13쪽은 첫 일본어 판독의 글 방향 투표로 시계 방향 90°를 판별했습니다. 바른 사진(69·157·185쪽)은 판독을 한 번 더 하지 않습니다.
  옆 사진만 일본어 판독이 한 번 더 듭니다(이 측정에서 1.3~1.8초).
- ★ 보조 판독(걷어냄, 10절): 이진화 0.36~0.55초 + 일본어 판독 한 번(1.2~1.6초). ★ 4개를 되찾았고 다른 칸은 바뀌지 않았습니다.
- **시간은 Mac 부하에 따라 크게 흔들립니다.** 같은 탐침을 부하 평균 약 45일 때 돌리면 한 장 6.1~10.5초(판독 한 번 1.7~2.5초)였습니다.
  ★ 보조 판독을 끈 표의 줄은 그 부하 높은 때 잰 값입니다. 실제 iPhone 측정이 필요합니다(Mac 연구 기록: 판독 한 번 0.4~0.7초, 이진화 18~84ms).
- Mac에서 녹화한 판독(교재 세트, 52/59)과 시뮬레이터 판독은 조금 다릅니다(같은 Vision API라도 iOS 26.5 시뮬레이터와 macOS 26.3의 결과가 다름).
  그래서 회귀 기준은 Mac 녹화 데이터로 두고, 다음 단계에서 **실제 iPhone으로 같은 쪽을 녹화한 고정 데이터**를 로컬 전용 회귀 세트에 더해야 합니다.
  실제 iPhone 측정은 아직 하지 않았습니다.

## 5. 하지 않은 것

- 실제 iPhone·Android 기기 실행 (Android 기기 없음). Android ML Kit 판독 정확도는 `research/ocr-android/README.md`(에뮬레이터)와 6.5절(앱 채널, 에뮬레이터).
- Android 에뮬레이터에서 앱 화면 흐름, 접근성 자동 점검, 다크 모드 스크린샷 (다크 토큰은 있고 위젯 테스트로 적용만 확인). OCR 채널만 에뮬레이터에서 확인했습니다(6.5절).
- 빌드를 위해 Android SDK 라이선스 동의(`sdkmanager --licenses`)를 했습니다. Gradle이 CMake 3.22.1을 내려받았습니다.

## 6. 캡처 개선: 내용 기준 칸 위치, 회전, ★ 보조 판독, ML Kit 조각과 보정 규칙

- 날짜: 2026-11-05. iOS는 iPhone 17 시뮬레이터(iOS 26.5), Android는 에뮬레이터 `Medium_Phone_API_36.1`. 실제 기기는 쓰지 않았습니다.
- 교재 세트의 점수는 합계 줄만 적습니다(쪽별 줄에는 교재 제목이 찍힐 수 있음).
- **이 절의 점수는 ★ 포함 옛 기준입니다**(줄 전체에 ★ 칸이 들어감). ★ 보조 판독(③)과 Android ★ 칸 픽셀 검사(6.7절)는
  2026-11에 걷어냈습니다(10절, 학습에 필요 없음). 지금 기준 점수는 2절과 6.3절입니다.

### 6.1 바꾼 것

| 단계 | 자리 | 내용 |
|---|---|---|
| ① 해석기 | `capture/vocab/column_scale.dart`, 두 템플릿 | 칸 위치 상수(`ax + 0.17` 등)를 **쪽마다 잰 배율**에 곱합니다. 배율 = (번호 칸 → 읽기 칸 거리의 최빈 칸) ÷ (상수를 정한 사진의 거리: 목록형 0.23, 항목형 0.183). 읽기 칸이 없으면 품사 배지 칸으로, 둘 다 없거나 0.6~1.8 밖이면 1.0. 사진·페이지만 자른 이미지·가깝게 찍은 사진을 같은 규칙으로 읽습니다 |
| ① 약점 1 | `vocab/anchors.dart` | 번호가 3개 미만이고 체크박스 글자가 붙지 않은 번호 열은 페이지(옆 페이지)로 인정하지 않습니다(가장 큰 열은 항상 남김) |
| ① 약점 2 | `capture/scan_preparation.dart` | 템플릿 앞 줄 정리 단계: 줄에 붙은 `★ * ☆ ＊`를 글자 수 비례 위치에서 떼어 냅니다. 읽기 칸이 "가나만" 조건을 다시 만족합니다. 10절부터는 뗀 기호를 버립니다(기호 잡음 정리 `dropSymbolNoise`) |
| ① 약점 4 | `vocab/layout.dart` | 형식 판별 두 번째 신호 = **예문 줄 수**(10자 이상, 일본어 비율 0.85 이상, 히라가나 있음, 가나만은 아님). 0줄 → 목록형, 3줄 이상 → 항목형, 1~2줄 → 번호 간격. 실제 교재의 판독 폴더 34개(엔진·이미지 변형) × 5쪽 모두에서 목록형 0줄, 항목형 4줄 이상 |
| ① 대조 | `eval/reference_diff.dart`, `tool/reference_diff.dart` | 기준 구현과 다른 칸은 의도한 차이 목록에 있어야 함(2절) |
| ② 회전 | iOS `OcrChannel.swift` | 첫 일본어 판독의 상자 글 방향(topLeft→topRight)을 글자 수로 투표 → 득표율 0.6 이상·20자 이상이면 그 방향으로 돌린 EXIF 방향으로 일본어를 다시 판독, 한국어는 처음부터 세운 방향으로. 좌표는 세운 이미지 기준. 바른 사진은 추가 판독 없음 |
| ② 회전 | Android `OcrChannel.kt`, `OcrGeometry.kt` | `androidx.exifinterface`로 EXIF 각도를 읽어 `InputImage.fromBitmap(bmp, 각도)`. 일본어 판독의 `Line.angle` 중앙값 + 넘긴 각도가 ±90°·180°(±20°)면 모든 상자를 그만큼 돌립니다(다시 판독하지 않음) |
| ③ ★ 보조 판독 | iOS 채널 + core | **걷어냄 (2026-11, 학습에 필요 없음, 10절).** 이진화한 사본을 한 번 더 판독해 ★만 더하던 단계였습니다 |
| ④ 조각 | Android `OcrGeometry.segments` | Line을 Element 간격 > 1.1 × 줄 높이에서, 그리고 기호(★·`*`·☆·＊, `NOISE_SYMBOLS`) 앞뒤에서 자릅니다. x는 Symbol 상자 합집합, y는 줄 상자, c는 Symbol 신뢰도 평균 |
| ④ 채널 | Android `OcrChannel.kt` | 일본어 → 한국어 차례 실행, recognizer 재사용과 `close()`, 비트맵 `recycle()`(판독이 끝나지 않았으면 놓지 않음), `Tasks.await` 60초 제한 |
| ④ 규칙 | core 템플릿·줄 정리·보정기 체인 | ML Kit 보정 규칙 18개(6.6절) |

### 6.2 단계별 점수표 (회귀 세트 네 개, 줄 전체 · 조용한 오류)

단계를 순서대로 하나씩 더해 잰 값입니다(★ 포함 옛 기준). ②③은 채널 변경이라 core 세트의 점수는 바로 앞 단계와 같고, 채널 측정은 오른쪽 열에 적습니다.

| 단계 | 합성 세트 (Vision형, 저장소) | 교재 Vision (로컬) | 교재 ML Kit 조각 (로컬) | 페이지만 자른 좌표 (로컬, 측정만) | 채널 측정 |
|---|---|---|---|---|---|
| 시작 (main) | 30/35 · 1 | 52/59 · 1 | 13/59 · 4 (기준 해석기) | 30/59 · 1 | iOS 시뮬레이터 49/59 · 2 (12·13쪽 미리 돌림) |
| ① 해석기 | 30/35 · 1 | 52/59 · 1 | 16/59 · 3 | **39/59** · 1 | |
| ② 회전 | (같음) | (같음) | (같음) | (같음) | iOS 51/59 · 1, Android 36/59 · 2 (둘 다 원본 사진, 돌리지 않음) |
| ③ ★ 보조 판독 | (같음) | **54/59** · 1 (★ 58/59, 녹화한 이진화 판독을 합침) | (같음) | (같음) | iOS **54/59** · 1 (★ 59/59) |
| ④ ML Kit 규칙 | 30/35 · 1 | 52/59 · 1 (★ 보조 54/59) | **38/59** · 1 | **40/59** · 1 | |
| 목표 | ≥ 30/35 | ≥ 52, ★ 보조 54, 조용한 오류 ≤ 1 | ≥ 38/59 | 측정만 | |

그때의 최종 합계 줄(★ 포함 옛 기준. `dart run tool/eval_capture.dart`, 교재 세트는 `--fixtures`·`--gt`로 로컬 폴더를 줌. `--stars`는 10절에서 걷어냄):

```
합성 세트 (Vision형)
TOTAL  headword=33/35  readings=35/35  pos=35/35  meaning=33/35  important=34/35  ex_ja=10/11  ex_ko=10/11  row=30/35  found=35/35
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 4

교재 Vision
TOTAL  headword=57/59  readings=59/59  pos=59/59  meaning=57/59  important=56/59  ex_ja=12/12  ex_ko=12/12  row=52/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 3

교재 Vision + ★ 보조 판독 (--stars <이진화 판독 폴더>)
TOTAL  headword=57/59  readings=59/59  pos=59/59  meaning=57/59  important=58/59  ex_ja=12/12  ex_ko=12/12  row=54/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 3

교재 ML Kit 조각
TOTAL  headword=52/59  readings=59/59  pos=55/59  meaning=58/59  important=46/59  ex_ja=12/12  ex_ko=12/12  row=38/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 7;  flagged but actually correct: 23

페이지만 자른 좌표 (원근 보정 이미지 좌표 그대로)
TOTAL  headword=52/57  readings=55/57  pos=55/57  meaning=52/57  important=49/57  ex_ja=8/10  ex_ko=8/10  row=40/59  found=57/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 8;  flagged but actually correct: 2
```

- 페이지 좌표의 남은 손실은 원근 보정이 펼친 면을 비틀어 편 157쪽(번호를 다른 숫자로 읽어 2단어를 놓침, 찾음 4/6)이 가장 큽니다.
  사진 좌표로 되돌린 판독(`a-persp-photo`)은 기준 해석기 40/59 → 41/59입니다.
- 정리 필터 변형(`research/scan/README.md` 4.2절)에서 약점 수정의 효과(최종 코드): 회색조 27 → 38/59(가짜 번호 열), 이진화 24 → 45/59(★가 붙은 읽기),
  원근 보정 + 이진화 18 → 28/59. OCR 입력은 여전히 컬러 원본이 가장 좋습니다(52/59).
- ML Kit 칸별 숫자(표제어 52, 읽기 59, 품사 55, 뜻 58, ★ 46, 예문 12/12)는 연구 도구의 보정 해석기 결과와 같습니다. Line 단위 판독 기록으로는 37/59(연구 도구와 같음).

### 6.3 합성 세트, ML Kit형 (저장소, `packages/core/test/fixtures/synthetic_mlkit/`)

합성 세트의 11쪽·140쪽 단어를 ML Kit 채널이 돌려주는 모양(조각, 연속 신뢰도, 상자 높이 0.85배)으로 만들었습니다(`tools/synthetic/make_pages.py`).
넣은 실수: ★ 미출력 2, ★가 읽기에 붙음, ★를 `*`로(★는 10절부터 잡음으로만 다룸), 배지 `8`, 붙은 배지(`명별`), 배지 미출력 2, 번호의 `O`·`D`·`l`, 번호 뒤 체크박스 `O`, 표제어 앞 `|` 2,
읽기 뒤 다른 칸 글자(`ひかる で`), 읽기의 `リ`, 한글 사이 마침표 2, 쉼표로 끝난 뜻, 낮은 신뢰도 쓰레기 줄(한국어 판독의 일본어 줄, 뜻 앞의 한글 잡음),
가짜 일본어 예문 줄(신뢰도 0.31), 항목형 번호 줄 미출력 3, 긴 후리가나 줄, 예문 앞 떠돌이 글자, 왼쪽에서 시작하는 번역, 비슷한 한자로 읽은 표제어(조용한 오류).

```
page tpl    n found head read  pos mean  row exJA exKO meta
  11 list  12    12   12   12   12   11   11    -    - ok
 140 entry  6     6    5    6    6    6    5    6    6 ok

TOTAL  headword=17/18  readings=18/18  pos=18/18  meaning=17/18  ex_ja=6/6  ex_ko=6/6  row=16/18  found=18/18
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 1;  flagged but actually correct: 8
```

틀린 2줄은 모두 일부러 넣은 것입니다: 쉼표로 끝난 뜻 1("뜻 확인 필요" `meaning:suspect`로 표시), 비슷한 한자 표제어 1(조용한 오류).
★ 포함 옛 기준은 ★ 미출력 2줄까지 틀려 14/18이었습니다.
같은 판독 기록을 기준 해석기(`tools/reference/parse_eval.py`)로 읽으면 1/18, 찾음 13/18입니다.
회귀 테스트(`regression_test.dart`의 "synthetic pages, ML Kit")가 위 값을 정확히 단언하고, `synthetic_mlkit_pages_test.dart`가 실수마다 하나씩 확인합니다.

### 6.4 iOS 채널 (회전)

- 실제 사진 탐침 결과와 시간은 4절. 회전 판별은 12·13쪽(EXIF 없음)에서 90°, 나머지 3쪽에서 0°(EXIF로 이미 바름)였습니다.
- 순수 로직 XCTest 5개(`app/ios/RunnerTests/RunnerTests.swift`): 투표 방향(0·90·180·270°, 경계 44°/46°), 픽셀 가로세로비, 득표율·글자 수 문턱, EXIF 방향과 회전의 합성(거울 방향은 돌리지 않고 로그를 남김), 가로세로가 바뀌는 방향. (이진화 이미지 크기 테스트는 ★ 보조 판독과 함께 걷어냄)
- 긴 변이 4096px를 넘는 사진만 줄여 디코드합니다(12MP 사진은 그대로). 판독마다 `autoreleasepool`로 임시 메모리를 놓습니다.
- 채널 JSON에는 `"turned"`(돌린 각도)와 `"timing"`(`orient_pass`, ms)이 더 있습니다. Dart 모델은 `turned`만 읽고(`OcrScan.turned`), `timing`은 탐침이 출력합니다. 옛 기록의 `"star"` 쪽은 읽을 때 무시합니다.

### 6.5 Android 채널 (조각, 회전, 에뮬레이터)

`flutter test integration_test/vision_channel_probe_test.dart -d emulator-5554` (사진은 `run-as`로 앱 내부 저장소에 넣음, 끝난 뒤 지움). 원본 사진, 12·13쪽 돌리지 않음.
좌표를 소수 4자리로 맞추고 오류 처리를 보강한 뒤 다시 돌려 점수가 칸별로 같음을 확인했습니다(시간은 첫 측정 값, 점수는 ★ 포함 옛 기준).

```
engine=mlkit
p012: turned 90°, ja 88 lines 3057 ms, ko 58 lines 2400 ms, no star pass, extra {decode: 484, exif_rotation: 0}, total 6134 ms
p013: turned 90°, ja 61 lines 901 ms, ko 48 lines 750 ms, no star pass, extra {decode: 467, exif_rotation: 0}, total 2202 ms
p069: turned 0°, ja 62 lines 1051 ms, ko 57 lines 887 ms, no star pass, extra {decode: 460, exif_rotation: 90}, total 2445 ms
p157: turned 0°, ja 74 lines 1131 ms, ko 62 lines 867 ms, no star pass, extra {decode: 233, exif_rotation: 90}, total 2333 ms
p185: turned 0°, ja 64 lines 834 ms, ko 46 lines 928 ms, no star pass, extra {decode: 282, exif_rotation: 90}, total 2106 ms
TOTAL  headword=47/59  readings=55/59  pos=50/59  meaning=52/59  important=50/59  ex_ja=12/12  ex_ko=12/12  row=36/59  found=59/59
core fields wrong but NOT flagged (silent errors): 2
core fields wrong and flagged for review: 16;  flagged but actually correct: 20
```

- 회전: 12·13쪽은 EXIF가 0이고 줄 각도 −90°로 시계 방향 90°를 판별, 나머지는 EXIF 90°로 이미 바름.
- **조각 구현 확인:** 같은 원본 사진·같은 디코드 경로(`fromBitmap(bmp, EXIF)`)의 연구 원본 덤프(`raw/orig-bitmap-exif`)를
  연구 도구(`raw_to_fixture.py segment --auto-rotate`)로 바꾼 결과와 쪽·판독마다 줄 수가 모두 같고(88/58, 61/48, 62/57, 74/62, 64/46),
  Dart 점수가 칸별로 같습니다(36/59).
- 세운 JPEG를 넣은 연구 측정(38/59)보다 2줄 낮은 것은 디코드 경로 차이입니다(연구 README 6절: 같은 쪽도 경로에 따라 ±4줄, 원본 입력에서 새 잡음).
  연구의 "원본 + 각도로 자동 세우기" 측정(36/59)과 같습니다.
- 첫 쪽의 시간(3.1초)에는 모델 적재가 들어 있습니다. 에뮬레이터라 실제 기기 시간이 아닙니다.
- 순수 로직 JVM 테스트 11개(`app/android/app/src/test/.../OcrGeometryTest.kt`): 자를 필요 없는 줄, 넓은 간격, Element 안에 붙은 기호(★·`*`), 줄 상자 높이 유지,
  상자 없는 글자(일부만 없는 경우 포함), 신뢰도 대체, 각도+EXIF로 회전 판별(시계 1·2·3회, 불분명·짧은 줄은 0), 상자 돌리기와 틀 바꾸기, 돌린 뒤 자르기.
- 쪽 JSON에 진단 값이 더 있습니다: `dropped`(상자 없는 줄), `lost_glyphs`(잘린 줄에서 빠진 상자 없는 글자), `no_confidence`(신뢰도가 NaN이라 0.5로 쓴 조각).
  판독이 시간 제한(60초)에 걸리거나 끝나지 않으면 비트맵을 해제하지 않고 남겨 둡니다(네이티브가 아직 읽을 수 있으므로).

### 6.6 ML Kit 보정 규칙 18개의 자리

| 규칙 | 자리 | 엔진 |
|---|---|---|
| `id_ocr` 번호의 O·o·D, 번호 뒤 `O` | 템플릿 (`anchors.dart`, `fields.dart` 표제어 정리). 숫자 2개 이상일 때만 | 공통 |
| `star_split` ★·`*` 떼기 | 줄 정리 (`scan_preparation.dart`). 10절부터 뗀 기호를 버림(`dropSymbolNoise`) | 공통 |
| `reading_token` 읽기는 첫 토막 | 템플릿 (`fields.dart` `readingText`, 슬래시 앞뒤 공백은 먼저 붙임) | 공통 |
| `kata_lookalike` 읽기의 リ·ヘ·ベ·ペ | 보정기 `ReadingLookalikeCorrector` (자동 보정으로 표시) | 공통 |
| `keep_anchored` 번호만 읽힌 줄 유지 | 목록형 템플릿. 줄 절반 이상에 읽기 칸이 있는 번호 열에서만(잘린 옆 페이지 번호가 단어가 되지 않게) | 공통 |
| `row_ids` 번호 채우기 | 이미 Dart에 있음(2.2절 차이 2번, 앞뒤 번호에서 거리만큼) | 공통 |
| `entry_fallback` 항목형 번호 대체, 안내 문구 제외 | 항목형 템플릿 (`_withRowAnchors`). 판별은 예문 줄 신호(6.1절) | 공통 |
| `sentence_geom` 예문 기하 | 항목형 템플릿 | 공통 |
| `sentence_conf` 예문 c ≥ 0.4 | 항목형 템플릿 | **ML Kit만** |
| `entry_reading` 읽기 조건 | 항목형 템플릿 | 공통 |
| `bar_noise` 앞의 `\|` | 템플릿 (`fields.dart`) | 공통 |
| `pos_8` 배지 `8` | 보정기 `BadgeMisreadCorrector` | 공통 |
| `pos_glued` 붙은 배지 | 목록형 템플릿 (이웃 줄 배지 위치가 필요) | 공통 |
| `pos_infer` 품사 추정 | 보정기 `PosInferenceCorrector` (`pos:inferred`, 새 표시 종류 "추정") | 공통 |
| `low_conf` c < 0.2 버림 | 줄 정리 | **ML Kit만** |
| `meta_day` DAY 숫자 위치 | 템플릿 (`page_meta.dart`) | 공통 |
| `ko_period` 한글 사이 마침표 | 보정기 `MeaningPunctuationCorrector`(뜻, 배지를 뗀 뒤, 자동 보정으로 표시) + `page_meta.dart`(제목) | 공통 |
| `meaning_cut` 쉼표로 끝난 뜻 | 보정기 `CutMeaningFlagger` (`meaning:suspect`, 새 표시 종류 "의심") | 공통 |

- 엔진과 상관없이 켠 규칙은 두 Vision 세트의 칸을 하나도 바꾸지 않았습니다(2절, 다른 칸 0개). 신뢰도 눈금에 기대는 두 규칙만 `OcrPage.engine == "mlkit"`일 때 켭니다.
- 보정기 체인은 core `standardCorrectors()` 안에서 바뀌므로 블록 지도(`blocks.dart`)는 그대로입니다.
- 새 표시 종류: `IssueKind.inferred`(→ `FieldStatus.inferred`), `IssueKind.suspect`(→ `FieldStatus.suspect`, 항목은 "확인 필요"로 셈).
  지금 검토 화면은 `needsReview`(빨간 여백)만 보고 두 상태를 따로 그리지 않습니다.

### 6.7 Android ★ 칸 픽셀 검사 — 걷어냄 (2026-11, 학습에 필요 없음)

ML Kit가 놓친 ★를 사진의 붉은 픽셀 비율로 되찾던 검사(core `star_check.dart`·`StarMeter` 포트, Android `measureStars`·`StarPixels.kt`, 앱 `PlatformStarMeter`)입니다.
★는 그 교재에만 있는 표시라 학습에 필요 없어 10절에서 모두 걷어냈습니다. 측정 기록은 git 기록(이 절의 이전 판)에 남아 있습니다.

## 7. 저장소 (SQLite, drift)

`packages/storage_drift/`는 순수 Dart 패키지입니다. 앱은 `blocks.dart`에서 `DriftLibraryRepository`, `DriftReviewRepository`를 끼우고,
두 저장소가 DB 파일 하나(`ShioriDatabase`)를 같이 씁니다. 위젯 테스트는 InMemory 블록을 씁니다.

### 7.1 설계

- **트랜잭션 포트:** 두 포트에 `Future<T> transaction<T>(Future<T> Function() action)`을 더했습니다.
  유스케이스의 두 단계 쓰기가 각각 한 저장소 안에서 일어나므로(DAY → 단어, 카드 → 기록) 포트마다 두었고,
  블록 교체도 지금처럼 provider 한 줄로 끝납니다. 뜻: 실패하면 그 안의 쓰기를 모두 되돌리고 오류를 다시 던짐,
  안쪽 호출은 자기 쓰기를 봄, 바깥 호출은 끝날 때까지 기다림, 겹친 호출은 savepoint.
  `LibraryService.saveDraft`(DAY + 단어), `StudyService.answer`(카드 + 기록), `createTextbook`(빈 id 확인 + 저장)이 이것으로 감싸져 있습니다.
- **테이블:** 콘텐츠 `textbooks`, `textbook_days`, `words` / 학습 상태 `review_cards`, `review_logs`.
  - 단어 저장은 `INSERT ... ON CONFLICT DO UPDATE`라 행을 지우지 않습니다. `review_cards`에는 단어로 가는 외래 키가 없어
    단어를 다시 찍어 갱신해도(또는 지워져도) 학습 상태가 남습니다. 콘텐츠 쪽은 외래 키를 켜 둡니다(`PRAGMA foreign_keys = ON`,
    없는 교재의 단어·DAY는 거부. InMemory 블록은 이 검사를 하지 않습니다).
  - 읽기 여러 개는 `words.readings`에 JSON 배열로 둡니다. 항상 단어와 함께 읽고 쓰며 따로 찾지 않으므로 하위 테이블의 조인과
    순서 열이 필요 없습니다. 배열이 아닌 값이 들어 있으면 빈 목록으로 읽지 않고 `FormatException`으로 실패합니다.
    예문은 목록이 아니라 한 쌍이라 `example_ja`, `example_ko` 두 열로 두고, 둘 다 있거나 둘 다 없도록 CHECK 제약을 겁니다.
  - 시각은 UTC 기준 epoch 마이크로초(INTEGER)로 저장하고, 같은 순간의 현지 시각으로 읽습니다. 앱 시계가 주는 현지 시각은
    `==`로 같게 돌아오고, 학습 일 경계(`dayStartHour`, 현지 시)는 그대로 계산됩니다(계약 테스트로 03:59:59와 04:00 확인).
- **DB 파일:** 앱 지원 폴더의 `shiori.sqlite` (`path_provider`의 `getApplicationSupportDirectory`).
  iOS `<앱 데이터 컨테이너>/Library/Application Support/`, Android `/data/data/<application id>/files/`.
  앱을 업데이트하면 남고, **앱을 지우면(다시 설치하면) 함께 지워집니다.** Android는 `allowBackup="false"`라 기기 백업에도 들어가지 않습니다.
  iOS 기기 백업 포함 여부와 앱 안 백업은 이번 범위가 아닙니다.
- **여는 시점과 실패:** `main`은 폴더를 찾아 DB 객체를 넘기고(`app/lib/app/startup.dart`), SQLite 파일은 첫 쿼리 때 백그라운드 isolate에서 열립니다.
  폴더를 못 찾거나 10초 안에 답이 없으면 로그를 남기고 앱은 그대로 뜨며, 저장소 provider가 그 오류를 던져 홈이 불러오기 오류를 보입니다.
- **복습 기록 순서:** 오래된 것부터(같은 시각이면 넣은 순서). `at` 색인으로 "오늘 이후" 조회가 정렬 없이 끝납니다.
- **sqlite3 버전:** Flutter 3.41.5가 `meta 1.17.0`을 고정하는데, sqlite3 3.6 이상은 `hooks 2.2 → record_use → meta 1.19`를 요구해
  앱에서 풀리지 않습니다. 그래서 `storage_drift`와 `dict_jmdict` 모두 `sqlite3: ">=3.4.0 <3.6.0"`(지금 3.5.2)으로 맞췄습니다.
  Flutter SDK가 올라가면 상한을 풉니다.

### 7.2 스키마 버전과 마이그레이션

- 지금 `schemaVersion = 3` (16절, 그 전 v2는 10절). 덤프: `packages/storage_drift/drift_schemas/shiori_database/drift_schema_v1.json`, `drift_schema_v2.json`, `drift_schema_v3.json`,
  단계 파일: `lib/src/database.steps.dart`(생성), 테스트 도우미: `test/migrations/generated/`
  (`dart run drift_dev schema generate drift_schemas/shiori_database/ test/migrations/generated/`).
- v1 → v2: `words.important` 열을 뺍니다. `Migrator.alterTable(TableMigration(schema.words))`로 SQLite 권장 12단계(새 표 → 복사 → 옛 표 지움 → 이름 바꿈, 색인 다시 만듦)를
  밟고, 모든 단계를 트랜잭션 하나로 감싸 중간에 실패하면 v1 파일이 그대로 남습니다. 다른 열과 모든 행(교재, DAY, 단어, 복습 카드·기록)은 그대로 옮겨집니다.
- `test/migrations/migration_test.dart`: 지금 스키마가 v2 덤프와 같은지(`validateDatabaseSchema`), 새 DB가 v2이고 `words`에 `important`가 없는지,
  v2 파일 검증, v1 파일을 열어 `SchemaVerifier.migrateAndValidate(db, 2)`, v1 스키마로 직접 쓴 행(교재 1·DAY 2·단어 3(그중 ★ 하나)·카드 2·기록 2)이
  `important`만 빠지고 모든 칸이 그대로인지 + 저장소 블록으로 읽기.
- 이 빌드가 모르는 버전의 파일(예: 더 새 앱이 쓴 파일, user_version 3)은 추측하지 않고 `UnsupportedError`로 거부합니다.
- 버전을 올릴 때: 테이블 수정 → `schemaVersion` 올림 → `dart run drift_dev make-migrations`(덤프·단계 파일) →
  위 `schema generate`로 도우미(이 저장소는 `test/migrations/generated/`에 둠) → `onUpgrade`의 `migrationSteps(...)`에 단계 연결 →
  마이그레이션 테스트에 옛 버전마다 경우 추가.
- 생성 단계 파일(`database.steps.dart`)에는 `coverage:ignore-file` 머리말이 없어 커버리지 숫자에서 따로 뺍니다(손으로 쓴 코드 221/221줄, 100%).
- 코드 생성 결과(`lib/src/database.g.dart`, 생성된 테스트 도우미)는 저장소에 넣습니다. 받은 사람은 생성 없이 테스트를 돌립니다.
  다시 만들 때: `dart run build_runner build`.

### 7.3 결과 (2026-11-05)

| 항목 | 명령 | 결과 |
|---|---|---|
| core | `cd packages/core && dart analyze && dart test` | 문제 없음, **173개 통과**, 교재 세트 8개 건너뜀 (교재 세트 포함 **190개**) |
| core 커버리지 | `dart run coverage:test_with_coverage -o coverage` | 줄 커버리지 **97.2%** |
| core 점수표 | `dart run tool/eval_capture.dart` (`--fixtures` 교재 세트) | 합성 row **30/35**, 교재 row **52/59** (2절과 같음) |
| 저장 패키지 | `cd packages/storage_drift && dart analyze && dart test` | 문제 없음, **58개 통과** (계약 테스트 22개 × InMemory·drift = 44, drift 전용 11개(변환기 포함), 마이그레이션 3개) |
| 저장 패키지 커버리지 | `dart run coverage:test_with_coverage -o coverage` | **100%** (189/189줄). 생성 코드(`database.g.dart`)와 테이블 선언(`tables.dart`, 생성기만 읽음)은 `coverage:ignore-file`로 뺐습니다. 생성 코드까지 세면 33% |
| 사전 패키지 | `cd packages/dict_jmdict && dart analyze && dart test` | sqlite3 3.5.2에서 문제 없음, **63개 통과** |
| app | `cd app && flutter analyze && flutter test` | 문제 없음, **43개 통과** (DB 폴더를 못 찾으면 앱은 뜨고 홈이 불러오기 오류를 보이는지 포함) |
| Android 빌드 | `flutter build apk --debug` | 성공, APK에 `libsqlite3.so`(arm64-v8a·armeabi-v7a·x86_64) 포함 |

계약 테스트(`packages/storage_drift/test/contract/repository_contract.dart`)는 한 벌의 테스트를 InMemory와 drift에 똑같이 돌립니다.
홈 교재 목록용 읽기 `LibraryRepository.textbookStats()`(교재별 단어 수·DAY 목록)도 같은 계약으로 지킵니다. drift는 `textbooks LEFT JOIN words GROUP BY 교재, DAY` 쿼리 한 번입니다(9절).
core의 일반 의존성에 `test`를 넣지 않으려고(앱까지 따라 들어가 `flutter_test`의 고정 버전과 부딪힘) 저장 패키지의 테스트 폴더에 두었습니다.

### 7.4 iOS 시뮬레이터: 껐다 켜도 남는지

iPhone 17 Pro (iOS 26.5), 합성 샘플 페이지, 실제 DB 파일.

```
cd app
xcrun simctl uninstall <시뮬레이터> com.nihongoapp.shiori
flutter drive -d <시뮬레이터> --keep-app-running --driver=test_driver/integration_test.dart \
  --target=integration_test/persistence_test.dart --dart-define=SHIORI_PERSISTENCE_STEP=save
xcrun simctl terminate <시뮬레이터> com.nihongoapp.shiori
flutter drive ... (같은 명령) --dart-define=SHIORI_PERSISTENCE_STEP=reopen
# 추가: 테스트가 아닌 앱 빌드로 다시 켜기
xcrun simctl terminate <시뮬레이터> com.nihongoapp.shiori
flutter build ios --simulator --debug && xcrun simctl install <시뮬레이터> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <시뮬레이터> com.nihongoapp.shiori && xcrun simctl io <시뮬레이터> screenshot ../docs/screenshots/17_app_relaunched.png
```

`--keep-app-running`이 없으면 `flutter drive`가 끝날 때 앱을 지워 데이터 폴더도 사라지므로 꼭 붙입니다.

- 저장 단계: 빈 홈 → DAY 20 샘플 6단어 저장 → 학습(다시 학습 1번, 알고있음 6번) → 홈 "오늘 6개 외움".
- 앱 프로세스를 끈 뒤 다시 켠 단계: 홈 "오늘 6개 외움"이 그대로이고, 같은 DB 파일에서 단어 6, 카드 6(다시 학습한 1장은 2단계, 나머지 4단계), 기록 7을 읽음(테스트가 단언).
- 실제 앱(`main()`)으로 다시 켜도 같은 홈이 나옴.

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `16_textbook_after_restart.png` | 다시 켠 뒤 교재 › DAY 20: 다시 학습한 1211은 2단계, 나머지 4단계 |
| `17_app_relaunched.png` | 테스트 빌드가 아닌 앱(`main()`)으로 다시 켠 홈: 교재·단어 6개·오늘 6개 외움 |

다시 켠 홈 화면은 `09_home_after_study.png`와 내용이 같아(시뮬레이터 상태 표시줄 시각도 09:41 고정) 따로 저장하지 않았습니다.
기존 흐름 테스트(`flow_screenshots_test.dart`)는 매번 빈 홈에서 시작하도록 메모리 DB로 돕니다.

## 8. 사전 연결 (JMdict, 2026-11-05)

### 8.1 바꾼 것

- **포트**: `Dictionary`에 `checkPair(headword, readings)` → `PairStatus { known, compoundOnly, notFound, unavailable }`,
  `fixHeadword(ocrHeadword, reading, {pos, limit})`, `byReading(..., pos:)`(품사 힌트는 순서만 바꿈)을 더했습니다.
  `EmptyDictionary`는 `unavailable`과 빈 목록을 돌려줍니다.
- **모델**: `CapturedEntry.ocrHeadword`(템플릿이 보정기 전 표제어를 채움), `IssueKind.unverified`·`FieldStatus.unverified`("사전에 없음", 확인 필요로 셈).
- **보정기**: `DictionaryPairCorrector`를 `DictionaryCandidateCorrector`와 `MissingFieldFlagger` 사이에 넣었습니다.
  짝이 있으면 그대로, 규칙이 바꾼 표제어가 없고 OCR 원문이 있으면 원문으로, 합성어로만 맞으면 그대로,
  헷갈리는 글자로 설명되면 고치고(후보도 채움), 그 밖은 "사전에 없음"입니다.
- **규칙 좁히기**: `ConfusableGlyphCorrector`는 앞뒤에 다른 가타카나가 없는 한 글자만 한자로 바꿉니다(`タ日`→`夕日`, `アメリカ人`은 그대로).
  헷갈리는 글자로만 된 2글자 이상 덩어리(체크박스 잡음 `ロロロ` 등)는 바꾸지 않고 "의심"으로 표시합니다
  (넓은 규칙이 우연히 붙이던 표시를 잃지 않게. 교재 세트의 스캐너형 자르기에서 조용한 오류가 1→2로 늘던 것을 막음).
- **어댑터**: `packages/jmdict_block`(순수 Dart). 앱은 `app/assets/dict/`의 gzip을 첫 실행 때 앱 캐시 폴더로 풀어 엽니다(다시 만들 수 있는 파일이라 iOS 백업에서 빠지게. 시스템이 지우면 다음 실행 때 다시 풂).
- **화면**: 검토 화면에 사전 후보 칩(누르면 표제어로 들어가고 "고침", 위쪽 표시는 "직접 고름"), 칸별 표시(사전에 없음·의심·고침·추정), 홈 → 정보 화면(출처·링크·판).
  편집 시트에서 "고치기"를 누르면 표제어가 그대로여도 "사전에 없음"·"의심"을 확인한 것으로 지웁니다(사전에 없는 진짜 단어, 읽기만 틀린 경우).

### 8.2 사전 끔 / 켬 점수표 (`full-lean`, JMdict 2026-11-04)

명령: `cd packages/jmdict_block && dart run tool/eval_capture_dict.dart --db <full-lean.sqlite> [--fixtures DIR] [--gt FILE]`
(DB는 `gzip -dc app/assets/dict/jmdict-full-lean.sqlite.gz`). 교재 세트는 합계만 적습니다. 10절(★ 걷어냄) 뒤 다시 잰 값입니다(줄 전체는 ★ 칸 없는 기준. 나머지 열은 전과 같음, ★ 보조 판독 줄은 걷어냄).

| 세트 | 줄 전체 끔 → 켬 | 조용한 오류 끔 → 켬 | 맞는 표제어를 "사전에 없음" | 사전이 새로 "확인 필요"로 잡은 틀린 줄 | 못 읽은 표제어의 정답 후보 순위 |
|---|---|---|---|---|---|
| 합성 (Vision형, 저장소) | 31/35 → 31/35 | 1 → 1 | 0/33 | 0 | 2위, 1위 |
| 합성 (ML Kit형, 저장소) | 16/18 → 16/18 | 1 → **0** | 0/17 | 1 | (없음) |
| 교재 Vision (로컬) | 55/59 → 55/59 | 1 → 1 | **0/57** | 0 | **1위, 1위** |
| 교재 ML Kit (로컬) | 51/59 → 51/59 | 0 → 0 | 0/52 | **2** | 2위, 1위, 1위, 1위, 1위 |

- 줄 전체 점수는 바뀌지 않습니다. 사전은 표제어를 학습자 대신 고르지 않고(후보만), 이 세트들에는 규칙이 망친 단어나 헷갈리는 글자 오류가 없기 때문입니다.
- 효과는 검토 화면 쪽입니다. ML Kit 세트에서 틀린 표제어 2줄이 전에는 "추정"·"자동 보정"만 붙어 확인 필요에 없었는데, 이제 "사전에 없음"으로 확인 필요에 들어갑니다.
- **합성 세트의 `日`(ひ)은 2위**입니다. JMdict 순위에서 ひ의 1위가 `火`(빈도대 nf02)이고 `日`은 nf03이라서입니다. 품사(명사) 힌트로도 가릴 수 없습니다.
  테스트 DB에는 `火`가 없어 단위 테스트에서는 1위입니다. 검토 화면은 후보 5개를 모두 보여 줍니다.

### 8.3 앱

| 항목 | 결과 |
|---|---|
| 사전 asset 만들기 | `python3 tools/dict/build_app_asset.py --expect-sha256 7f6dc7a4…001ed` 약 8초. gzip 12,200,998 B, SQLite 30,539,776 B(sha256 `bdaf3b7c…`, 이전 빌드와 같음) |
| 첫 실행 | gzip을 백그라운드 isolate에서 앱 캐시 폴더로 풂(`.part` 파일 → 이름 바꿈 → 판 표시 파일). 화면은 기다리지 않고, 그동안 사전 슬롯은 비어 있음 |
| 실패 시 | asset 없음·깨진 gzip·판 표시 파일 오류·열기 실패 → 로그 한 줄, `EmptyDictionary`로 동작(단위 테스트 9개) |
| debug APK 크기 | 압축 항목 합계 194,296,028 B → 206,481,158 B (**+12.2 MB**, asset이 이미 gzip이라 zip으로 더 줄지 않음). 설치 뒤 풀린 파일 30.5 MB가 더 생김 |
| iOS 시뮬레이터 (iPhone 17 Pro) | asset 없음: 앱이 뜨고 정보 화면에 "사전 데이터가 들어 있지 않아요". asset 있음: 첫 실행에 풀고 후보 칩·정보 화면 동작 (`integration_test/dictionary_screenshots_test.dart`) |
| 스크린샷 | `docs/screenshots/18_about_dictionary.png`, `19_review_candidates.png`, `20_review_candidate_picked.png` |
| 배포 빌드 | 사전 asset이 없으면 Gradle `preReleaseBuild`와 iOS 셸 단계가 멈춤(dev_samples 검사와 같은 자리) |

## 9. 캡처·검토 정리 (2026-11-05)

해석기의 칸 규칙과 회귀 점수는 그대로 두고, 기록·표시·집계만 바꿨습니다. 저장 스키마는 그대로였습니다(그때 `schemaVersion = 1`, 생성 코드 변화 없음).

### 9.1 바꾼 것

| 자리 | 내용 |
|---|---|
| 칸 배율 기록 | `columnScale(...)`이 값과 함께 **어떻게 정했는지**를 돌려줍니다: `ColumnScale(value, source)`, `ColumnScaleSource { reading, badge, tooFewRows, outOfRange }`, `isDefault`(뒤 둘). 값은 전과 같습니다. 읽기 열로 잰 값이 0.6~1.8 밖이면 배지 열을 다시 재지 않고 1.0(`outOfRange`)인 동작도 그대로입니다 |
| 쪽 단위 전달 | 두 템플릿 → `TemplateResult.columnScale` → `CaptureDraft.columnScale`(`copyWith`·`replaceEntry`·`==`에서 유지, 메모리에만 있고 저장하지 않음). 재지 않는 템플릿이면 null |
| 검토 화면 안내 | 배율이 기본값으로 넘어간 쪽은 요약 카드에 한 줄: "칸 위치를 재지 못해 기본값으로 읽었어요. 칸이 어긋났을 수 있어요." 항목마다 표시는 붙이지 않습니다 |
| 체크박스 잡음 "의심" | `ConfusableGlyphCorrector`의 가타카나 덩어리 검사(8.1절)는 그대로, 테스트만 붙였습니다(`到着ロロ` 의심, `アメリカ人` 이슈 없음, `タ日` → `夕日` 고침, 한자 없는 `ロロロ` 그대로) |
| 고치기 | core `applyLearnerEdits`로 옮겼습니다. 저장하면 그 항목의 **모든 칸**에서 "의심"(`suspect`)·"사전에 없음"(`unverified`)을 지웁니다(값이 그대로여도, 학습자가 보고 확인함). 바꾼 칸은 모든 표시를 지웁니다. 바꾸지 않은 칸의 "고침"·"추정"은 남습니다. 빈 칸은 다시 "없음"이 됩니다. 8.1절의 "표제어만" 규칙을 모든 칸으로 넓힌 것입니다 |
| 학습자가 고른 후보 | 새 이슈 종류 `IssueKind.picked`(코드 `headword:picked`, `pickHeadword`). 칸 표시는 전처럼 "고침"(`statusOf`는 `corrected`와 같게), 위쪽 배지는 "직접 고름 → X". **"자동 보정 N"(`correctedCount`)에는 들어가지 않습니다.** `needsReview`와 저장(`saveDraft`)은 전과 같습니다 |
| ★ 추정 표시 | 걷어냄 (2026-11, 10절). 검토 화면은 ★를 그리지 않습니다 |
| 홈 교재 목록 | `LibraryRepository.textbookStats()` → `TextbookStats(textbook, wordCount, days)`, 교재 순서는 `textbooks()`와 같음. drift는 `textbooks LEFT JOIN words GROUP BY 교재, DAY` 쿼리 한 번(단어 없는 교재도 0으로 한 줄). `shelfProvider`는 이것만 부르고, 교재마다 `words()`를 부르던 것은 없앴습니다 |

### 9.2 테스트

| 묶음 | 파일 | 내용 |
|---|---|---|
| 배율 기록 | `packages/core/test/capture/column_scale_source_test.dart` | 사진(읽기 열, 약 0.96)·읽기 없음(배지 열)·번호 1개(기본값, 행 모자람)·읽기 열이 기준의 2배(기본값, 범위 밖)·1.5배(잼). 합성 6쪽(`s010`·`s011`·`s140`·`s147`, ML Kit형 `m011`·`m140`)은 기본값이 아니고 값이 전과 같음(1e-12). 번호만 있는 작은 쪽은 두 템플릿 모두 기본값 기록. `copyWith` 유지 |
| 의심 표시 | `packages/core/test/capture/correctors_test.dart` | 위 4가지 |
| 고르기·고치기 | `packages/core/test/capture/learner_edits_test.dart` | 고른 후보는 자동 보정 수에 안 들어감, 확인 필요 아님, 저장됨. 고치기 규칙 8가지 |
| 저장소 계약 | `packages/storage_drift/test/contract/repository_contract.dart` | `textbookStats` 7개 × InMemory·drift: 빈 결과, 교재 순서(같은 시각이면 id), 단어 수(0 포함), DAY 중복 없이 오름차순·DAY 없는 단어는 수에만, `words()`와 같음, 바꿀 수 없는 목록, 트랜잭션 안에서 자기 쓰기를 봄 |
| 홈 | `app/test/app/shelf_provider_test.dart` | 세는 가짜 저장소로 `words()` 0번·`textbookStats()` 1번, 홈 카드의 단어 수·DAY 표시 |
| 검토 화면 | `app/test/features/review_marks_test.dart` | 바꾸지 않고 고치기 → 뜻 "의심" 사라지고 확인 필요 1 줄어듦, 후보를 골라도 "자동 보정 1" 그대로, 쪽 안내(기본값 둘은 보임, 잰 쪽·재지 않은 쪽은 안 보임) |

### 9.3 점수 (★ 포함 옛 기준)

| 세트 | 결과 |
|---|---|
| 합성 (Vision형) | 30/35, 기준 구현과 다른 칸 0개 (전과 같음) |
| 합성 (ML Kit형) | 14/18 (전과 같음) |
| 교재 Vision (로컬) | 52/59, ★ 보조 54/59, 기준 구현과 다른 칸 0개 (전과 같음) |
| 교재 ML Kit 조각 (로컬) | 38/59 (전과 같음) |
| 배율이 기본값으로 넘어간 쪽 | 합성 6쪽 0쪽(0.98~1.02). 교재 5쪽: Vision 0쪽(0.98~1.03), ML Kit 조각 0쪽(0.97~1.04), 페이지만 자른 좌표 0쪽(1.12~1.37) |

### 9.4 화면 확인

| 항목 | 방법 | 결과 |
|---|---|---|
| 후보를 골라도 "자동 보정" 수 그대로 | iOS 시뮬레이터 iPhone 17 Pro, 합성 샘플 DAY 01(`integration_test/dictionary_screenshots_test.dart`, 사전 asset 있음) | 고르기 전후 모두 "자동 보정 1", 고른 줄은 "직접 고름 → 日"·칸 "고침". `docs/screenshots/20_review_candidate_picked.png`를 다시 찍음(전에는 "자동 보정 2") |
| 홈 교재 목록 (drift 쿼리) | 같은 시뮬레이터, 실제 DB 파일로 저장 → 앱 끄기 → 다시 켜기(`integration_test/persistence_test.dart`) | 통과, 스크린샷 16은 전과 같음 |
| 바꾸지 않고 고치기로 "의심" 지우기, 쪽 안내 | 위젯 테스트(`review_marks_test.dart`) | 합성 샘플에는 뜻 "의심"·기본값 배율 쪽이 없어서(6쪽 모두 0.98~1.02) 시뮬레이터 대신 위젯 테스트로 확인 |
| Android 빌드 | `flutter build apk --debug` | 성공 |

## 10. ★ 걷어냄 (2026-11-05)

교재의 ★(중요 표시)는 그 교재에만 있는 표시라 학습에 필요 없습니다. 교재만의 표시가 앱 구조에 남지 않도록 ★ 인식·채점·화면 표시·저장 필드를 모두 걷어냈습니다.
판독 결과에는 ★·☆·`*`·`＊` 글자가 여전히 나오므로, 이 글자가 표제어·읽기·뜻에 섞이지 않게 떼어 버리는 **기호 잡음 정리**만 남겼습니다(의미는 두지 않음).

### 10.1 걷어낸 것

| 계층 | 걷어낸 것 |
|---|---|
| core 모델 | `CapturedEntry.important`, `EntryField.important`, `Word.important`, `OcrScan.stars`(옛 기록의 `"star"` 키는 읽을 때 무시) |
| core 캡처 | ★ 보조 판독 합치기(`starPassMarks`), 두 템플릿의 ★ 판정과 칸 상수(`cols.star`), ★ 칸 픽셀 검사(`capture/star_check.dart`), 포트 `StarMeter`(`ports/star_meter.dart`), 고치기의 ★ 인자 |
| core 채점·도구 | 채점 칸 `important`(줄 전체 = 표제어·읽기·품사·뜻), `eval/recorded_stars.dart`, `eval_capture.dart`의 `--stars`·`--star-ratios`, `scoreCapture(refine:)`. 사전 점수 도구 `eval_capture_dict.dart`의 `--stars` |
| 저장 | `words.important` 열 (스키마 v2, 7.2절) |
| 앱 | `PlatformStarMeter`, `starMeterProvider`, 캡처 흐름의 ★ 검사 단계(5초 제한 포함), 인식 호출 인자 `starPass`, 고치기 시트의 ★ 스위치, 검토 화면·학습 카드(`★ 기출`)·교재 화면의 ★, 탐침의 `SHIORI_PROBE_STARS`·`SHIORI_PROBE_MEASURE_STARS` |
| iOS | ★ 보조 판독(이진화 + 일본어 판독 한 번 더), 이진화 함수, 그 테스트 1개, `"star"` 응답 |
| Android | `measureStars`, `StarPixels.kt`와 그 테스트 14개 |
| 기준 구현·합성 생성기 | `parse_eval.py`의 `important` 출력·채점, 합성 정답의 `important`(판독 기록의 ★ 글자 잡음은 그대로) |

### 10.2 남긴 것: 기호 잡음 정리

- core `capture/scan_preparation.dart`의 `dropSymbolNoise`(전 이름 `splitGluedStars`): 일본어 판독 줄에서 `★ * ☆ ＊`를 글자 수 비례 위치로 잘라 내고 기호 조각은 버립니다
  (`★かわ` → `かわ`, `乗り換える*のりかえる` → 두 조각, 단독 `*` 줄 → 없음). 전에는 떼어 낸 기호를 `★` 줄로 남겼고, ML Kit의 낮은 신뢰도 줄을 버릴 때도 단독 ★ 줄은 남겼습니다.
  지금은 둘 다 버립니다. 합성 세트 두 벌과 교재 세트 두 벌(Vision, ML Kit 조각)에서 ★ 칸 말고는 모든 항목의 모든 칸이 전과 같았습니다.
- Android `OcrGeometry.segments`의 기호 앞뒤 자르기는 그대로입니다(상수 이름 `STARS` → `NOISE_SYMBOLS`). 붙은 기호를 단어 안쪽까지 자르지 않고 떼어 내기 위해서입니다.
- 표제어 정리(`cleanHead`)의 `★` 지우기와 안내 문구 줄(`★三人=…`, `★ 표시 = …`)이 항목이 되지 않는 규칙도 그대로입니다.

### 10.3 테스트

| 묶음 | 내용 |
|---|---|
| 지운 테스트 | core `star_check_test.dart`, app `platform_star_meter_test.dart`·`star_check_flow_test.dart`, Android `StarPixelsTest.kt`(14개), iOS 이진화 크기 1개 |
| 새 기준 점수 | `regression_test.dart`: 합성 31/35, 합성 ML Kit형 16/18(정확히), 교재 Vision ≥ 55/59, 교재 ML Kit 조각 ≥ 51/59, 채점 칸에 `important` 없음 |
| 기호 잡음 | core `symbol_noise_test.dart`: 합성 6쪽 모든 항목의 표제어·읽기·뜻에 `★☆*＊` 없음, 붙은·단독 기호 5곳의 표제어·읽기가 정답과 같음, 안내 문구 줄은 항목이 아님(35·18개). `page_frame_test.dart`: 자르기 위치, 단독 기호, 안내 문구 줄, ML Kit 낮은 신뢰도, 멱등 |
| 옛 기록 | `OcrScan.fromJson`이 `"star"` 키가 있는(깨진 값도) 옛 기록을 읽고 무시. `EntryField` 이름 목록 5개 |
| 저장 | `migration_test.dart` 5개(7.2절), 계약 테스트는 `Word`에 `important` 없이 InMemory·drift 모두 통과 |
| 앱 | `no_star_marks_test.dart`: 검토 화면(합성 3쪽)·고치기 시트(스위치 없음)·교재 화면·학습 카드에 ★·「기출」 없음, ML Kit형·Vision 캡처 흐름이 파이프라인 결과 그대로 끝남. 인식 어댑터는 `{'path'}`만 보내고 응답의 `"star"`를 무시 |

### 10.4 점수 (★ 칸 없는 기준)

| 세트 | 줄 전체 | 조용한 오류 | 기준 구현과 다른 칸 |
|---|---|---|---|
| 합성 (Vision형, 저장소) | 30/35 → **31/35** | 1 → 1 | 0 |
| 합성 (ML Kit형, 저장소) | 14/18 → **16/18** | 1 → 1 | (기준 출력 없음) |
| 교재 Vision (로컬) | 52/59 → **55/59** | 1 → 1 | 0 |
| 교재 ML Kit 조각 (로컬) | 38/59 → **51/59** | 0 → 0 | (기준 출력 없음) |
| iOS 시뮬레이터 채널 (로컬 사진) | 54/59 → **54/59** | 1 → 1 | — |

- 오른쪽 숫자는 ★만 틀렸던 줄이 맞게 바뀐 만큼만 올랐습니다(칸별 표제어·읽기·품사·뜻·예문 수는 모두 같음). 교재 ML Kit 조각의 앞 숫자 38은 ★ 포함 옛 기준이고,
  6.7절 검사 기록을 재생한 41/59와는 다른 값입니다.
- iOS 채널은 ★ 보조 판독이 ★ 칸만 고쳐 왔으므로 줄 전체가 같습니다. 쪽당 시간은 4.6~6.7초 → 2.7~4.9초(쪽마다 1.6~2.1초 줄어듦, 4절).
- 기준 구현(`parse_eval.py`)과 합성 생성기는 `important` 출력만 뺐고 다른 규칙은 그대로입니다. 합성 `reference_output.json`·정답, 로컬 교재 세트의 `reference_output.json`을 다시 만들었습니다.

### 10.5 화면

iPhone 17 Pro 시뮬레이터에서 합성 샘플 흐름(3절)과 사전 화면(8.3절), 저장 유지(7.4절)를 다시 돌렸습니다. ★가 찍혀 있던 스크린샷만 바꿨습니다:
`03_review_examples`, `05_study_card_covered`, `06_study_card_revealed`, `07_study_retried_card`, `10_review_flags`, `11_entry_editor`(★ 스위치 없음),
`12_review_fixed`, `14_textbook_days`, `15_textbook_memory_levels`, `19_review_candidates`, `20_review_candidate_picked`, `16_textbook_after_restart`.
나머지는 ★가 없어 그대로 두었습니다.

### 10.6 결과

| 항목 | 결과 |
|---|---|
| 정적 분석 | core·storage_drift·jmdict_block·dict_jmdict `dart analyze`, app `flutter analyze` 문제 없음 |
| 테스트 | core 302개(교재 세트 포함 314개), storage_drift 74개, jmdict_block 19개, dict_jmdict 63개, app 79개, Android 단위 11개, iOS RunnerTests 5개 통과 |
| 생성 코드 | `dart run build_runner build --delete-conflicting-outputs`와 스키마 도구를 다시 돌려도 바뀌지 않음, v2 덤프 = 지금 테이블 |
| 빌드 | `flutter build apk --debug` 성공, `python3 tools/synthetic/make_pages.py --check` 통과 |
| 커버리지 | core 97.7%, app 91.6%, storage_drift 손으로 쓴 코드 100%(생성 steps 파일 제외) |
| 코드 줄 수 | 제품 코드(core·storage_drift·app·네이티브·도구) 36개 파일 +150/−1269줄, 테스트 27개 파일 +504/−1178줄 (생성 코드·fixtures 제외) |

## 11. 배포 준비 (2026-11-05)

flavor(dev·prod), release 차단 검사, 충돌 기록, release 서명 자리를 넣었습니다. 구조는 `docs/architecture.md` 5절.

### 11.1 바뀐 명령

| 하려는 것 | 명령 |
|---|---|
| 개발 실행·테스트 (dev, 샘플 있음) | `flutter run`, `flutter test`, `flutter build apk --debug`, `flutter drive …` 그대로 (기본 flavor가 dev). `--flavor dev`를 붙여도 같음 |
| 배포판 모양으로 실행 (샘플 없음) | `flutter run --flavor prod` (debug), `flutter run --flavor prod --release` (사전 asset·서명 필요) |
| 배포 빌드 | `flutter build apk --flavor prod --release`, `flutter build appbundle --flavor prod --release`, `flutter build ios --flavor prod --release` (README "배포 빌드") |
| Android 채널 단위 테스트 | `./gradlew :app:testDevDebugUnitTest` (전: `testDebugUnitTest`) |
| iOS 채널 단위 테스트 | `xcodebuild test … -scheme dev …` (전: `-scheme Runner`) |
| 시뮬레이터·에뮬레이터 앱 지우기 | dev 앱 ID는 `com.nihongoapp.shiori.dev` (`xcrun simctl uninstall <시뮬레이터> com.nihongoapp.shiori.dev`) |

### 11.2 release 빌드 결과

사전 asset은 `tools/dict/build_app_asset.py`로 만든 것을 복사해 썼고, Android 서명은 저장소 밖에 만든 시험용 keystore(유효 1일, 확인 뒤 지움)로 했습니다.

| 명령 | 조건 | 결과 |
|---|---|---|
| `flutter build apk --flavor prod --release` | `key.properties` 없음 | 실패: `preProdReleaseBuild` — `Release signing: android/key.properties is missing. A release is never signed with the debug key. …` |
| 같음 | 시험 키 + 사전 asset | **성공** (105.8MB). `apksigner`: 시험 인증서로 서명됨. 패키지 `com.nihongoapp.shiori` |
| 같음 | 시험 키, 사전 asset 없음 | 실패: `Dictionary asset missing: assets/dict/jmdict-full-lean.sqlite.gz, … Build it with: python3 tools/dict/build_app_asset.py` |
| `flutter build appbundle --flavor prod --release` | 시험 키 + 사전 asset | **성공** (78.1MB), `jarsigner -verify` 통과 |
| `flutter build apk --flavor dev --release` | — | 실패: `preDevReleaseBuild` — `The dev flavor bundles development samples (assets/dev_samples/) and never builds for release. Build with --flavor prod.` |
| `flutter build ios --flavor prod --release --no-codesign` | 사전 asset 없음 | 실패: `assets/dict/jmdict-full-lean.sqlite.gz is missing. …` |
| 같음 | 사전 asset 있음 | **성공** (`Runner.app` 32.4MB), 번들 ID `com.nihongoapp.shiori` |
| `flutter build ios --flavor dev --release --no-codesign` | — | 실패: dev flavor 메시지(위와 같음) |
| 결과물 검사 시험 | pubspec에서 `flavors: [dev]`를 일부러 뺀 채 prod release (확인 뒤 되돌림) | Android `copyFlutterAssetsProdRelease`, iOS "Release bundle check"가 둘 다 `dev_samples`를 찾아 실패 |
| 같은 시험 뒤 pubspec을 되돌리고 다시 prod release | (`flutter clean` 없이) | Android·iOS 모두 결과물 검사에서 실패: 앞 빌드의 `dev_samples`가 빌드 폴더(`intermediates/flutter/prodRelease`, `build/ios/Release-prod-iphoneos`)에 남아 있었음. 그 폴더를 지우고 다시 빌드하니 성공. 메시지에 `flutter clean` 안내를 더함 |

결과물 안의 Flutter asset (`unzip -l`, 앱 번들 `find`):

| 결과물 | `assets/` 아래 | `dev_samples` |
|---|---|---|
| `app-prod-release.apk` | `flutter_assets/assets/dict/jmdict-full-lean.edition.json`, `…sqlite.gz` + `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z`, `NativeAssetsManifest.json`, `fonts/MaterialIcons-Regular.otf`, `shaders/ink_sparkle.frag`, `shaders/stretch_effect.frag` | 0개 |
| `app-prod-release.aab` | `base/assets/flutter_assets/assets/dict/` 두 파일 (나머지는 APK와 같음) | 0개 |
| `Runner.app` (prod release) | `App.framework/flutter_assets/assets/dict/` 두 파일과 `.gitignore`, 나머지는 APK와 같음 | 0개 |
| `app-prod-debug.apk` | — | 0개 |
| `app-dev-debug.apk` (`com.nihongoapp.shiori.dev`) | `flutter_assets/assets/dev_samples/` 합성 4쪽 × 2 | 8개 |

iOS 앱 번들에는 `assets/dict/.gitignore`(71바이트)도 들어갑니다(이번 변경 전부터, Android는 점 파일을 빼서 없음).

### 11.3 테스트

| 묶음 | 파일 | 내용 |
|---|---|---|
| flavor 판단 | `test/features/dev_flavor_test.dart` | `devSamplesEnabledFor`: `dev`만 켜짐, `prod`·없음·`Dev`·`staging`·빈 이름은 꺼짐. 빌드 상수가 `appFlavor` 판단과 같음. prod 설정에서 샘플 판독기가 모든 쪽을 거절. dev 화면에는 "샘플 페이지로 해 보기"와 샘플 쪽이 있고 prod에는 없음 |
| 전역 처리기 | `test/app/crash_reporting_test.dart` | 화면 오류 하나와 비동기 오류 하나가 둘 다 기록되고(출처·글·위치·스택·시각), 원래 처리(오류 표시, `false`)는 그대로. 새 로그 객체로 다시 읽힘, 지우기, 파일 없음, 깨진 줄 건너뜀 |
| 크기 상한 | 같은 파일 | 상한 2000바이트에 40개를 쓰면 파일이 상한 이하이고 가장 새 기록은 남고 순서 유지. 상한보다 큰 기록 하나는 잘려서 남음 |
| 쓰기 실패 | 같은 파일 | 폴더를 못 얻음·폴더 자리가 파일이어도 `record`가 조용히 끝남. 그 상태에서 전역 처리기의 원래 처리도 그대로 |
| 정보 화면 | `test/features/crash_log_screen_test.dart` | 기록 없음 문구, 개인 정보 안내, 최근 것이 위, 복사 버튼이 두 기록을 최근 것부터 클립보드에 넣고 알림, 지우기, 읽기 실패 문구 |
| 기존 테스트 | `test/app/blocks_test.dart` | 첫 블록 목록에 `devSamplesEnabledProvider`·`crashLogProvider` 추가. 화면 테스트 보조(`test/support/harness.dart`)는 flavor와 상관없이 샘플을 켬 |

- `flutter test` 101개 통과(기본 flavor, `--flavor dev` 둘 다). 줄 커버리지 92.2%.
- Android 채널 11개(`testDevDebugUnitTest`), iOS 채널 5개(스킴 `dev`) 그대로 통과. core는 고치지 않았고 302개 통과, 점수표 31/35·16/18 그대로.

### 11.4 시뮬레이터·에뮬레이터

| 기기 | 확인 | 결과 |
|---|---|---|
| iPhone 17 Pro 시뮬레이터 | `flutter drive --flavor dev … flow_screenshots_test.dart` (스크린샷은 저장소 밖에 저장해 기존 그림을 바꾸지 않음) | 통과 (15장) |
| 같음 | `flutter test integration_test/flavor_check_test.dart --flavor prod` / `--flavor dev` | 통과: prod는 샘플 버튼 없음·샘플 asset 못 읽음, dev는 둘 다 있음 |
| 같음 | `flutter drive --flavor dev … crash_log_screenshot_test.dart` | 통과: 실제 전역 처리기로 지어낸 오류 두 개를 앱 지원 폴더에 기록하고 정보 → 오류 기록에 보임. `docs/screenshots/21_about_crash_log.png` |
| Android 에뮬레이터 `Medium_Phone_API_36.1` | `flutter drive --flavor dev … persistence_test.dart --dart-define=SHIORI_PERSISTENCE_STEP=save` | 통과: 합성 샘플 DAY 20 → 저장 6개 → 학습 |
| 같음 | `flavor_check_test.dart --flavor prod` / `--flavor dev` | 통과 |
| 같음 | `flow_screenshots_test.dart` | 실패: Android에서 `takeScreenshot` 전에 `convertFlutterSurfaceToImage()`가 필요함(스크린샷 테스트는 원래 iOS 시뮬레이터용, 이번 변경과 무관) |

## 12. 형용사 배지 오독, な형용사 「だ」, 여분 항목 집계 (2026-11-05)

실기기(iPhone)로 찍은 교재 한 쪽에서 나온 문제 중 해석기의 가로줄 배정과 상관없는 세 가지를 고쳤습니다.
기울어지고 휜 쪽에서 오른쪽 칸이 다음 행으로 밀리는 문제(쪽 전체에 기울기 하나, 옆 쪽 번호가 섞인 행 간격)는 이번에 고치지 않았습니다.

### 12.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 형용사 배지 오독 | `packages/core/lib/src/capture/vocab/fields.dart` | 한국어 판독이 い형을 `니형`, な형을 `⅓형`·`⅛형`(NFKC 뒤 `1⁄3형`·`1⁄8형`)으로 읽은 것을 배지로 받아 품사를 붙이고 뜻에서 뗍니다. 바로 뒤가 「형」이 아니면(`니트 …`, `1⁄3 정도`) 배지로 보지 않습니다 |
| な형용사 「だ」 | `packages/dict_jmdict/lib/src/spelling.dart` | 사전 대조에서 떼는 어미에 `だ`를 더했습니다(`静かだ`【しずかだ】 → `静か`【しずか】, 읽기 없음도 같음). 한자가 없는 표제어(`ただ`, `まだ`)는 떼지 않습니다. 앱이 타는 사전 블록 경로도 같은 결과입니다 |
| 여분 항목 집계 | `packages/core/lib/src/eval/capture_scorer.dart`, `tool/eval_capture.dart` | 채점기는 같은 번호가 여러 번 나오면 나중 것만 채점해서, 번호가 겹치거나 정답에 없는 항목이 점수에 드러나지 않았습니다. 쪽마다 항목 수와 여분(같은 번호의 앞 항목 `DUP`, 정답에 없는 번호·번호 없음 `EXTRA`)을 따로 셉니다. 기존 점수와 표는 그대로이고, 도구는 표 뒤에 전체·쪽별 여분을 적습니다 |

### 12.2 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/capture/vocab_fields_test.dart` | `니형 바쁘다` → い형, `⅓형`·`1⁄3형`·`⅛형`·`1⁄8형` → な형, 뜻에 배지 글자가 남지 않음, 기존 배지 그대로, `니트 짜기`·`1⁄3 정도` 같은 뜻은 품사 없음 |
| `packages/core/test/capture/capture_pipeline_test.dart` | 합성 쪽의 배지 줄을 `⅓형 …`(NFKC 전 글자)·`니형 …`으로 바꿔 넣으면 파이프라인 결과가 な형·い형 |
| `packages/core/test/capture/capture_scorer_test.dart` | 중복 번호·정답에 없는 번호·번호 없음을 여분으로 셈, 중복은 나중 항목을 채점, 여분 0이면 점수와 표가 그대로 |
| `packages/core/test/tool/eval_capture_tool_test.dart` | 도구 출력에 쪽별·전체 여분, `--verbose`에 `EXTRA` 줄 |
| `packages/core/test/capture/regression_test.dart` | 합성 세트, 합성 ML Kit형, 교재 세트의 여분 0 |
| `packages/dict_jmdict/test/text_rules_test.dart`, `pair_test.dart` | `stripAffixes`·`checkPair`의 `だ` 처리, 한자 없는 단어는 그대로 |
| `packages/jmdict_block/test/adapter_test.dart` | 어댑터에서 `静かだ`【しずかだ】가 사전에 있는 단어 |

### 12.3 점수

| 세트 | 줄 | 여분 |
|---|---|---|
| 합성 (4쪽 35단어) | 31/35 (그대로) | 0 |
| 합성, ML Kit형 | 16/18 (그대로) | 0 |
| 교재 세트, Vision (로컬) | 55/59 (그대로) | 0 |
| 교재 세트, ML Kit 조각 (로컬) | 51/59 (그대로) | 0 |
| 교재 세트, 쪽 잘라 펴기 (로컬) | 48/59 (그대로) | 2 (한 쪽에서 번호를 잘못 읽은 두 항목) |
| 실기기 촬영 1쪽 15단어, 시뮬레이터 Vision 재판독 (로컬) | 6/15 (그대로, 품사 11 → 12) | 3 (밀린 읽기로 생긴 번호 중복 2, 마지막 번호 다음 1) |

- 기준 구현과 다른 칸: 합성·교재 세트 모두 0개(`tool/reference_diff.dart`).
- 실기기 쪽은 줄 밀림이 그대로라 배지 줄이 버려지는 행이 있어 품사가 하나만 늘었습니다. 사전을 켜면 な형용사 표제어 한 개의 「사전에 없음」이 사라집니다(오탐 2 → 1, 남은 하나는 밀린 읽기 때문).

## 13. 범용 추출 (배치에 기대지 않는 단어 추출, 2026-11-05)

가로줄 틀 해석기 옆에 **범용 추출기**를 새 모듈로 두었습니다(설계: `docs/extraction.md`). 앱 화면·저장소·학습 코드와 가로줄 틀 코드는 바꾸지 않았습니다.

### 13.1 바꾼 것

| 항목 | 위치 |
|---|---|
| 추출기 | `packages/core/lib/src/extract/**` (조각 수집·분류, 활용 되돌리기, lattice 분할, 한자음 대조, 헝가리안 배정, 결과 모델), 공개: `shiori_core.dart` |
| 새 포트 `Lexicon` | `packages/core/lib/src/ports/lexicon.dart` (메모리 블록 `InMemoryLexicon` 포함). 기존 `Dictionary` 포트는 그대로 |
| JMdict 일괄 조회 | `packages/dict_jmdict/lib/src/form_lookup.dart` (`JmdictDictionary.lookupForms`), 어댑터 `packages/jmdict_block/lib/src/jmdict_lexicon_adapter.dart` |
| 채점기 | `packages/core/lib/src/eval/extract_truth.dart`, `extract_scorer.dart` (표제어 기준, 가로줄 틀도 같은 잣대) |
| 도구 | `packages/core/tool/eval_extract.dart`, `packages/jmdict_block/tool/eval_extract_dict.dart`, `tools/extract/build_extract_data.py`, `tools/extract/convert_truth.py`, `tools/synthetic/make_general_pages.py` |
| 외부 데이터 | `packages/core/third_party/jl/` (활용 되돌리기 규칙, Apache-2.0), `packages/core/third_party/unihan/` (한국 한자음, Unicode License v3) — 앱 정보 화면 표기는 앱 연결 단계에서 |
| 합성 범용 세트 | `packages/core/test/fixtures/synthetic_general/` (5쪽, 지어낸 내용만) |

### 13.2 테스트

| 패키지 | 결과 |
|---|---|
| core | **381개 통과**, 교재 세트 11개 건너뜀 (`SHIORI_PRIVATE_DIR` 지정 시 394개 통과). 새 테스트: `test/extract/**`(조각 수집·원형화·lattice·헝가리안·짝짓기·문장 단어·합성 세트·채점기·결과 모델·한자음·메모리 사전), `test/tool/eval_extract_tool_test.dart` |
| dict_jmdict | **72개 통과** (`form_lookup_test.dart` 6개 추가) |
| jmdict_block | **23개 통과** (`lexicon_adapter_test.dart` 3개 추가) |
| app | `flutter analyze` 문제 없음, `flutter test` **101개 통과**, `flutter build apk --debug --flavor dev` 성공 |
| 기존 회귀 | 합성 31/35, 합성 ML Kit형 16/18, 교재 Vision 55/59, 교재 ML Kit 조각 51/59, 기준 구현과 다른 칸 0 (그대로) |

### 13.3 비교표 (표제어 기준 채점, 쪽당 시간은 데스크톱 Dart VM)

범용은 실제 JMdict(`full-lean`, 2026-11-04)를 붙인 결과, 가로줄 틀은 `CapturePipeline.standard`(JMdict)입니다. 읽기·뜻은 찾은 단어 중에서 셉니다.
문장 단어는 재현율 / 정밀도. 교재 쪽은 숫자만 적습니다(로컬 전용 세트).

| 세트 | 방식 | 찾음 | 읽기 | 뜻 | 문장 단어 | 여분 | 높음인데 틀림 | ms/쪽 |
|---|---|---|---|---|---|---|---|---|
| 합성 기존 (4쪽 35단어) | 틀 | 33/35 | 33/33 | 31/33 | - | 1 (+중복 1) | - | 18 |
| | 범용 | 27/35 | 27/27 | 19/27 | - | 28 | 0 | 81 |
| 합성 범용 (5쪽 46단어, 문장 단어 39) | 틀 | 15/46 | 13/15 | 8/15 | 0/39 | 1 (+중복 2) | - | 13~32 |
| | 범용 | **46/46** | **46/46** | **45/46** | **39/39 / 32/32** | 1 | 0 | 37~117 |
| 　└ 박스형 g01 | 틀 / 범용 | 0/14 / 14/14 | - / 14 | - / 14 | 0/9 / 9/9 | | | |
| 　└ 문장 위주 g02 | 틀 / 범용 | - | - | - | 0/19 / 19/19 | | | |
| 　└ 읽기 없는 목록 g03 | 틀 / 범용 | 0/10 / 10/10 | - / 10 | - / 10 | | | | |
| 　└ 휜 단어장 g04 | 틀 / 범용 | 15/15 / 15/15 | 13 / 15 | 8 / 14 | | | | |
| 　└ 옆 칸 인라인 g05 | 틀 / 범용 | 0/7 / 7/7 | - / 7 | - / 7 | 0/11 / 11/11 | | | |
| 교재 단어장 5쪽 (59단어, 로컬) | 틀 | 57/59 | 57/57 | 55/57 | - | 1 (+중복 1) | - | 14 |
| | 범용 | 56/59 | 56/56 | 48/56 | - | 16 | 0 | 56~62 |
| 실기기 촬영 휜 쪽 1쪽 (15단어, 로컬) | 틀 | 13/15 | 9/13 | 7/13 | - | 3 (+중복 2) | - | 62 |
| | 범용 | 13/15 | **13/13** | **12/13** | - | 3 | 0 | 81~103 |
| 다른 교재 3쪽 (15단어, 문장 단어 33, 로컬, 정답 초안) | 틀 | 0/15 | - | - | 0/33 | 0 | - | 11 |
| | 범용 | **15/15** | **15/15** | **11/15** | **30/33 / 29/62** | 35 | 0 | 80~115 |

- 사전 없이(메모리 사전도 없이) 돌린 범용 추출: 합성 범용 46/46·읽기 36/46·뜻 43/46·문장 단어 7/39, 교재 5쪽 50/59·46/50·40/50.
  합성 범용 세트의 메모리 사전(`lexicon.json`)으로는 46/46·46/46·46/46·39/39, 여분 0.
- 한국어 뜻 조회 흉내(`korean_glosses.json`, 고유어 11개)를 붙여도 높음은 0개입니다. 뜻 짝이 높음이 되려면 한자음과 뜻 조회가 함께 맞아야 하는데,
  흉내 표에는 고유어만 있어 한자음과 겹치지 않습니다. 한자어까지 담은 한국어 뜻 사전이 붙으면 한자어 단어부터 높음이 생깁니다.
- 합성 기존 세트에서 범용이 낮은 것은 그 쪽들이 가로줄 틀의 보정 규칙(헷갈리는 가타카나, 못 읽은 표제어, 예문 상자)을 시험하려고 일부러 망가뜨린 판독이기 때문입니다.
- 다른 교재 쪽의 여분 35개 대부분은 한국어 설명 단락 속 일본어를 일본어 패스가 엉터리로 읽은 조각입니다(`docs/extraction.md` 8절).

## 14. 한국어 뜻 사전 (한국어기초사전 역색인, 2026-11-05)

자세한 규칙·측정은 docs/dictionary.md 11절입니다.

### 14.1 바꾼 것

| 무엇 | 어디 | 내용 |
|---|---|---|
| 데이터 빌드 | `tools/dict/build_ko_glossary.py` | 기초사전 JSON zip → SQLite(lean/full) + gzip + 판 정보 JSON. 원본은 인자로 받고 내려받지 않음 |
| 포트 | `packages/core/lib/src/ports/korean_glossary.dart` | `KoreanGlossary`, `KoreanSense`, `GlossarySourceInfo`, `EmptyKoreanGlossary` |
| 블록 | `packages/krdict_block` | `KrdictGlossary` (SQLite 읽기 전용, 스키마 1), 키 정규화 `pairKey`, 측정 도구 `tool/measure_glossary.dart` |
| 보정기 | `packages/core/lib/src/capture/correctors/korean_meaning_filler.dart` | 빈 뜻 칸만 1순위 뜻으로 채움(`meaning:inferred`). glossary를 줄 때만 체인에 들어감 |
| 앱 | `app/lib/adapters/bundled_glossary.dart`, `unpacked_asset.dart`(JMdict와 공용), `app/lib/app/blocks.dart`, `startup.dart`, `main.dart` | asset 풀기·열기, `koreanGlossaryProvider`, 데이터가 없으면 체인에 채우기 없음 |
| 캡처 | `app/lib/features/capture/capture_controller.dart` | 두 사전이 열린 뒤 체인을 만듦(첫 페이지도 사전을 씀. 전에는 JMdict도 첫 페이지에서 빠질 수 있었음) |
| 정보 화면 | `app/lib/features/about/about_screen.dart` | 「한국어 뜻 사전」 카드, 라이선스 페이지 `한국어기초사전` 항목 |
| release 차단 | `app/android/app/build.gradle.kts`, `app/ios/Runner.xcodeproj/project.pbxproj` | `ko-glossary.sqlite.gz`·`ko-glossary.edition.json`이 없으면 실패 |

### 14.2 점수 (보정기 켬, 실제 asset)

| 세트 | 줄 | 뜻 | 여분 |
|---|---|---|---|
| 합성 (4쪽 35단어) | 31 → **32/35** | 33 → 34 (빈 뜻 1개가 맞게 채워짐) | 0 |
| 합성, ML Kit형 | 16/18 (그대로, 빈 뜻 없음) | 17/18 | 0 |
| 교재 세트, Vision (로컬) | 55 → **56/59** | 57 → 58 (빈 뜻 1개가 맞게 채워짐) | 0 |
| 교재 세트, ML Kit 조각 (로컬) | 51/59 (그대로, 빈 뜻 없음) | 58/59 | 0 |

- 보정기를 끈 기준 체인(`standardCorrectors(dictionary)`)의 점수와 기준 구현과 다른 칸 0개는 그대로입니다.
- 모든 표제어에 지어낸 뜻을 답하는 사전으로도 합성 두 세트의 점수가 그대로입니다(사진에서 읽은 뜻을 바꾸지 않음, `korean_meaning_regression_test.dart`).

### 14.3 빌드와 화면

| 명령 | 조건 | 결과 |
|---|---|---|
| `flutter build apk --debug --flavor dev` | — | 성공 (`app-dev-debug.apk`, 198 MB) |
| `flutter build ios --flavor prod --release --no-codesign` | JMdict asset만 있음 | 실패: `assets/dict/ko-glossary.sqlite.gz is missing. Build it with: python3 tools/dict/build_ko_glossary.py --source <krdict JSON zip>` |
| `flutter build apk --flavor prod --release` | 같음 | 실패: `preProdReleaseBuild` — `Dictionary asset missing: assets/dict/ko-glossary.sqlite.gz, assets/dict/ko-glossary.edition.json. …` |
| `flutter build ios --flavor prod --release --no-codesign` | 두 사전 asset 있음 | **성공** (`Runner.app` 36.1 MB, `assets/dict/`에 네 파일, `dev_samples` 0개) |

`flutter drive -d <iPhone 17 Pro> --driver=test_driver/integration_test.dart --target=integration_test/glossary_screenshots_test.dart` (합성 샘플만):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `22_about_glossary.png` | 정보: 한국어 뜻 사전 카드, 출처 문구, 라이선스·사전 링크, 판 2026-10-19 |
| `23_review_glossary_meaning.png` | 검토: 11쪽 0022 鼻의 빈 뜻 칸이 「코」로 채워지고 「추정」 표시 |

### 14.4 테스트

| 파일 | 내용 |
|---|---|
| `tools/dict/test_build_ko_glossary.py`, `test_build_ko_glossary_extra.py` | 대역어 나누기(짝·가나·`・` 대안·오기 괄호·꼬리 끝말), `(対訳語無し)`·다른 언어·단어 아닌 항목 제외, 등급·뜻 번호·유의어, lean/full, 같은 원본 같은 바이트, zip·폴더 읽기 순서, 판 정보 JSON(출처·판 날짜·라이선스·sha256), 테스트 DB가 견본에서 만든 것과 같음 |
| `tools/dict/testdata/ko_glossary_keys.json`, `ko_glossary_keys_extra.json` | 키 정규화 시험 표 30줄. Python과 Dart 테스트가 같은 표를 읽음 |
| `packages/krdict_block/test/lookup_test.dart` | 읽기+한자 함께 맞추기(食堂/食道), だ·する, 한자 없는 だ, 순위(자리 → 등급 → 뜻 번호), 다의어 묶음과 `limit`, 가나 표제어의 가나 대역어 먼저 |
| `packages/krdict_block/test/open_test.dart`, `keys_test.dart`, `keys_extra_test.dart`, `ranking_extra_test.dart` | 없는 파일·다른 스키마·테이블 없음·SQLite 아님은 열기 거부, 닫은 뒤 조회 오류, 출처 문구; 끝말 일치 순위, `お`·`ご` 떼고 다시 찾기 |
| `packages/core/test/capture/korean_meaning_filler_test.dart`, `korean_meaning_filler_extra_test.dart` | 빈 뜻만 채움(`meaning:inferred`), 읽은 뜻·잘린 뜻은 그대로, 사전 없음·「사전에 없음」·표제어 없음은 채우지 않음, 체인 자리, 조회가 실패하면 비워 둠 |
| `packages/core/test/capture/korean_meaning_regression_test.dart` | 모든 단어에 지어낸 뜻을 답해도 합성 두 세트 점수 그대로, 기준 구현과 다른 칸은 빈 뜻 1칸뿐; 鼻 → 코면 합성 뜻 34/35·줄 32/35 |
| `app/test/adapters/bundled_glossary_test.dart`, `app/test/app/glossary_slot_test.dart` | asset 없음·DB 아님·판 정보 이상은 빈 사전, 첫 실행 풀기, 같은 판 다시 안 풂, 체인에 채우기가 들어감/빠짐 |
| `app/test/features/about_glossary_test.dart`, `review_glossary_test.dart` | 정보 화면 출처 문구·판 날짜·라이선스 링크, 라이선스 페이지 항목; 검토 화면에서 鼻의 빈 뜻이 「코」+「추정」 |

결과: core 337개 통과(교재 세트 포함 350개), 사전 블록 74개, Python 33개, app 113개 통과.

## 15. 범용 추출 앱 연결: 경로 선택, 한국어 뜻 사전, 여분 거르기, 검토 화면 (2026-11-06)

설계는 `docs/extraction.md` 8~10절입니다. 가로줄 틀 해석 규칙(`capture/vocab/**`)과 저장 스키마·`packages/storage_drift`는 바꾸지 않았습니다.

### 15.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 경로 선택 | `packages/core/lib/src/capture/capture_router.dart`, `models/capture_route.dart` | 쪽마다 틀의 원본 행(보정 전)을 재서(`TemplateFit`) 모든 검사를 통과하면 틀, 아니면 범용(`chooseRoute`, 기준은 extraction.md 9절). 결과와 이유는 `CaptureDraft.route`. `CapturePipeline`은 `attempt`(틀 나누기)와 `finish`(보정기)로 나눔(결과 같음) |
| 한국어 뜻 사전 연결 | `extract/general_extractor.dart` | `GeneralExtractor(koreanGlossary:)`: 짝짓기 근거 + 사진에 뜻이 없는 사전 낱말의 1순위 뜻(출처 사전, 중간) + 다른 뜻 묶음은 후보 |
| 헷갈리는 글자 | 같은 곳 | 사전에 없는 한자어 안 외톨이 가타카나를 한자로 바꾼 표기가 사전에 있을 때만(`人ロ` → `人口`, 「글자 보정+사전」) |
| 여분 거르기 | `extract/fragment.dart`, `fragment_collector.dart`, `general_extractor.dart` | 기기 채널의 32비트 0.3 비교, 한국어 설명 단락 속 일본어, 문형 줄, 괄호 읽기, 가나 한 글자, 따로 읽힌 □ 상자로 체크박스 열, 글자 폭 기준 열 허용폭 |
| 검토 근거 | `models/evidence.dart`, `capture/evidence_edits.dart`, `CapturedEntry.evidence` | 칸별 출처·짝 신뢰도·사진 좌표 상자·후보, 후보 고르기·조각 붙이기·새 항목·높음 전체 승인. 저장하지 않음 |
| 이미 있는 단어 | `CaptureRouter.fromScan(lookupKnown:)`, `app/lib/features/capture/capture_controller.dart` | 범용 쪽에서만 라이브러리 `words()`(숨긴 단어 포함)의 표제어를 건너뛰고 `CaptureDraft.skippedKnown`에 남김 |
| 앱 연결 | `app/lib/app/blocks.dart` | `lexiconProvider`, `generalExtractorProvider`, `captureRouterProvider`, `highConfidenceApprovalProvider`(켬) |
| 검토 화면 | `app/lib/features/capture/evidence_tile.dart`, `evidence_view.dart`, `fragment_tray.dart`, `review_screen.dart` | 출처 배지(사진/사전/번역), 짝 신뢰도 3단계(글자·색·화면 읽기 라벨), 칸을 누르면 근거 조각(사진을 세운 뒤 잘라 보기, 사진이 없으면 판독 기록으로 그린 쪽), 낮음·중간 칸의 후보 칩, 짝 없는 조각 보관함(칸에 붙이기·새 단어), 문장 단어의 예문, 요약의 경로·건너뛴 수, "높음 전체 승인" |
| 사진 보관 | `capture_controller.dart` | 판독 뒤 임시 사진 파일은 그대로 지우고, 근거 조각용으로 바이트만 메모리에(24MiB 초과는 안 둠). 잘라 보기는 긴 변 2048px로 줄여 풂 |
| 출처 표기 | `app/lib/features/about/about_screen.dart`, `extract_licenses.dart` | 정보 화면 「단어 추출 데이터」 카드, 라이선스 페이지 `JL deconjugation rules`(Apache-2.0)·`Unihan`(Unicode License v3) |
| 개발 샘플 | `app/assets/dev_samples/g01.*`, `g06.*` (`generalDevSamples`) | 합성 범용 쪽 2개(코어 사본과 같음) |
| 합성 세트 | `tools/synthetic/make_general_pages.py` | g06(한국어 설명 단락, 문형 줄, `人ロ`) 추가. 메모리 사전 125항목 |
| 평가 도구 | `packages/core/tool/eval_extract.dart`, `packages/jmdict_block/tool/eval_extract_dict.dart` | `--routed`, `--glossary` |

### 15.2 경로 선택 결과

| 세트 | 경로 |
|---|---|
| 합성 s010·s011·s140·s147, ML Kit형 m011·m140 | 틀 (모두) |
| 합성 범용 g01·g02·g03·g05·g06 | 범용 (단어장 번호 줄 없음) |
| 합성 범용 g04 (휜 단어장) | 범용 (번호 겹침 2, 빈 뜻 7/18, 빈 읽기 2/18) |
| 교재 단어장 5쪽 Vision·ML Kit 조각 (로컬) | 틀 (모두) |
| 실기기 촬영 휜 쪽 1쪽 (로컬) | 범용 (번호 겹침 2, 빈 뜻 6/18, 빈 읽기 3/18) |
| 다른 교재 3쪽 (로컬) | 범용 (번호 줄 없음) |
| (참고) 교재 쪽 잘라 펴기 5쪽 (로컬) | 틀 4, 범용 1 (번호 순서 0.33·빈 읽기 2/6인 쪽) |

틀로 간 쪽은 `CapturePipeline`의 결과와 같습니다(`route_selection_test`): 줄 점수 합성 31/35(한국어 뜻 채움 32/35), ML Kit형 16/18,
교재 Vision 55/59(채움 56/59), ML Kit 조각 51/59, 기준 구현과 다른 칸 0, 여분 0 — 모두 그대로입니다.

### 15.3 비교표 (표제어 기준, 실제 JMdict, 「한국어 뜻」 열은 한국어 뜻 사전을 붙인 경로 선택 결과)

쪽당 시간은 데스크톱 Dart VM, 경로 선택(틀 나누기 + 그 경로) 전체입니다. 교재 쪽은 숫자만 적습니다.

| 세트 | 경로 선택 결과 | 찾음 | 읽기 | 뜻 | 한국어 뜻 사전 붙임: 뜻 | 문장 단어 | 여분 | 높음 (사전 붙임) | 높음인데 틀림 | ms/쪽 |
|---|---|---|---|---|---|---|---|---|---|---|
| 합성 기존 4쪽 (35단어) | 틀 | 33/35 | 33/33 | 31/33 | 32/33 | - | 1 (+중복 1) | 0 | 0 | 2~3 |
| 합성 ML Kit형 2쪽 (18단어) | 틀 | 17/18 | 17/17 | 16/17 | 16/17 | - | 1 | 0 | 0 | 3 |
| 합성 범용 6쪽 (49단어, 문장 단어 45) | 범용 | **49/49** | **49/49** | 47/48 | **48/48** | **45/45 / 38/38** | 1 → 사전 붙임 0 | 1 (8) | 0 | 16~17 |
| 　└ 그중 13절의 5쪽 | 범용 | 46/46 | 46/46 | 45/46 | 46/46 | 39/39 | 0 | | 0 | |
| 교재 단어장 5쪽 (59단어, 로컬) | 틀 | 57/59 | 57/57 | 55/57 | 56/57 | - | 1 (+중복 1) | 0 | 0 | 2 |
| 실기기 촬영 휜 쪽 1쪽 (15단어, 로컬) | 범용 | 13/15 | 13/13 | 12/13 | **14/14** (찾음 14/15) | - | 2 → 1 | 0 | 0 | 22 |
| 다른 교재 3쪽 (15단어, 문장 단어 33, 로컬) | 범용 | **15/15** | **15/15** | 11/15 | 11/15 | 30/33 / 29/33 | **4** (13절 35) | 0 (2) | 0 | 42~48 |

- 높음 수는 검토 화면과 같은 기준(`EntryEvidence`: 뜻이 없으면 높음이 아님)으로 셉니다.
- **"높음 전체 승인"은 켰습니다**(`highConfidenceApprovalProvider`): 합성 세트 전부(기존·ML Kit형·범용, 메모리 사전·한국어 뜻 흉내·한자음 낱말을 더한 흉내)와
  로컬 세트 전부(실제 JMdict·한국어 뜻 사전)에서 높음인데 틀린 항목이 0입니다. 다만 높음은 적습니다: 합성 범용 8, 다른 교재 2, 단어장·휜 쪽 0.
  읽기 짝이 높음이 되는 것은 인라인 괄호뿐이라(4.4절) 높음 항목은 `漢字(かな)` + 한자음 뜻 쪽에 몰립니다.
- **여분 35 → 4**(다른 교재 3쪽): 32비트 0.3 비교를 고친 것만으로 35 → 19, 단락·문형·괄호 읽기·가나 한 글자 거르기로 19 → 4.
  남은 4개는 문장 속 활용형의 명사 오분할 1, 짧은 문장의 기능어 1, `*`로 시작하는 보충 줄의 낱말 2입니다.
- **헷갈리는 글자 보정:** 합성 g06의 `人ロ` → `人口`(뜻 「인구」, 사전에 없으면 그대로). 합성 기존 4쪽을 범용으로 돌리면 찾음 27 → 28, 여분 28 → 19(보정과 거르기를 합친 효과).
- **한국어 뜻 사전 효과(범용 단독):** 합성 기존 4쪽 뜻 20/28 → 25/28, ML Kit형 11/16 → 14/16, 휜 쪽 12/13 → 14/14(찾음 13 → 14),
  합성 범용 47/48 → 48/48·높음 1 → 8, 다른 교재 높음 0 → 2. 교재 단어장 5쪽은 48/56 → 47/56(사전 1순위 뜻이 교재 뜻과 다른 1개).
- **범용이 단어장에서 틀을 따라잡았는가:** 아직 아닙니다. 교재 단어장 5쪽에서 범용(+한국어 뜻 사전)은 찾음 56/59·뜻 47/56, 틀은 57/59·55/57입니다.
  틀에는 품사 배지·예문 상자 같은 단어장 전용 보정이 있고 범용에는 없습니다. 틀이 맞는 쪽은 계속 틀로 읽습니다.

### 15.4 테스트 (E1~E11)

| 파일 | 내용 |
|---|---|
| `packages/core/test/capture/route_selection_test.dart` | E1 쪽별 경로·이유, 판정 함수의 검사별 이유, E2 틀 쪽은 파이프라인과 같은 결과, 합성 범용 5쪽 46/46·46/46·45 이상·39/39 (로컬: 교재 5쪽·ML Kit 틀, 휜 쪽·다른 교재 범용) |
| `packages/core/test/extract/korean_glossary_link_test.dart` | E3 運動↔운동 높음, 食べる↔먹다 중간 이상, 部屋 → 방(출처 사전), 다의어 1순위 뜻·2순위 후보, 사전 없음·조회 실패 |
| `packages/core/test/extract/glyph_fix_test.dart` | E4 g06 `人ロ` → `人口`(근거), 사전에 없으면 그대로, 사전에 있는 `カ月`은 그대로 |
| `packages/core/test/extract/high_confidence_test.dart` | E5 합성 전 세트 높음인데 틀림 0, 높음 항목은 짝 칸이 모두 높음 |
| `packages/core/test/extract/paragraph_noise_test.dart` | E6 g06 여분 0, 단락 속 `学校[がっこう]`는 남음, 다른 쪽 점수 그대로, 괄호 읽기·가나 한 글자 |
| `packages/core/test/extract/known_words_test.dart` | E7 이미 있는 단어 건너뜀·한 번만 셈, 틀 쪽은 거르지 않음 |
| `packages/core/test/library/general_save_test.dart` | E9 범용 결과 저장: 표제어·읽기·품사·뜻·예문, 번호 없는 항목도 각자 id |
| `packages/core/test/extract/previous_holds_test.dart` | E10 `丈夫だ`/`丈夫` 한 항목, 체크박스 열의 `ロッカー`(1단·2단), `あした/あす`, 가타카나 단어, 세로 사진의 상자 열 |
| `packages/core/test/capture/evidence_edits_test.dart` | E8(core) 후보 고르기·조각 붙이기·새 항목·높음 전체 승인·상자 자르기 |
| `packages/jmdict_block/test/routed_capture_local_test.dart` | 로컬·실제 사전: E2 휜 쪽, E5 전 세트 높음인데 틀림 0, E6 다른 교재 여분 10 이하 |
| `app/test/features/general_review_test.dart` | E8 출처 배지, 신뢰도 3단계와 화면 읽기 라벨, 근거 조각 화면, 후보 칩, 보관함(칸에 붙이기·새 항목), 문장 단어 예문, 높음 전체 승인(스위치) |
| `app/test/features/general_capture_test.dart` | 범용 개발 샘플(코어 사본과 같음), 범용 경로로 검토 화면, 라이브러리에 있는 단어 건너뜀 요약 |
| `app/test/features/about_extract_credits_test.dart` | E11 정보 화면·라이선스 페이지의 JL·Unihan |

### 15.5 시뮬레이터 (iPhone 17, 합성 샘플만)

`flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/general_review_screenshots_test.dart`

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `28_capture_general_samples.png` | 등록: 범용 샘플 쪽 |
| `29_review_general.png` | 검토: 경로 요약, 출처 배지, 짝 신뢰도 3단계 |
| `30_review_general_evidence.png` | 근거 조각(판독 기록으로 그린 쪽에서 잘라 보기) |
| `31_review_general_tray.png` | 짝 없는 조각 보관함 |
| `32_about_extract_credits.png` | 정보: 단어 추출 데이터(JL·Unihan) |
| `33_home_after_general_save.png` | 저장 뒤 홈 |
## 16. 아는 단어 숨기기 「이미 알아요」 (저장 스키마 v3, 2026-11-06)

사진의 문장에서 나온 단어가 모두 단어장에 들어오면 이미 아는 쉬운 단어도 섞입니다. 그런 단어를 한 번 눌러 학습과 목록에서 빼는 상태를 더했습니다.
학습 카드의 「알고있음」(다음 복습을 미루는 답 버튼)과는 다른 동작이고, 그 버튼과 「다시 학습」은 그대로입니다.

### 16.1 설계

- **숨김 상태는 단어에 둡니다** — `Word.hiddenAt`(숨긴 시각, 보일 때 null)과 `isHidden`, 저장은 `words.hidden_at`(UTC epoch 마이크로초, NULL 가능).
  따로 표를 두지 않은 이유: `words()` 한 번으로 숨김 여부까지 읽혀야 하고(사진에서 다시 들어온 표제어를 거르는 쪽이 이 조회를 씀), 교재별 집계도 같은 `textbooks LEFT JOIN words` 쿼리에서
  `COUNT(hidden_at)` 하나로 끝납니다. 표를 나누면 모든 조회에 조인이 붙고, 단어 없이 숨김 행만 남는 경우를 따로 막아야 합니다.
- **숨김은 내용이 아닙니다.** `saveWords`는 숨김을 바꾸지 않습니다: 이미 있는 단어는 저장된 숨김을 지키고(drift는 `ON CONFLICT DO UPDATE`의 SET에서 `hidden_at`을 뺌),
  새 단어는 `Word.hiddenAt`이 무엇이든 보이는 상태로 들어갑니다. 그래서 같은 쪽을 다시 찍어 저장해도 숨긴 단어가 되살아나지 않습니다.
- **포트 `HiddenWordRepository`**(`packages/core/lib/src/ports/hidden_word_repository.dart`): `hideWords(ids, at:)`, `unhideWords(ids)`, `hiddenWords({textbookId})`.
  - 모두 또는 하나도 안 함: 없는 단어 ID가 하나라도 있으면 `WordNotFoundException(ids)`을 던지고 아무것도 바꾸지 않습니다(조용히 넘어가지 않음). drift는 확인과 쓰기를 트랜잭션 하나로 합니다.
  - 두 번 숨겨도 처음 숨긴 시각이 남습니다. 숨기지 않은 단어를 되살리는 것은 아무 일도 하지 않습니다. ID는 500개씩 나눠 `IN`으로 묻습니다.
  - `LibraryRepository`에 메서드를 더하지 않고 따로 둔 이유: 그 포트를 구현한 블록·테스트용 대역이 여럿이라 포트를 넓히면 모두 고쳐야 합니다. 기본 블록 둘(`InMemoryLibraryRepository`, `DriftLibraryRepository`)이 두 포트를 함께 구현하고,
    `StudyService`·`LibraryService`는 `hidden:`을 주지 않으면 서재 블록에서 꺼냅니다(숨길 수 없는 블록이면 숨기기는 `StateError`).
- **숨겨도 학습 기록은 그대로입니다.** 카드(단계·다음 복습 시각·횟수)와 누른 기록을 지우거나 바꾸지 않습니다. 되살리면 같은 카드로 세션에 돌아옵니다.
- **읽기:** `words()`·`word()`는 숨긴 단어도 돌려줍니다(`isHidden`으로 구분). `textbookStats()`의 `wordCount`·`days`는 숨긴 단어까지 세고 `hiddenCount`가 그중 숨긴 수입니다(`shownCount` = 뺀 수).
- **학습:** `SessionBuilder`가 숨긴 단어를 뺍니다(복습 예정·새 단어 모두, 목표 장수 자리도 차지하지 않음). `StudySummary`의 `dueCount`·`newCount`에서 빠지고 `hiddenCount`로 따로 셉니다.
  `wordCount`는 숨긴 단어까지 셉니다(모두 숨겼을 때 홈이 "먼저 교재 페이지를 등록해 주세요"로 잘못 안내하지 않게). 숨기기 전에 누른 「알고있음」은 오늘 외운 수에 그대로 남습니다.
- **세션:** `StudyService.hide(session)`은 지금 카드의 단어를 숨기고 다음 카드를 돌려줍니다(카드·기록은 쓰지 않음, 세션 장수 −1). `unhide(session, item)`은 그 카드를 맨 앞으로 되돌립니다(장수 +1, 끝난 세션이면 다시 엶).

### 16.2 스키마 v3와 마이그레이션

- `schemaVersion` 2 → 3. v2 → v3 단계는 `ALTER TABLE words ADD COLUMN hidden_at INTEGER NULL` 하나(`Migrator.addColumn`)라 행을 옮기지 않고, 모든 단어가 "안 숨김"으로 시작합니다.
  v1 파일은 v1 → v2 → v3를 차례로 밟고, 모든 단계가 트랜잭션 하나라 중간에 실패하면 옛 파일이 그대로 남습니다.
- 덤프 `drift_schema_v3.json`, 단계 파일 `database.steps.dart`(`Schema3`), 테스트 도우미 `test/migrations/generated/schema_v3.dart`를 생성 도구로 만들었습니다.
  `dart run drift_dev make-migrations`는 `test/migrations/shiori_database/`에 예시 테스트와 도우미 사본을 함께 만드는데, 이 저장소는 `test/migrations/generated/`를 쓰므로 그 폴더는 지웁니다.
- 생성 코드 확인: `dart run build_runner build --delete-conflicting-outputs`, `make-migrations`, `schema generate`를 다시 돌려도 생성 파일 다섯 개(`database.g.dart`, `database.steps.dart`, v3 덤프, 도우미 둘)가 바뀌지 않음.
- "이 빌드가 모르는 버전" 테스트(`drift_storage_test.dart`)는 user_version 3을 쓰던 것을 `schemaVersion + 1`로 바꿨습니다(이제 3은 지금 버전).

### 16.3 화면

| 화면 | 동작 |
|---|---|
| 학습 카드 | 카드 아래 오른쪽의 글자 버튼 「이미 알아요」(눈 가림 아이콘, 채움 없음)를 누르면 그 단어를 숨기고 다음 카드로 갑니다. 아래의 두 답 버튼(「다시 학습」·「알고있음」)과 자리·모양이 다르고, 화면 읽기 이름도 「이미 알아요: 이 단어를 숨기고 다음 카드로」 / 「알고있음, 다음 복습 …」으로 다릅니다 |
| 되돌리기 | 숨긴 직후 화면 맨 위(카드 위)에 「「雨」 숨겼어요 · 되돌리기」 줄이 나옵니다. 답 버튼을 가리지 않도록 스낵바 대신 이 줄을 씁니다. 다음 답을 누르면 사라집니다. 마지막 카드를 숨겨 세션이 끝나도 남아 있어 되돌리면 세션이 다시 열립니다. 숨기기가 실패하면 같은 자리에 「숨기지 못했어요」가 나오고 카드는 그대로입니다 |
| 교재 목록 | 숨긴 단어는 DAY 목록에서 빠지고(모두 숨긴 DAY는 머리글도 빠짐), 맨 아래 「숨긴 단어 n개 보기」로 펼쳐 「되살리기」를 누릅니다. 각 줄 오른쪽의 눈 가림 아이콘으로 목록에서도 숨기고, 스낵바의 「되돌리기」로 되돌립니다. 위의 「단어」 수·학습함·장기 기억, DAY별 개수는 숨기지 않은 단어만 셉니다. 숨기거나 되살린 뒤 목록을 다시 읽는 동안에도 이전 목록을 그대로 두어 스크롤 위치와 펼친 숨긴 단어가 유지됩니다 |
| 홈 | 교재 카드 「DAY 01 · 단어 8개 · 숨김 2개」(숨긴 것이 없으면 「숨김」 생략), 「내 교재」 옆 합계와 오늘 학습할 수(복습할 단어·새 단어)도 숨기지 않은 단어만 셉니다 |

문구는 `app/lib/shared/hide_labels.dart` 한 곳에 있습니다(버튼 이름을 바꿀 때 이 파일만 고침).

`flutter drive -d <iPhone 17 Pro> --driver=test_driver/integration_test.dart --target=integration_test/known_hide_screenshots_test.dart` (메모리 DB, 합성 샘플 10쪽):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `24_study_hide_button.png` | 학습 카드: 카드 아래 「이미 알아요」, 그 아래 「다시 학습」·「알고있음 21일 후」 |
| `25_study_hidden_undo.png` | 「이미 알아요」 뒤: 맨 위 「「雨」 숨겼어요 · 되돌리기」, 다음 카드, 0 / 9 |
| `26_textbook_hidden_open.png` | 교재 목록: DAY 01 8개, 줄마다 숨기기 아이콘, 「숨긴 단어 접기」 아래 雨·雲과 「되살리기」 |
| `27_home_hidden_count.png` | 홈: 새 단어 8, 「오늘 학습 시작 · 8장」, 「DAY 01 · 단어 8개 · 숨김 2개」 |

### 16.4 옛 앱 데이터가 남는지 (시뮬레이터)

iPhone 17 Pro (iOS 26.5), dev 앱. 스키마 v2 앱(이 변경 바로 전 커밋의 소스)으로 `integration_test/persistence_test.dart`의 `save` 단계를 `--keep-app-running`으로 돌려
합성 DAY 20 6단어를 저장·학습한 뒤(파일: user_version 2, 단어 6·카드 6·기록 7, `hidden_at` 열 없음), 앱을 지우지 않고 이 빌드로 같은 파일의 새 단계 `upgrade`를 돌렸습니다
(`--dart-define=SHIORI_PERSISTENCE_STEP=upgrade`).

- 앱 안 단언: user_version = `schemaVersion`(3), 단어 6개 모두 안 숨김, `hiddenWords()` 없음, 카드 단계 [2,4,4,4,4,4], 기록 7개, 홈 「오늘 6개 외움」·숨김 표시 없음 — 통과.
- 파일 비교(시뮬레이터 컨테이너의 `shiori.sqlite`를 두 시점에 덤프): `textbooks`·`textbook_days`·`review_cards`·`review_logs`의 모든 행이 같고, `words`는 `hidden_at`을 빼면 모든 칸이 같으며 `hidden_at`은 6행 모두 NULL.

### 16.5 테스트

| 파일 | 내용 |
|---|---|
| `packages/storage_drift/test/contract/hidden_words_contract.dart` (+ `hidden_words_contract_test.dart`가 InMemory·drift 둘 다 돌림) | 숨김 상태·시각 저장, 되살리기, 두 번 숨겨도 첫 시각, 없는 ID는 이름을 단 오류, 1200개 한 번에; `words()`가 숨긴 단어 포함·필드로 구분, `hiddenWords()` 순서·교재 거르기·바꿀 수 없는 목록, 다시 저장해도 숨김 유지, `saveWords`는 숨기지 않음, 실패한 트랜잭션 안의 숨기기 되돌림; 집계(`wordCount`·`hiddenCount`·`days`, `words()`와 일치); 세션에서 빠짐·카드와 기록 유지·되살리면 같은 카드, 요약 수, 세션 안 숨기기·되돌리기, 같은 쪽 다시 저장해도 숨김 유지; 일부 ID가 없으면 아무것도 안 바뀜 (22개 × 2) |
| `packages/storage_drift/test/drift_hidden_words_test.dart` | 저장 오류 주입(두 번째 단어 쓰기에서 SQLite `RAISE`): 숨김 0개·카드와 기록 그대로, 학습 화면 경로(`StudyService.hide`)도 같음; 파일을 닫았다 열어도 숨김 유지 |
| `packages/storage_drift/test/migrations/migration_test.dart` | 지금 스키마 = v3 덤프, 새 DB는 v3이고 `hidden_at` 있음, v1·v2·v3 파일 검증, v1 → v3 모든 칸, **v2 → v3**: 교재 2·DAY 3·단어 5·카드 3·기록 4가 그대로이고 열은 `hidden_at` 하나만 늘고 모두 NULL, 블록으로 읽어도 숨김 0·카드와 기록 그대로 |
| `packages/core/test/study/known_hide_session_test.dart`, `known_hide_service_test.dart` | 세션 구성에서 빠짐(목표 자리도 안 차지), `afterHidden`·`restored`(진행률, 마지막 카드, 다시 학습한 카드, 끝난 세션), 서비스의 숨기기·되돌리기, 카드 유지, 요약, 숨기기 실패는 아무것도 안 바꿈, 숨길 블록 없음·끝난 세션은 오류 |
| `packages/core/test/library/known_hide_library_test.dart` | `LibraryService.hideWords`·`unhideWords`, 개요의 숨긴 단어·수, 모델 같음 비교·`TextbookStats.hiddenCount` |
| `app/test/features/known_hide_study_test.dart` | 「이미 알아요」 → 카드 사라짐·다음 카드·되돌리기로 되살아남, 「알고있음」 동작·표시 그대로, 두 버튼의 화면 읽기 이름이 다름, 마지막 카드를 숨겨 끝난 세션 되돌리기, 숨기기 실패 안내 |
| `app/test/features/known_hide_textbook_test.dart` | 교재 목록: 숨긴 단어 기본으로 안 보임·「숨긴 단어 n개 보기」로 펼쳐 되살리기, 목록에서 숨기기와 되돌리기; 홈 교재 카드·합계·오늘 학습할 수 |

결과(16절 반영 뒤):

| 항목 | 결과 |
|---|---|
| 정적 분석 | core·storage_drift `dart analyze`, app `flutter analyze` 문제 없음 |
| 테스트 | core **427개**(교재 세트 포함 **440개**), storage_drift **122개**, app **120개** 통과 |
| 캡처 회귀 | 합성 row 31/35 그대로(이 변경은 캡처를 건드리지 않음), 기준 구현과 다른 칸 0 |
| 빌드 | `flutter build apk --debug --flavor dev` 성공 (`app-dev-debug.apk`, 195 MB) |
| 시뮬레이터 | 16.3절 스크린샷 4장, 16.4절 v2 → v3 덮어 설치 데이터 보존 |

## 17. 「높음」 늘리기: 범용 독립 근거, 틀 경로 항목의 근거 (2026-11-06)

규칙은 `docs/extraction.md` 4.4절입니다. 짝짓기·칸 값·가로줄 틀 해석 규칙(`capture/vocab/**`)·경로 선택 기준·저장 스키마는 바꾸지 않았습니다(신뢰도와 근거만).

### 17.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 신뢰도 단계 | `packages/core/lib/src/extract/confidence.dart`, `general_extractor.dart`(연결) | 같은 표제어 합치기가 끝난 뒤 신뢰도를 정함: 내용 근거 하나 + 강한 위치 + 이웃 경쟁 없음 → 높음, 공통 관문(한글 아닌 글자, 읽기 없는 한자 표제어, 사전이 준 표제어)은 높음을 막음 |
| 틀 경로 근거 | `packages/core/lib/src/capture/template_evidence.dart`(`withTemplateEvidence`), `capture_router.dart`(연결) | 틀로 간 쪽의 항목에 칸별 출처·짝 신뢰도·사진 좌표 상자. 사전·한국어 뜻 사전은 범용 추출기의 것. 값과 문제 표시는 그대로 |
| 검토 화면 | `app/lib/features/capture/entry_tile.dart`, `review_screen.dart` | 틀 항목은 기존 타일(번호, 표제어 후보, 칸 표시, 고치기)에 출처 배지·신뢰도·근거 조각(누르면 사진 조각)·「확인됨」을 더함. 요약에 「높음 N」, 근거가 있는 쪽이면 틀 쪽에서도 「높음 전체 승인」 |
| 합성 함정 쪽 | `tools/synthetic/make_general_pages.py`, `synthetic_general/g21~g23.*`, `ground_truth_traps.json` | 같은 읽기 이웃(`橋/箸`, 후리가나 촘촘한 줄), 같은 낱말을 멀리, 이웃의 같은 뜻(`橋/脚`: 다리). 점수표 정답 파일과는 따로 |
| 테스트 데이터 | `packages/core/test/support/real_dictionary.dart` | 합성 세트 낱말만, JMdict·한국어기초사전 값을 그대로 옮긴 메모리 사전·뜻 사전 |

### 17.2 측정 (규칙을 정하기 전, 실제 JMdict·한국어 뜻 사전, 앱과 같은 경로 선택)

칸마다 근거 조합과 맞음/틀림을 셌습니다(맞음/틀림, 교재 쪽은 숫자만). 「범」은 범용 경로, 「틀」은 가로줄 틀 경로입니다.

| 근거 조합 | 합성 | 로컬 |
|---|---|---|
| 범 뜻: 내용 2 (한자음+뜻 사전) | 18/0 | 8/0 |
| 범 뜻: 내용 1 + 강한 위치(0.85 이상) | 24/0 | 10/0 |
| 범 뜻: 내용 1 + 약한 위치 | 1/0 | 0/0 |
| 범 뜻: 내용 1 + 여러 줄 이음 | 2/0 | 0/0 |
| 범 뜻: 내용 1 + 판독 최저 | 0/0 | 1/0 |
| 범 뜻: 내용 1 + 한글 아닌 글자 | 0/0 | 1/**1** |
| 범 뜻: 사전으로 채움 | 1/0 | 0/**2** |
| 범 뜻: 위치만 | 2/0 | 5/**1** |
| 범 읽기: 사전 + 강한 위치(0.6 이상) | 10/0 | 4/0 |
| 범 읽기: 사전 + 약한 위치 | 4/0 | 2/0 |
| 범 읽기: 사전 + 위치, 판독 최저 | 0/0 | 2/0 |
| 범 읽기: 사전으로 채움 | 10/0 | 3/0 |
| 범 읽기: 인라인 괄호 | 18/0 | 8/0 |
| 틀 뜻: 틀 칸 + 내용 근거 (표제어 글자 보정 포함) | 41/0 | 84/0 |
| 틀 뜻: 내용 근거 없음 | 4/**1** | 22/**1** |
| 틀 뜻: 사전으로 채움 | 1/0 | 1/0 |
| 틀 뜻: 칸 문제 표시(의심) | 0/**1** | 0/**1** |
| 틀 읽기: 틀 칸 + 사전 일치 (표제어 글자 보정 포함) | 44/0 | 104/0 |
| 틀 읽기: 사전 일치 + 읽기 칸 보정 | 1/0 | 1/0 |

틀린 칸은 내용 근거가 없거나 사전으로 채운 칸, 판독 잡티가 섞인 뜻에만 있습니다. 더 세게 시험하려고 틀로 가는 쪽까지 범용으로 돌린 변형에서는
**품사 배지 오독이 붙은 뜻**(`명4, 사` 꼴)이 내용 근거 둘(한자음+뜻 사전)로 **예전 규칙에서도 높음인데 틀림**이었고(1건), 여러 줄 이은 뜻의 잡티,
읽기 없는 한자 표제어가 뜻만으로 높음이 되는 경우가 나왔습니다. 이것들이 공통 관문(4.4절)의 근거입니다. 그 변형에서도 「사전 + 강한 위치」 읽기(118)와
「내용 1 + 강한 위치」 뜻(89)은 모두 맞았습니다.

### 17.3 결과 (높음 항목 수, 높음인데 틀림)

| 세트 | 경로 | 높음 전 → 후 | 하한 | 높음인데 틀림 |
|---|---|---|---|---|
| 합성 범용 6쪽 (메모리 사전 + 실제 뜻 사전 값) | 범용 | 8 → **28** | 25 | 0 |
| 　같은 쪽, 뜻 사전 흉내 / 없음 | 범용 | 0 → 15 / 0 → 10 | | 0 |
| 합성 함정 3쪽 (g21~g23) | 범용 | 0 → 2 (g22의 멀리 떨어진 두 단어) | | 0 |
| 합성 기존 4쪽 (실제 사전 값) | 틀 | 0 → **27** | 22 | 0 |
| 합성 ML Kit형 2쪽 (실제 사전 값) | 틀 | 0 → **13** | 10 | 0 |
| 교재 단어장 5쪽 (로컬, 실제 사전) | 틀 | 0 → **43** | 40 | 0 |
| 교재 5쪽 ML Kit 조각 (로컬) | 틀 | 0 → **40** | 36 | 0 |
| 실기기 촬영 휜 쪽 1쪽 (로컬) | 범용 | 0 → **6** | 4 | 0 |
| 다른 교재 3쪽 (로컬) | 범용 | 2 → **8** | 6 | 0 |

- 값은 전 세트 그대로입니다: 합성 범용 찾음 49/49·읽기 49·뜻 48/48·문장 단어 45/45·38/38·여분 0, 합성 기존 33/35·33·뜻 31(뜻 사전 32)·여분 1,
  ML Kit형 17/18·17·16·여분 1, 교재 5쪽 57/59·57·56·여분 1, ML Kit 조각 52/59·52·51·여분 4, 휜 쪽 14/15·14·14·여분 1, 다른 교재 15/15·15·11·여분 4.
  줄 점수 합성 31/35(채움 32/35), ML Kit형 16/18, 교재 Vision 55/59(채움 56/59), ML Kit 조각 51/59, 기준 구현과 다른 칸 0 — 그대로.
- 틀로 간 쪽은 `CapturePipeline`의 결과와 값이 같고(근거를 뺀 값 비교), 근거만 붙습니다.
- 함정 쪽: g21(같은 읽기 이웃)과 g23(같은 뜻 이웃)은 값이 맞아도 그 짝이 높음이 되지 않고, g22(멀리)는 읽기 짝이 높음입니다.

### 17.4 테스트 (C1~C9)

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/high_confidence_counts_test.dart` | C1 합성 전 세트(범용·함정·기존·ML Kit형, 뜻 사전 없음·흉내·실제 값) 높음인데 틀림 0, 높음 항목은 짝 칸 모두 높음·확인 필요 아님. C2 하한. C7 값 그대로 |
| `packages/core/test/extract/confidence_rules_test.dart` | C3 같은 읽기 이웃(g21)/멀리(g22), C4 같은 뜻 이웃(g23), C5 사전에 없는 인쇄 읽기(옆·괄호), 잡티 붙은 뜻(예전 규칙의 높음인데 틀림 회귀), 읽기 없는 한자 표제어, 사전이 준 표제어, 기기 채널의 0.3 |
| `packages/core/test/capture/template_evidence_test.dart` | C6 틀 쪽 모든 항목에 근거·값은 파이프라인과 같음·표제어 상자, 사전에 없는 표제어, 사전으로 채운 뜻(출처 사전), C5 사전에 없는 읽기는 낮음, 이웃 행 같은 읽기·같은 뜻, 잡티, 문제 표시 |
| `packages/jmdict_block/test/high_confidence_local_test.dart` | C8 로컬 4세트(실제 사전): 높음인데 틀림 0, 하한, 값 그대로 (숫자만 출력) |
| `app/test/features/template_review_evidence_test.dart` | C9 틀 경로 초안: 출처 배지·신뢰도 라벨(화면 읽기 포함), 근거 조각, 요약 「높음 N」, 「높음 전체 승인」은 높음만 확인됨·스위치 뒤, 번호·「확인 필요」·칸 표시·표제어 후보·고치기 그대로 |
| 기존 테스트 수정 | `route_selection_test.dart` E2 두 개와 `app/test/features/no_star_marks_test.dart`의 흐름 비교를 근거를 뺀 값 비교로, `korean_glossary_link_test.dart`의 「사전 없으면 높음 아님」을 「뜻 사전 근거가 쓰이지 않음」으로(새 규칙에서는 한자음 + 강한 위치가 높음) |

결과: core **514개** 통과(교재 세트 포함 **531개**), jmdict_block **23개**(로컬 포함 **27개**), app **144개** 통과, analyze 문제 없음,
생성기 `--check` 3개 같음.

### 17.5 빌드와 시뮬레이터 (iPhone 17, 합성 샘플만)

`flutter build apk --debug --flavor dev` 성공(`app-dev-debug.apk`, 195 MB).
`flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/template_evidence_screenshots_test.dart`
(실제 JMdict·한국어 뜻 사전 asset, 합성 샘플 10쪽):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `34_review_template_evidence.png` | 틀 경로 검토: 요약 「높음 6」, 번호·출처 배지·신뢰도, 못 읽은 표제어의 사전 후보 그대로 |
| `35_review_template_evidence_piece.png` | 뜻 칸의 근거 조각(사진이 없어 판독 기록으로 그린 쪽) |
| `36_review_template_approved.png` | 「높음 전체 승인」 뒤: 높음 항목만 「확인됨」 |

## 18. 단어장 따라잡기: 범용 추출의 단어장 내용 규칙, 못 읽은 표제어 되살리기, 판독 기록 내보내기 (2026-11-06)

규칙은 `docs/extraction.md` 2절·12절입니다. 가로줄 틀 해석 규칙(`capture/vocab/**`)의 동작, 경로 선택 기준(`chooseRoute`), 신뢰도 규칙, 저장 스키마는 바꾸지 않았습니다.
틀을 걷어내지 않았습니다(틀이 맞는 쪽은 그대로 틀로 읽음).

### 18.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 단어장 표지 공용 표 | `packages/core/lib/src/capture/text/word_list_marks.dart` (새), `capture/vocab/fields.dart` | 품사 배지 표(`posBadges`)·빈 칸 대시(`readingDashes`)를 틀에서 옮겨 함께 씀. 틀 결과 그대로(아래 18.3) |
| 조각 분류 | `extract/fragment_collector.dart`, `extract/fragment.dart` | 배지 줄은 한국어가 이김, 한글 1자 쓰레기는 가나에 짐, 빈 칸 대시(높이 0.5배 이하), 상자 글자 줄·체크박스 열의 `問`, 표지 줄(`=`·`|`·`[…]`), 후리가나, 배지 뒤 `.`·품사 이름 배지, 조각의 `posBadge` |
| 표제어 고치기 | `extract/headword_repair.dart` (새) | 띄어 읽힌 표제어 잇기, 가나 표제어의 헷갈리는 글자, 괄호 접두 형태 |
| 되살리기 | `extract/read_back.dart` (새), `ports/korean_glossary.dart` (`KoreanReverseGlossary`, `GlossedSpelling`), `packages/krdict_block` (`reverseLookup`) | 흔적 + 사전 역조회로 못 읽은 한자 표제어, 흔한 낱말 하나면 그것, 여럿이면 표제어 후보 |
| 짝짓기 | `extract/general_extractor.dart`, `extract/pairing.dart` | 사전에 없는 한자 조각이 다른 낱말의 읽기를 위치로 못 가져감, 확인 안 된 0.3 표제어의 뜻 비용 +0.2, 문장 아래 번역, 후리가나 크기·0.3 가나 거르기, 배지 품사 |
| 검토 근거 | `extract/extracted_word.dart` | `headwordCandidates` → `CapturedEntry.headwordCandidates`·표제어 칸 후보·설명 「사전 역조회 후보 N」. 범용 검토 타일(`evidence_tile.dart`)은 표제어 칸 후보 칩을 아직 그리지 않음(설명만 보임) |
| 판독 기록 내보내기 | `app/lib/features/capture/ocr_export.dart` (새), `review_screen.dart`(상단 버튼 한 줄), `app/pubspec.yaml` (`share_plus` 13.3.1 고정, BSD-3) | release가 아닌 빌드에서만 검토 화면 상단에 버튼. 두 패스를 녹화 판독 형식(`<이름>.ja.json`·`<이름>.ko.json`)으로, 경로 선택 결과(`<이름>.route.json`)와 함께 공유 시트로. 사진은 넣지 않음. 라이선스 페이지에 `share_plus`가 자동으로 실림(APK의 NOTICES 확인) |
| 합성 세트 | `tools/synthetic/make_general_pages.py`, `synthetic_general/g10.*`·`g11.*` | g10 번호 없는 단어장(배지·오독 배지·배지 줄을 일본어 패스가 이김·빈 칸 대시·보통 높이 `一`·0.3 오독 표제어·가나 표제어·`(お)`·한글 1자 쓰레기·`ニつ`·`交通 事故`·`問`/`コロロ`·범례·꼬리), g11 예문 상자(후리가나·아래 번역·`[문형]`·두 줄 뜻). 메모리 사전 +30항목, 뜻 흉내 +11 |

### 18.2 결과 (표제어 기준, 실제 JMdict·한국어 뜻 사전, 범용 단독 = 경로 선택 없이 범용만)

교재 쪽은 숫자만 적습니다. 「전」은 이 작업 전(main 71b9b94), 「후」는 이 작업 뒤.

| 세트 | 방식 | 찾음 | 읽기 | 뜻 | 여분 | 높음인데 틀림 |
|---|---|---|---|---|---|---|
| 교재 단어장 5쪽 (59단어, 로컬) | 범용 단독 전 | 56/59 | 56/56 | 47/56 | 15 | 0 |
| | **범용 단독 후** | **59/59** | **59/59** | **58/59** | **0** | 0 |
| | 틀 (그대로) | 57/59 | 57/57 | 55/57 (한국어 뜻 채움 56/57) | 1 (+중복 1) | 0 |
| 실기기 촬영 휜 쪽 1쪽 (15단어, 로컬) | 범용 전 | 14/15 | 14/14 | 14/14 | 1 | 0 |
| | **범용 후** (기록 그대로 / 빈 칸 대시를 `一` 0.5로 바꾼 변형) | **15/15 / 15/15** | 15/15 | 15/15 | **0 / 0** | 0 |
| 다른 교재 3쪽 (15단어, 문장 단어 33, 로컬) | 범용 전 → 후 | 15/15 → 15/15 | 15/15 | 11/15 → 11/15 | 4 → 4 | 0 |
| 합성 기존 4쪽 (35단어) | 범용 단독 전 → 후 | 28/35 → **32/35** | 28 → 32 | 25/28 → **31/32** | 17 → **4** | 0 |
| 합성 범용 g01~g06 (49단어) | 범용 전 → 후 | 49/49 → 49/49 | 49/49 | 48/48 | 0 → 0 | 0 |
| 합성 범용 g10·g11 (21단어, 새) | 범용 전 → 후 | 17/21 → **21/21** | 17 → 21 | 13/16 → **20/20** | 5 → **0** | 0 |

- 교재 5쪽에서 남은 틀림 1개는 판독 오류(뜻의 한 글자를 다른 글자로 읽음)로, 틀도 같은 칸을 틀립니다.
- 합성 기존 4쪽의 기준선 여분은 15.3절에 19로 적혀 있지만, 같은 코드(main 71b9b94)를 이 측정 조건(`eval_extract_dict.dart --glossary`, 실제 asset)으로 다시 재면 17이라 17을 기준으로 삼았습니다.
  남은 놓침 3은 표제어 자리에 아무것도 읽히지 않은 행 2(흔적 없음)와 판독 오류 1입니다.
- 원인별 개수(이 작업 전, 교재 5쪽): 배지 줄을 일본어 패스가 이김 3, 한글 1자 쓰레기 2, 가타카나 오독 표제어 1, 상자 글자 3, 표지 줄 3, 후리가나 8, 두 줄 뜻 1, 빈 칸 대시 2, 판독 오류 1.
- 쪽당 시간(데스크톱 Dart VM, 교재 5쪽 범용 단독): 65~68 ms(세 번), 이 작업 전 1회 83 ms — 측정 오차 안. 역조회 질의는 색인(`ja_reading`·`ja_key`)을 탑니다(`EXPLAIN QUERY PLAN`).
- 경로 선택 결과(15.2절)는 그대로입니다. 경로 선택을 거치면 교재 5쪽은 여전히 틀(57/59·56/57)로 갑니다.

### 18.3 회귀 (그대로)

줄 점수 합성 31/35(채움 32/35), 합성 ML Kit형 16/18, 교재 Vision 55/59(채움 56/59), 교재 ML Kit 조각 51/59, 기준 구현과 다른 칸 0, 여분 0,
경로 선택 결과(15.2절), 합성 범용 g01~g06의 값(찾음·읽기·뜻·문장 단어·여분). 높음인데 틀림은 모든 세트에서 0입니다.

### 18.4 테스트 (V1~V10)

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/vocab_list_test.dart` | g10: 점수(사전 있음 18/18·여분 0, 없음 17/18·여분 1), V1 배지(뜻 칸·낱말·보관함·품사·배지 줄), V7 빈 칸 대시와 보통 높이 `一`, V8 `竹` 0.3 → `箱`(출처 사전·근거), 가나 표제어는 가나, V9 `(お)みやげ`, 한글 1자 쓰레기, `(다`, `ニつ`, `交通 事故`, 상자 글자, 범례·꼬리 |
| `packages/core/test/extract/word_list_marks_test.dart` | 손으로 만든 판독: 배지 떼기·배지만·`동사무소`, 배지 줄과 한쪽 판독 다툼, 상자 글자, 대시 6종, V8 흔적 3종·흔적 없음·후보 둘·역조회 없음/실패·쪽마다 한 번 |
| `packages/core/test/extract/example_box_test.dart` | V2 g11: 점수, 예문(원문·아래 번역), 번역은 뜻이 아님, 문장 단어와 예문, 표제어 합치기, 후리가나, 두 줄 뜻, 상자 머리 |
| `packages/core/test/extract/general_set_holds_test.dart` | V3 g01~g06 값 그대로(메모리 사전) |
| `packages/krdict_block/test/reverse_lookup_test.dart` | 역조회: 읽기 → 표기·뜻 낱말·유의어, 여러 읽기, 가타카나 읽기, 없음, 닫은 뒤 |
| `packages/jmdict_block/test/vocab_catchup_local_test.dart` | 로컬·실제 사전: V6 교재 5쪽, 휜 쪽 두 변형, 다른 교재, V5 합성 기존 4쪽, V3 g01~g06, g10·g11 |
| `app/test/features/ocr_export_test.dart` | V10: release 아님 → 버튼, 내보낸 JSON을 `FixtureTextRecognizer`로 다시 읽으면 같은 줄, route 파일, 사진 없음; release 플래그·판독 기록 없음 → 버튼 없음 |

### 18.5 빌드와 시뮬레이터 (iPhone 17 Pro, 합성 샘플만)

`flutter build apk --debug --flavor dev` 성공.
`flutter drive -d <iPhone 17 Pro> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/ocr_export_screenshot_test.dart`:

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `40_review_ocr_export.png` | 범용 샘플 쪽의 검토 화면, 상단 오른쪽 「판독 기록 내보내기」 |


## 19. Android 따라잡기: ML Kit 판독에서 범용 추출, 깨끗한 스캔본의 경로 선택, 속도 (2026-11-06)

규칙은 `docs/extraction.md` 2절·9절·13절입니다. 가로줄 틀 해석 규칙(`capture/vocab/**`)의 동작, 저장 스키마는 바꾸지 않았습니다. 틀을 걷어내지 않았습니다.
신뢰도 규칙은 관문 하나만 더했습니다(표제어 자리를 못 읽은 가나 낱말은 높음이 아님, 4.4절).

### 19.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 조각 분류 | `extract/fragment_collector.dart`, `extract/fragment.dart` (`gluedBadge`) | 붙어 읽힌 배지(두 글자·숫자 앞은 뗌, 한 글자 + 한글은 표시만), 한국어 패스의 `い`+`형…`을 한 구간으로, 세로 글, 쪽 머리 띠, 일본어 앞 `ー` 자국 |
| 뜻 정리 | `extract/meaning_marks.dart` (새) | 한 글자 붙은 배지를 내용 근거로 정함, 끝 마침표 때문에 문장이 된 짧은 서술을 뜻 후보로 |
| 표제어 고치기 | `extract/headword_repair.dart` (`mendByReading`) | 같은 줄 가나의 사전 표기 중 한자 한 자만 다른 유일 표기로 |
| 짝짓기·낱말 | `extract/general_extractor.dart` | 위 두 단계 연결, 짝 없는 낱말을 보관함으로(쪽 낱말의 절반 이상이 짝지어졌을 때), 위치만으로 짝지은 가나 한 글자는 낱말 아님 |
| 신뢰도 관문 | `extract/read_back.dart` (`hasHeadwordTrace`), `extract/confidence.dart` | 흔적 또는 「자국 + 빈 표제어 칸」 옆의 가나 낱말은 높음 아님 |
| 경로 선택 | `capture/capture_router.dart` (`isMarkedHeadword`, `routeMinMarkedHeadwords` 2, `routeMaxMarkedHeadwordShare` 0.1), `models/capture_route.dart` (`TemplateFit.markedHeadwords`, `RouteReason.markedHeadwords`) | 표제어 칸에 체크박스 자국이 붙은 행이 2개 이상이고 10% 이상이면 범용. 검토 화면 요약 「표제어 앞 자국 N/M」 |
| 속도 | `extract/deconjugator.dart` (`indexed`), `extract/lattice.dart` | 규칙을 어미 끝 글자로 색인(결과 불변), 부분 문자열 후보를 한 번만 |
| 채점·평가 도구 | `eval/extract_scorer.dart` (`extraHigh`, `warmUp`), `tool/eval_extract.dart`, `jmdict_block/tool/eval_extract_dict.dart` (`--no-warmup`) | 「여분인데 높음」 열(`exHigh`, `extra_high=`), 첫 쪽 예열 뒤 시간(기본) |
| 판독 기록 내보내기 | `app/lib/features/capture/ocr_export.dart` | `<이름>.route.json`의 잰 숫자에 `markedHeadwords` |
| 합성 세트 | `tools/synthetic/make_general_pages.py`, `synthetic_general/g30`·`g31`·`g32`·`c01`, `ground_truth_android.json` | 13절. 메모리 사전 +10항목, 뜻 흉내 +3. 기존 쪽 파일은 그대로 |

### 19.2 결과 (표제어 기준, 실제 JMdict·한국어 뜻 사전)

교재 쪽은 숫자만 적습니다. 「전」은 main `0bdbc04`, 「후」는 이 작업 뒤.

| 세트 | 방식 | 찾음 | 읽기 | 뜻 | 여분 | 높음 / 높음인데 틀림 / 여분인데 높음 |
|---|---|---|---|---|---|---|
| 교재 단어장 5쪽, **ML Kit 조각**(앱의 Android 채널, 59단어) | 범용 단독 전 | 57/59 | 57/57 | 50/57 | 9 | 33 / 0 / 0 |
| | **범용 단독 후** | **58/59** | **58/58** | **57/58** | **1** | 37 / 0 / 0 |
| | 틀 (그대로) | 52/59 | 52/52 | 51/52 | 4 (+중복 3) | - |
| | 경로 선택 (그대로, 5쪽 모두 틀) | 52/59 | 52/52 | 51/52 | 4 (+중복 3) | 40 / 0 / 0 |
| 교재 단어장 5쪽, Vision | 범용 단독 전 → 후 | 59/59 → 59/59 | 59/59 | 58/59 → 58/59 | 0 → 0 | 20 / 0 / 0 |
| | 경로 선택 (그대로) | 57/59 | 57/57 | 56/57 | 1 (+중복 1) | 43 / 0 / 0 |
| (참고) 같은 5쪽, ML Kit 낱말 단위(앱이 쓰지 않음) | 범용 단독 전 → 후 | 56/59 → 57/59 | 56 → 57 | 27/56 → 30/57 | 21 → 9 | 25 → 27 / **5 → 5** / 0 |
| 휜 쪽 원본 사진 (Mac Vision, 15단어) | 경로 선택 (범용) 전 → 후 | 15/15 → 15/15 | 15/15 | 15/15 | 0 → 0 | 6 / 0 / 0 |
| **같은 쪽 스캔 앱 결과** | 경로 선택 전 (틀) → **후 (범용)** | 11/15 → **14/15** | 11/11 → 14/14 | 11/11 → **14/14** | 4 → **1** | 9 → 8 / 0 / 0 |
| 예문 쪽 2쪽 사진·스캔 앱 결과 (12단어) | 경로 선택 (틀) 전 → 후 | 12/12 · 12/12 | 12/12 | 12/12 | 0 · 0 | 9 / 0 / 0 |
| 다른 교재 3쪽 사진 · 스캔 앱 결과 (15단어, 문장 단어 33) | 경로 선택 (범용) 전 → 후 | 15/15 · 14/15 (그대로) | 그대로 | 11/15 · 9/14 (그대로) | 6 · 6 | 0 / 0 / 0 (높음인데 틀림·여분인데 높음) |
| 휜 쪽 (실기기 기록) · 다른 교재 3쪽 (기록) | 범용 단독 | 15/15 · 15/15 (그대로) | 그대로 | 15/15 · 11/15 | 0 · 4 | 0 / 0 |
| 합성 기존 4쪽 (35단어) | 범용 단독 | 32/35 (그대로) | 32/32 | 31/32 | 4 | 24 / 0 / 0 |
| 합성 ML Kit형 2쪽 (18단어) | 범용 단독 전 → 후 | 17/18 | 17/17 | 16/17 | 1 | 13 / 0 / **1 → 0** |
| 합성 범용 g01~g11 (70단어, 문장 단어 54) | 범용 | 70/70 (그대로) | 70/70 | 68/68 | 0 | 42 / 0 / 0 |
| 합성 g30·g31·g32·c01 (32단어, 새, 메모리 사전) | 범용 / 경로 선택 | g30 9/9·여분 0, g31 6/7(표제어 자리에 아무것도 안 읽힌 행 1)·여분 1, g32 6/6, c01 경로 선택 9/10·여분 1 (틀이면 6/10·여분 4) | | | | 0 / 0 (높음인데 틀림·여분인데 높음) |

- **ML Kit 조각에서 남은 것:** 놓침 1과 여분 1은 같은 행입니다(표제어 자리에 아무것도 읽히지 않았고 그 낱말이 한국어 뜻 사전에 없어 되살릴 근거가 없음 — 가나 그대로, 높음 아님).
  뜻 틀림 1은 한국어 패스가 뜻 줄을 읽지 못하고 일본어 패스가 엉터리로 읽은 판독 오류입니다(틀도 이 쪽에서 뜻 1개를 틀림).
- 원인별 개수(이 작업 전, ML Kit 조각 5쪽 범용): 붙은 배지 뜻 3(그 때문에 이웃 행과 뜻이 바뀐 1 포함), 끝 마침표로 문장이 된 뜻 5, 세로 탭 글이 뜻으로 1(끝 마침표와 같은 행),
  헷갈리는 한자 표제어 1(놓침 1·여분 1), 짝 없는 낱말 6(옆 쪽 가장자리 4, 뜻 줄의 한자 1, 되살리기 흔적이었던 오독 1), 가나 한 글자 1, 표제어 미판독 1, 판독 오류 1.
- **경로 선택:** 15.2절의 결과는 그대로이고(틀로 가는 쪽 전부 「표제어 앞 자국」 0행), 체크박스가 표제어에 붙어 읽힌 스캔 앱 결과(4/15)와 합성 c01(4/10)만 새로 범용으로 갑니다.
- **여분인데 높음:** 측정한 60개 조합(교재·스캔 쌍·합성 × 범용 단독·틀·경로 선택) 모두 0. 관문 전에는 스캔 앱 결과 1(표제어를 못 읽어 가나로 남은 낱말)과 합성 ML Kit형 1(헷갈리는 한자 표기가 둘이라 고치지 못한 행)이었습니다.
- 높음 하한(17절)·높음인데 틀림 0은 전 세트 그대로입니다. 낱말 단위 판독의 높음인데 틀림 5는 원인이 「한 줄을 낱말 상자로 쪼갠 판독」이라(extraction.md 11절) 이 작업 범위 밖입니다.

### 19.3 속도 (데스크톱 Dart VM, ML Kit 조각 5쪽, 범용 단독)

| 측정 | 전 | 후 |
|---|---|---|
| 첫 쪽(식은 상태, 평가 도구 `--no-warmup`) | 243 ms | 115 ms |
| 평가 도구 쪽당 평균 (첫 쪽 포함, 예열 없음) | 117 ms | 52 ms |
| 평가 도구 쪽당 평균 (첫 쪽 예열 뒤, 세 번) | - | 45~80 ms (문장 쪽 46~65 ms) |
| 같은 쪽 세 번째 (완전히 따뜻한 상태): 단어장 3쪽 / 문장 2쪽 | 9~17 / 60~76 ms | 8~17 / 28~43 ms |
| 문장 쪽 활용 되돌리기·후보 만들기 | 30~49 ms | 12~20 ms |
| 합성 g02 (문장 쪽), 예열 뒤 | - | 11 ms (테스트 상한 300 ms) |

- 첫 쪽이 큰 것은 VM 예열과 SQLite 첫 읽기입니다(G0 측정: 같은 쪽을 거듭 읽으면 198 → 17 ms, 다른 쪽을 먼저 읽으면 그 쪽이 커짐). 기기(AOT)에는 JIT 예열이 없지만 SQLite 첫 읽기는 있습니다.
- 평가 도구의 쪽당 시간은 이제 기본으로 첫 쪽을 한 번 시간 밖에서 읽은 뒤의 값입니다. 측정마다 ±20 ms 정도 흔들립니다.

### 19.4 회귀 (그대로)

줄 점수 합성 31/35(채움 32/35), ML Kit형 16/18, 교재 Vision 55/59(채움 56/59), ML Kit 조각 51/59, 기준 구현과 다른 칸 0, 여분 0(`eval_capture` TOTAL row 31/35),
경로 선택 결과(15.2절), 합성 범용 g01~g11·g21~g23의 값, 휜 쪽 15/15(두 변형), 다른 교재, 교재 Vision 범용 59/59·58/59·여분 0.

### 19.5 테스트 (A1~A7)

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/android_reads_test.dart` | g30 점수, A1 붙은 배지(내용으로 뗌·두 글자·숫자 앞·`명함`·`동전`·뜻 사전 없이·판독 보정 표시), A2 끝 마침표(짧은 서술·과거형 문장·예문 번역 그대로), E 읽기로 표제어 고치기(유일 표기·표기 둘·읽는 표제어 그대로), I 가나 한 글자, A2 머리 띠·세로 탭·가장자리·뜻 줄의 한자·보관함에서 새 단어, g31 점수, F 한자만 목록, 흔적 관문(자국 + 빈 칸, 흔적, 체크박스 옆 가나 그대로) |
| `packages/core/test/capture/marked_headwords_test.dart` | A3 c01 경로·이유·요약·잰 숫자, 범용 결과 점수, 판정 함수(2개·10%), `isMarkedHeadword` 표 19칸, 합성 틀 쪽 6개 0행 |
| `packages/core/test/extract/deconjugator_index_test.dart` | A7 색인과 전체 훑기의 후보·순서 같음(표면형 3,746개), 기본 규칙은 색인, g02 예열 뒤 300 ms 이하 |
| `packages/core/test/extract/extra_high_test.dart` | 채점기 「여분인데 높음」, 표와 합계 |
| `packages/jmdict_block/test/android_catchup_local_test.dart` | 로컬·실제 사전: A4 ML Kit 조각 범용 단독(찾음 ≥ 58/59, 뜻 틀림 ≤ 1, 여분 ≤ 2, 높음인데 틀림 0, 여분인데 높음 0), A5 스캔 앱 결과 경로 선택(≥ 14/15, 뜻 틀림 0, 여분 ≤ 1)과 원본 쌍·예문 쪽·다른 교재 그대로, 로컬 10세트 × 범용 단독·경로 선택 여분인데 높음 0·높음인데 틀림 0 |

### 19.6 범용이 Android에서도 따라잡았는가, 틀을 걷어낼 때인가 (의견)

- **따라잡았습니다.** 앱의 Android 채널(ML Kit 조각)에서 범용 단독이 찾음 58/59·뜻 57/58·여분 1로, 틀(52/59·51/52·여분 4 + 중복 3)보다 찾음 +6, 뜻 틀림은 같고(1), 여분·중복이 적습니다.
  Vision(59/59·58/59·0)과 휜 쪽·다른 교재·스캔 앱 결과에서도 범용이 틀과 같거나 낫습니다. 높음인데 틀림·여분인데 높음은 전 세트 0입니다.
- **그러나 지금 앱은 이 교재 쪽을 여전히 틀로 읽습니다**(경로 선택이 「틀이 맞는 쪽」을 틀로 보냄). 그래서 Android에서 사용자가 받는 결과는 아직 52/59입니다.
- **걷어낼 때가 됐다고 봅니다. 다만 한 단계씩:** ① 경로 선택에서 「틀이 맞아도 범용」으로 기본을 바꾸고 틀은 비교용으로만 남겨 실제 사용 기록(판독 기록 내보내기)을 몇 주 모은 뒤,
  ② 범용이 틀을 이기지 못한 쪽이 나오지 않으면 틀 코드(`capture/vocab/**`)와 경로 선택을 걷어냅니다. 근거: 두 판독 엔진·사진·스캔 앱 결과 모두에서 범용이 같거나 낫고,
  틀이 낫던 유일한 이유(단어장 전용 보정)는 18절·이 절의 내용 규칙으로 옮겨졌으며, 깨끗한 스캔본처럼 틀이 「맞는다고 재지만 틀리는」 쪽이 새로 확인됐습니다.
  남은 위험: 틀이 주던 번호(학습 순서)와 「확인 필요」 칸 표시가 범용 결과에는 없거나 다릅니다 — 걷어내기 전에 검토 화면에서 확인할 것.


## 20. 가로줄 틀 경로 걷어내기: 모든 쪽을 단어 추출기로 (2026-11-06)

설계와 이유는 `docs/extraction.md` 9절입니다. **모든 교재가 같은 양식이 아니므로** 특정 단어장의 가로줄 틀 경로를 걷어내고 모든 쪽을 단어 추출기로 읽습니다.
쪽 정보(DAY·제목·쪽 번호)와 단어 번호는 자동으로 읽지 않습니다(묶음은 다음 단계에서 학습자가 만듦). 저장 스키마는 바꾸지 않았습니다(v3 그대로).

### 20.1 걷어낸 것 · 옮긴 것 · 남긴 것

| 구분 | 내용 |
|---|---|
| 걷어냄 (core) | 가로줄 틀 해석기 `capture/vocab/**`, `TemplateRegistry`·포트 `TextbookTemplate`, `CapturePipeline`, 경로 선택 `CaptureRouter`·`chooseRoute`·`TemplateFit`·`RouteDecision`, 보정기 체인 `capture/correctors/**`(11개)와 포트 `EntryCorrector`, 틀 쪽 근거 `withTemplateEvidence`, 줄 정리 `prepareScan`, `ColumnScale`, `PageMeta`, `CaptureDraft.templateId`·`meta`·`columnScale`·`route`, `CapturedEntry.no`, `IssueKind.unverified`, 포트 `Dictionary`, 틀 채점기 `scoreCapture`·`GroundTruth`·`referenceDiff`·`sequence_matcher`, 도구 `tool/eval_capture.dart`·`tool/reference_diff.dart`, 평가 도구의 `--template`·`--routed` |
| 걷어냄 (다른 패키지·도구) | `JmdictDictionaryAdapter`·`tool/eval_capture_dict.dart`(jmdict_block), `dict_jmdict`의 `lookupByReading`·`lookupByHeadword`·`hasPair`·`checkPair`·`suggestHeadword`와 헷갈리는 글자·표기 규칙·가나 모듈·`tool/query_batch.dart`, `measure_glossary.dart capture`, Python 기준 구현 `tools/reference/parse_eval.py`·`dump_reference.py`, `tools/extract/convert_truth.py`, `tools/dict/eval_dict.py`, 합성 `reference_output.json`·`ground_truth_legacy.json` |
| 걷어냄 (앱) | 틀 타일 `entry_tile.dart`, 블록 `templateRegistryProvider`·`dictionaryProvider`·`entryCorrectorsProvider`·`capturePipelineProvider`·`captureRouterProvider`, 검토 화면의 쪽 정보 머리·고치기 시트·칸 배율 안내·경로 요약, 판독 기록 내보내기의 `route.json` |
| 옮김 | 헷갈리는 글자 표 → `extract/confusables.dart`, `flagMissingFields` → `capture/learner_edits.dart`, 사진 → 판독 기록 도구 → `tools/ocr/`, 범용 쪽의 초안 만들기 → `extract/page_draft.dart`(`pageDraft`) |
| 새로 | 送り仮名 가타카나 고치기(`光ル` → `光る`, 사전 + 같은 줄 읽기), 쪽 글자 높이에서 체크박스 줄 빼기(빈 읽기 칸 대시 판정), 검토 초안을 사진 속 순서로, 저장 id 순번 4자리(정렬 버그 `-10` < `-2` 고침), 검토 타일의 표제어 후보 칩, 검토 머리 「단어 N개 · 판독 n초」, 새 교재 기본 이름 「내 단어장」 |
| 남김 | 합성 단어장 4쪽·ML Kit형 2쪽의 판독 기록(범용 회귀 세트, 정답은 `general-1`로, 관련어 상자 낱말은 `ignore`)과 생성기 `make_pages.py`, 앱 샘플, 저장 스키마(`words.no`·`textbooks.template_id` 열), 앞 버전이 저장한 번호·DAY의 표시, Android·iOS 채널(틀 전용 코드 없음), `research/**` |

### 20.2 결과 (표제어 기준, 실제 JMdict·한국어 뜻 사전; 전 = 경로 선택, 후 = 단어 추출기만)

교재 쪽은 숫자만 적습니다. 「여분」 괄호는 중복입니다.

| 세트 | 전 경로 | 전: 찾음 · 읽기 · 뜻 · 여분 · 높음 | 후: 찾음 · 읽기 · 뜻 · 여분 · 높음 |
|---|---|---|---|
| 합성 단어장 4쪽 (35) | 틀 | 33/35 · 33/33 · 32/33 · 1(+1) · 27 | **33/35 · 33/33 · 32/33 · 2(+0)** · 24 |
| 합성 ML Kit형 2쪽 (18) | 틀 | 17/18 · 17/17 · 16/17 · 1 · 13 | 17/18 · 17/17 · 16/17 · 1 · 13 |
| 합성 범용 g01~g11 (70, 문장 54) | 범용 | 70/70 · 70 · 68/68 · 0 · 42 | 그대로 |
| 합성 Android g30~g32·c01 (32) | 범용 | 29/32 · 29 · 21/21 · 3 · 20 | 그대로 |
| 교재 단어장 5쪽 Vision (59, 로컬) | 틀 | 57/59 · 57/57 · 56/57 · 1(+1) · 43 | **59/59 · 59/59 · 58/59 · 0** · 20 |
| 같은 5쪽 ML Kit 조각 (59, 로컬) | 틀 | 52/59 · 52/52 · 51/52 · 4(+3) · 40 | **58/59 · 58/58 · 57/58 · 1** · 37 |
| 휜 쪽 실기기 기록 (15) | 범용 | 15/15 · 15 · 15 · 0 · 6 | 그대로 |
| 다른 교재 3쪽 (15, 문장 33) | 범용 | 15/15 · 15 · 11/15 · 4 · 8 | 그대로 |
| 스캔 쌍: 휜 쪽 원본 · 스캔 앱 | 범용 · 범용 | 15/15 · 0 · 6 / 14/15 · 14/14 · 1 · 8 | 그대로 |
| 스캔 쌍: 예문 쪽 2쪽 원본 · 스캔 앱 (12) | 틀 · 틀 | 12/12 · 12 · 12 · 0 · 9 / 같음 · 9 | 12/12 · 12 · 12 · 0 · **5** / 같음 · **6** |
| 스캔 쌍: 다른 교재 원본 · 스캔 앱 | 범용 | 15/15·11/15·6·8 / 14/15·9/14·6·6 | 그대로 |

- 높음인데 틀림·여분인데 높음: 앱 채널 세트 전부 0(전과 같음). (참고: 앱이 쓰지 않는 ML Kit 낱말 단위 판독은 전 3·후 5로 이미 기록된 결함, extraction.md 11절.)
- **합성 단어장 4쪽의 여분 2**는 표제어를 판독하지 못하고 흔적도 없는 두 행(`日`·`空`)이 가나 `ひ`·`そら`로 남은 것입니다. 틀은 같은 두 행을 빈 표제어(여분 1 + 중복 1)로 냈습니다.
  이 쪽을 틀과 같게 하려고 넣은 규칙: 送り仮名 가타카나(`光ル`, 놓침 1·여분 1 → 0), 체크박스 줄을 뺀 글자 높이(대시 `一`가 낱말이 되던 여분 → 0), 관련어 상자 낱말은 정답의 `ignore`.
- **「높음」이 줄어든 세트**(값은 같거나 나음): 틀 근거는 틀 칸을 위치 근거로 썼고, 추출기는 판독 신뢰도가 가장 낮은(0.3) 읽기 가나·약한 위치를 높음에서 막습니다.
  교재 Vision 5쪽에서 읽기가 중간에 머문 16개 중 10개가 0.3 가나, 4개가 약한 위치입니다. 높음 회복은 다음 단계입니다.
- 쪽당 시간은 단어 추출기 그대로(데스크톱 Dart VM, 예열 뒤 단어장 10~20 ms, 문장 쪽 30~60 ms; 틀 3~5 ms였음).

### 20.3 하한 (범용 기준, 승인 2026-11-06)

| 세트 | 하한 |
|---|---|
| 합성 단어장 4쪽 (메모리 사전 + 역조회 되는 메모리 뜻 사전, 그리고 실제 사전) | 찾음 ≥ 33/35, 읽기 = 찾음, 뜻 틀림 ≤ 1, 여분 + 중복 ≤ 2, 높음 ≥ 21 |
| 합성 ML Kit형 2쪽 | 찾음 ≥ 17/18, 읽기 = 찾음, 뜻 틀림 ≤ 1, 여분 + 중복 ≤ 2, 높음 ≥ 10 |
| 교재 단어장 5쪽 Vision (로컬) | 59/59 · 읽기 59 · 뜻 틀림 ≤ 1 · 여분 0 · 높음 ≥ 17 |
| 같은 5쪽 ML Kit 조각 (로컬) | ≥ 58/59 · 뜻 틀림 ≤ 1 · 여분 ≤ 2 · 높음 ≥ 33 |
| 스캔 쌍 예문 쪽 (로컬) | 12/12 · 뜻 틀림 0 · 여분 0 · 높음 ≥ 4 |
| 전 세트 | 높음인데 틀림 0, 여분인데 높음 0 |

### 20.4 검토 화면과 저장

- 모든 항목을 근거 타일 하나로 그립니다(출처·신뢰도·근거 조각·칸 표시·고치기, 높음이 아닌 칸의 후보 칩. **표제어 칸 후보 칩을 더함**: 못 읽은 표제어의 사전 역조회 후보).
- 머리는 「단어 N개」와 「출처 · 판독 n초」입니다. DAY·제목·쪽 고치기 시트, 「목록형/항목형/범용 추출」 라벨, 칸 배율 안내, 경로 요약은 없습니다.
- 저장: 새 단어는 번호·DAY·쪽 없이 저장되고 id는 `교재id:w<저장 시각 µs>-<쪽 안 순번 4자리>`입니다. 같은 시각에 두 번 저장해도 덮어쓰지 않습니다.
  학습·서재 순서는 (DAY → 번호 → 저장 시각 → id)라 새 단어는 사진 속 순서대로 나옵니다. 앞 버전이 저장한 번호·DAY는 그대로 읽히고 서재에서 DAY별로 보입니다.
  새 단어는 서재에서 「DAY 모름」 묶음에 들어갑니다(교재 화면은 이번에 바꾸지 않음).
- 이미 라이브러리에 있는 표제어는 모든 쪽에서 건너뜁니다(전에는 범용 쪽만). 같은 쪽을 다시 찍어 단어를 갱신하는 길은 없어졌습니다.
- 표제어 후보 칩으로 가나 표제어(읽기 없음)에 한자 표기를 고르면 그 가나가 읽기가 되고, 한자 표제어에 읽기가 하나도 없으면 「확인 필요」입니다.
- 평가 도구의 정답 읽기(`ExtractTruth.fromJson`)는 `"format": "general-1"`이 아니면 형식 오류로 멈춥니다(옛 형식 정답이 0점으로 조용히 채점되지 않게).

### 20.5 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/word_book_reads_test.dart` (새) | D7 `光ル` → `光る`(합성 s011, 손으로 만든 행, 사전에 없거나 읽기가 다르면 그대로, 가타카나 낱말 그대로), D8 체크박스 줄이 많은 쪽의 대시 `一`는 낱말 아님, 검토 초안의 사진 속 순서·건너뛴 단어·보관함 |
| `packages/core/test/library/library_service_test.dart` (다시 씀) | 번호·DAY·쪽 없이 저장, D10 12단어의 저장·학습 순서, 다음 쪽은 뒤에, 같은 시각 두 번 저장, 앞 버전 단어의 DAY·번호 그대로 |
| `packages/core/test/extract/high_confidence_counts_test.dart` | D1·D2 합성 단어장 값·높음 하한(20.3절) |
| `packages/jmdict_block/test/{android_catchup,high_confidence,vocab_catchup}_local_test.dart` | D4~D6 로컬 세트를 앱과 같은 초안으로(경로 선택 → 추출기), 하한 20.3절 |
| `packages/storage_drift/test/contract/*.dart` | 다른 쪽 저장 뒤 학습 상태·숨김 그대로, D10 사진 순서(InMemory·drift 둘 다) |
| `app/test/features/review_heading_test.dart` (새) | D11 머리(쪽 정보 없음), 새 교재 「내 단어장」으로 저장(번호·DAY·쪽 없음, `template_id` 없음) |
| `app/test/features/review_marks_test.dart` (다시 씀) | D11 표제어 후보 칩, 의심·추정 표시, 고치기, 고른 후보는 자동 보정이 아님 |
| `packages/core/test/capture/headword_pick_test.dart` (새) | 가나로 남은 표제어에 한자 후보를 고르면 그 가나가 읽기가 됨, 읽기가 전혀 없으면 「확인 필요」 |
| 걷어낸 테스트 | core 21개 파일(+부분 2), jmdict_block 3, dict_jmdict 4, app 2, 통합 1 (G0 목록대로) |

결과: core **337** · dict_jmdict **11** · jmdict_block **6**(로컬 지정 **15**) · krdict_block **80** · storage_drift **124** · app **132** 통과, analyze 문제 없음,
Android 채널 11 · iOS RunnerTests 5 통과, 생성기 `--check` 2개 같음. 커버리지 core 92.9%, app 90.8%.

### 20.6 빌드와 시뮬레이터 (iPhone 17, 합성 샘플만)

`flutter build apk --debug --flavor dev` 성공.
`flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/word_book_screenshots_test.dart`(실제 JMdict·한국어 뜻 사전 asset):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `48_capture_word_book_samples.png` | 등록: 합성 단어장 샘플 |
| `49_review_word_book.png` | 검토 머리 「단어 12개 · 샘플 10쪽 · 판독 n초」, 높음·확인 필요·자동 보정 |
| `50_review_word_book_read_back.png` | 체크박스로 지워진 표제어를 읽기·뜻으로 되살린 낱말, 표제어 후보 칩 |
| `51_review_word_book_examples.png` | 예문이 있는 쪽: 예문·번역, 문장에서 나온 낱말 |
| `52_home_after_word_book_save.png` | 두 쪽 저장 뒤 홈 |
| `53_textbook_new_words.png` | 교재: 새 단어가 사진 속 순서로(「DAY 모름」 묶음) |

예전 틀 검토 화면 스크린샷(03·10·11·12·19·20·23·34~36)은 앞 절의 기록으로 남깁니다.


## 21. 재생목록: 교재·DAY를 걷어내고 재생목록으로 단어 모으기 (저장 스키마 v4, 2026-11-06)

어떤 교재인지 자동으로 가리지 않습니다. 사진을 인식해 검토한 뒤 「단어 N개 추가」를 누르면 어느 재생목록에 넣을지 고릅니다. 단어는 라이브러리에 한 번만 있고 재생목록이 그 단어를 가리킵니다. DAY·UNIT 같은 묶음은 학습자가 재생목록으로 만듭니다.

### 21.1 결정

| 항목 | 결정 |
|---|---|
| 같은 단어의 기준 | **표제어만**: `wordKey` = NFKC, 공백 제거, 한자가 있는 표제어 끝의 な형용사 「だ」 제거(추출기가 한 쪽 안에서 같은 단어를 합치는 기준 `headwordKey`와 같음). 읽기는 넣지 않음(읽기 가나는 판독 오류가 가장 많고 여러 개일 수 있음). 같은 한자 다른 단어(上手 じょうず/うわて 등)는 하나로 합쳐짐 |
| 같은 단어가 여러 재생목록에 | 단어 하나, **학습 기록 하나를 공유**. 「재생목록마다 따로」는 설정에 「준비 중」으로 보이고 저장 구조(`scope` 칸)만 준비 |
| 다른 목록에 있는 단어를 다시 추가 | 저장된 내용(읽기·뜻·예문)과 학습 기록 그대로 **연결만**. 검토 화면에서 그 항목에 「이미 라이브러리에 있음 · 저장된 뜻 유지」, 요약에 「이미 있는 단어 n개는 저장된 뜻을 그대로 써요」 |
| 같은 목록에 같은 단어 | 하나만(DB 기본 키 + 서비스), 스낵바 「… · 이미 있음 k」 |
| 어느 목록에도 없게 된 단어 | **라이브러리에 남김**. 어디에도 안 보이고 학습(전체 포함)에도 안 나오며, 다시 추가하면 기록이 이어짐 |
| 숨긴 단어(이미 알아요)가 사진에 다시 | 추출에서 뺌(요약 「숨긴 단어 n개는 뺐어요」). 추출에 넘기는 `knownHeadwords`가 라이브러리 전체에서 **숨긴 단어만**으로 바뀜(추출 규칙은 그대로) |
| 숨김 | 단어 단위(모든 재생목록에서 숨겨짐) |
| 재생목록 이름 | 비면 안 됨, 다른 목록과 같으면 안 됨(앞뒤 공백·대소문자·NFKC 폭 무시) |
| 학습 범위 | 기본: 「오늘 학습 시작」은 전체(어느 재생목록에든 있는 단어, 각 단어 한 번), 「재생목록 골라 학습」은 목록 하나 |
| 기존 데이터 | v1~v3 파일은 **옮기지 않고 비움**(아래 21.2) |

### 21.2 스키마 v4와 v3 이하 파일

| 테이블 | 내용 |
|---|---|
| `words` | `id`, `key`(유일), `headword`, `readings`(JSON), `pos`, `meaning`, `example_ja`·`example_ko`(둘 다 있거나 없음), `created_at`, `hidden_at`. 교재·DAY·번호·쪽 열 없음. 새 단어 id는 `w<저장 시각 µs>-<순번 4자리>` |
| `playlists` | `id`, `name`(빈 이름 CHECK), `created_at`, `position`(홈·편집 화면 순서) |
| `playlist_words` | 기본 키 (`playlist_id`, `word_id`), `position`(목록 안 순서, 추가할 때 뒤에), `added_at`. 목록·단어 FK `ON DELETE CASCADE`, 색인 `playlist_words_by_word` |
| `review_cards` | 기본 키 (`scope`, `word_id`), 단어 FK `ON DELETE CASCADE`. `scope`: `''` 공유(지금 유일하게 씀), `p:<목록 id>` 목록마다 따로(나중) |
| `review_logs` | `scope` 칸 더함(오늘 외운 수를 모드별로 셀 수 있게). 단어 FK 없음(기록은 역사) |
| `settings` | 키-값. `study.record_mode`(`shared`/`per_playlist`), `study.scope_mode`(`all_or_playlist`/`playlist_only`). 모르는 값은 기본값으로 읽고 행은 그대로 둠 |

- `schemaVersion` 3 → 4. `onUpgrade`에서 `from < 4`이면 **트랜잭션 하나로** 파일의 모든 테이블·뷰·트리거(색인은 테이블과 함께)를 지우고 v4를 만듭니다. 옛 단계(v1→v2 표 다시 만들기, v2→v3 열 더하기)는 밟지 않습니다. 이상한 옛 데이터 때문에 그 단계가 실패해 앱이 열리지 않는 길을 없애기 위해서입니다.
- 비우기가 실패하면 트랜잭션이 되돌려 옛 파일이 그대로 남습니다. drift는 마이그레이션에 실패한 연결을 계속 실패시키므로, `appDatabaseProvider`가 만들어질 때마다 **새 연결**을 엽니다(`startup.dart`). 홈의 「다시 불러오기」가 그 provider부터 다시 만들어 새 연결로 다시 시도합니다.
- 지운 데이터는 SQLite 빈 페이지에 남을 수 있습니다(`VACUUM`은 트랜잭션 안에서 못 돌림). 앱 전용 폴더라 그대로 둡니다.
- 생성 파일: 덤프 `drift_schema_v4.json`, `database.g.dart`, `database.steps.dart`(Schema4, 앱은 쓰지 않음), 테스트 도우미 `schema_v4.dart`·`schema.dart`. `build_runner build`, `make-migrations`, `schema generate`를 다시 돌려도 다섯 파일이 바뀌지 않음.

### 21.3 포트·유스케이스

- `LibraryRepository`: `words({playlistId})`(null이면 어느 목록에든 있는 단어를 만든 순), `wordsByKey`, `insertWords`(같은 key·id면 `DuplicateWordException`, 아무것도 안 씀), `playlists`·`savePlaylist`·`deletePlaylist`(단어는 안 지움), `playlistStats`(한 쿼리: 단어 수·숨김 수·마지막 추가), `addToPlaylist`(뒤에 붙임, 있는 단어는 제자리), `removeFromPlaylist`→`restoreEntries`(되돌리기는 제자리로), `playlistsOf`.
- `ReviewRepository`: 모든 읽기·쓰기에 `CardScope`(기본 공유). 새 포트 `StudyPreferencesRepository`(`load`·`save`).
- `LibraryService`: `createPlaylist`·`renamePlaylist`·`deletePlaylist`(남은 목록 번호 다시 매김)·`reorderPlaylists`, `previewAdd`(라이브러리에 있는 key, 목록마다 이미 있는 수), `addDraft(draft, to: ExistingPlaylist | NewPlaylist)`(새 목록 만들기까지 트랜잭션 하나), `addWords`(다른 목록에 추가), `removeWords`·`restoreWords`, `playlistView`.
- `StudyService.summary/startSession({scope: AllWords() | PlaylistOnly(id)})`. 카드 scope는 `cardScopeFor` 한 곳에서 정하고 지금은 늘 공유(설정에 「따로」가 저장돼 있어도 공유로 동작).

### 21.4 화면

| 화면 | 동작 |
|---|---|
| 홈 | 오늘 카드(전체), 「오늘 학습 시작 · n장」, 재생목록이 있으면 「재생목록 골라 학습」. 「재생목록」 머리와 「편집」, 목록 타일(「단어 n개 · 숨김 k개」). 비었으면 「페이지를 등록하고 재생목록에 단어를 모아 보세요」. 앱바에 설정·정보 |
| 검토 | 교재 줄 없음. 아래 버튼 「단어 N개 추가」 → 재생목록 고르기 시트 → 추가 뒤 홈, 스낵바 「'목록'에 단어 n개 추가 · 이미 있음 k」 |
| 재생목록 고르기 시트 | 「어느 재생목록에 추가할까요?」, 「새 재생목록」(목록이 없으면 처음부터 펼침, 이름 기본 「내 단어장」, 중복이면 「같은 이름의 재생목록이 있어요」), 마지막에 추가한 목록이 위, 줄마다 「단어 n개 · 이미 있음 k」 |
| 재생목록 화면 | 단어(목록 순서)·기억 단계, 「이 목록 학습」, 단어 메뉴 「이 목록에서 빼기」(되돌리기)·「다른 목록에 추가」, 숨기기·숨긴 단어 펼치기, 메뉴 「이름 바꾸기」·「삭제」(「단어와 학습 기록은 남아요」) |
| 재생목록 편집 | 끌어서 순서 바꾸기, 줄 메뉴 「위로 옮기기」·「아래로 옮기기」·「이름 바꾸기」·「삭제」, 「새 재생목록」 |
| 학습 범위 시트 | 「무엇을 학습할까요?」: 전체와 목록마다 「복습 d · 새 단어 n」, 할 것 없는 줄은 「오늘 할 것 없음」으로 비활성 |
| 설정 | 학습 기록: 재생목록끼리 공유 / 재생목록마다 따로(준비 중, 비활성). 학습 범위: 전체 복습 + 재생목록 골라 학습 / 항상 재생목록 하나씩(준비 중, 비활성). 화면 읽기에 선택 상태 |

`flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/playlists_screenshots_test.dart` (메모리 DB, 합성 샘플, 실제 JMdict·한국어 뜻 사전 asset):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `54_home_no_playlists.png` | 빈 홈 |
| `55_review_add_button.png` | 검토: 「단어 N개 추가」 |
| `56_picker_first_playlist.png` | 첫 재생목록: 폼이 펼쳐져 「내 단어장」 |
| `57_picker_new_playlist_name.png` | 목록이 있을 때 새 재생목록 이름 입력 |
| `58_home_playlists.png` | 두 목록이 있는 홈, 「재생목록 골라 학습」 |
| `59_review_in_library.png` | 같은 쪽 다시: 「이미 라이브러리에 있음 · 저장된 뜻 유지」 |
| `60_picker_already_in.png` | 고르기 시트: 최근 목록이 위, 「이미 있음 12」 |
| `61_playlist_screen.png` | 재생목록 화면 |
| `62_playlist_word_menu.png` | 단어 메뉴(빼기·다른 목록에 추가) |
| `63_study_scope_sheet.png` | 학습 범위: 전체 41(두 목록의 12+29에서 겹친 12를 한 번), 목록마다 |
| `64_study_all.png` | 전체 학습 카드 |
| `65_settings.png` | 설정(준비 중 비활성) |
| `66_playlists_edit.png` | 재생목록 편집 |

앞 절의 교재·DAY 스크린샷(14·15·16·26·53 등)은 기록으로 남깁니다.

### 21.5 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/library/playlist_service_test.dart` (새, `library_service_test.dart` 대체) | 목록 만들기(이름 정리·빈 이름·같은 이름: 공백·대소문자·폭 무시)·이름 바꾸기·순서·삭제(단어·기록 남김, 번호 다시 매김), 초안 추가(사진 순서, 같은 목록 두 번 → 하나·이미 있음 1, 초안 안 중복, 다른 목록 단어 연결·카드 하나·내용 그대로, だ·공백 같은 단어, 목록 밖 단어가 기록과 함께 돌아옴, 없는 목록·이름 충돌이면 아무것도 안 남음, 같은 시각 두 번 저장), 미리보기, 다른 목록에 추가, 빼기·되돌리기, 숨김은 단어 단위 |
| `packages/core/test/study/study_scope_test.dart` (새) | 전체·목록 범위의 오늘 복습·새 단어, 두 목록의 단어는 전체에서 한 번, 숨긴 단어는 둘 다에서 빠짐, 한 목록에서 공부하면 다른 목록에도 반영(카드 하나), 빼기·목록 삭제 뒤 범위와 카드, 「따로」 값이 저장돼도 공유로 동작 |
| `packages/core/test/models_and_ports_test.dart` 외 | `wordKey`, `Playlist`·`PlaylistEntry`·`CardScope`·`StudyPreferences`, 인메모리 저장소 트랜잭션·scope·설정, 기존 학습·숨김 테스트를 재생목록 기준으로 |
| `packages/storage_drift/test/contract/repository_contract.dart` (다시 씀, InMemory·drift 둘 다) | 단어 key 유일·한 번에 1200개, 목록 순서·추가·빼기·되돌리기·삭제·`playlistsOf`, 목록 통계 한 쿼리, 트랜잭션, 카드·기록 scope, 유스케이스(공유 기록, 사진 순서, 오늘 외운 수 04시 경계) |
| `…/contract/hidden_words_contract.dart`, `preferences_contract.dart`(새) | 숨김(목록 밖 숨긴 단어 포함, 모든 목록에서 숨김), 설정 저장·복원(따로 모드 값 포함)·모르는 값은 기본값 |
| `packages/storage_drift/test/migrations/migration_test.dart` (다시 씀) | 지금 스키마 = v4 덤프, 빈 v1·v2·v3 → v4 검증, 데이터가 있는 v1·v2와 **디스크의 v3 파일**(교재 2·DAY 3·단어 40·카드 25·기록 25·앱이 만들지 않은 색인) → 빈 v4·새 DB와 같은 객체·추가와 학습 정상·다시 열면 v4 데이터 유지, **비우기 중 실패 → v3 파일 그대로(버전·객체·모든 행), 다음 연결에서 비워짐** |
| `packages/storage_drift/test/drift_storage_test.dart` | v4 테이블, 외래 키(목록·단어·카드), 목록 안 중복·key 유일·빈 이름을 표가 막음, scope 저장, 시간·읽기 형식, v4 파일 다시 열기 |
| `app/test/app/storage_retry_test.dart` (새) | 실제 v3 파일 위에서 앱 시작 → 빈 홈, 샘플 캡처 → 추가 → 홈에 목록, 앱 다시 열어도 유지; 비우기 실패 → 「불러오지 못했어요」·옛 파일 그대로 → 「다시 불러오기」가 새 연결로 비우고 빈 홈 |
| `app/test/features/playlist_picker_test.dart`·`playlist_screen_test.dart`·`playlists_edit_test.dart`·`study_scope_test.dart`·`settings_screen_test.dart`·`home_playlists_test.dart`·`known_hide_playlist_test.dart` (새) | 고르기 시트, 재생목록 화면(학습·빼기·되돌리기·다른 목록·이름 바꾸기·삭제), 편집(만들기·이름·삭제·옮기기), 학습 범위 시트, 설정(준비 중 비활성·화면 읽기), 홈 타일·숨김 수 |
| 기존 앱 테스트 | 캡처·검토(「단어 N개 추가」, 이미 라이브러리에 있음 표시, 숨긴 단어만 뺌), 시작(새 연결 다시 열기), 블록 지도 |

- 테스트 동결은 두 단계(core·storage_drift 먼저, app 뒤)로 했고, 동결 뒤 발견한 테스트 결함 7개(레코드 안 리스트 비교, 백그라운드 isolate가 감싼 오류, 옛 문구 등)는 승인을 받아 고쳤습니다.
- 추출 회귀(`eval_extract.dart`, 로컬 세트 15개): 이 변경 전과 같음(추출 규칙 그대로, `headwordKey`는 `models/word_key.dart`로 옮기기만).

결과: core **361** · storage_drift **154** · app **170** · jmdict_block **6**(로컬 지정 **15**) · krdict_block **80** · dict_jmdict **11** 통과, analyze 문제 없음, Android 채널 11 · iOS RunnerTests 5 통과, `flutter build apk --debug --flavor dev` 성공.

## 22. 「높음」 되살리기: 흐린 판독의 짝, 체크박스 열 자국 (2026-11-06)

틀 경로를 걷어낸 뒤(20절) 교재 단어장 쪽의 높음이 줄었습니다(Vision 43 → 20). 원인은 판독 신뢰도 최저(0.3) 조각이 낀 짝을 높음에서 막는 관문이었습니다.
Vision은 멀쩡히 읽은 줄에도 0.3을 흔히 줍니다. 규칙은 `docs/extraction.md` 4.4절 「흐린 판독」, 흔적 규칙은 12.3절입니다.
추출 값(표제어·읽기·뜻·순서·여분)은 바꾸지 않았습니다(아래 체크박스 규칙이 고친 한 쪽만 예외).

### 22.1 측정 (규칙을 정하기 전, 실제 JMdict·한국어 뜻 사전, 교재 쪽은 숫자만)

- 교재 Vision 5쪽에서 높음이 아닌 맞는 낱말 39개 중 18개가 **0.3 관문 하나에만** 막혔습니다(다른 높음 조건은 모두 채움).
  7개는 0.3 + 다른 관문(뜻이 위치뿐이거나 사전으로 채운 뜻), 7개는 뜻이 위치뿐, 4개는 사전이 준 표제어.
- 0.3 조각이 낀 짝(합성·로컬·스캔 쌍)에서 내용 근거(한자음·뜻 사전)를 가진 짝은 모두 맞음(합성 2, 로컬 27, 스캔 쌍 14). 틀린 짝은 1개이고 그 뜻은 위치뿐이었습니다.
  앱 채널 세트의 여분 낱말에는 0.3 조각이 없습니다.
- 후보 비교(높음 / 높음인데 틀림 / 여분인데 높음): 0.3 관문을 없애기만 하면 실데이터 숫자는 같지만 **모든 줄을 0.3으로 낮춘 시험**에서 합성 범용 쪽의 읽기 없는 가나 낱말이
  여분인데 높음이 됩니다. 뜻에 내용 근거 둘을 요구하면 Vision 31(목표 35 미달). 그래서 「같은 낱말의 사전 읽기 + 내용 근거 뜻(강한 위치)이 뒷받침」으로 정했습니다.

### 22.2 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 흐린 판독의 짝 | `packages/core/lib/src/extract/confidence.dart` | 0.3 조각 때문에만 막힌 짝은, 같은 낱말의 읽기가 사전 일치(높음 조건)이고 뜻이 한자음·뜻 사전 근거 + 배치 0.85 이상(높음 조건)이면 둘 다 높음. 뒷받침이 없으면 중간 그대로 + 설명 「글자가 흐릿하게 읽힘」(`faintReadNote`, 검토 화면 근거 조각에 보임). 이웃 경쟁·공통 관문은 그대로 |
| 체크박스 열 자국 | `packages/core/lib/src/extract/read_back.dart` | 상자 글자 + 체크 표시 한 자 이하이고 같은 열에 상자 줄이 둘 이상 더 있으면 판독 실패 흔적이 아님 → 체크 표시된 상자 옆 가나 표제어(합성 s010 `ちょっと`)에 역조회 후보가 붙지 않음 |

### 22.3 결과 (표제어 기준, 실제 JMdict·한국어 뜻 사전)

| 세트 | 높음 전 → 후 | 하한 | 값 (찾음 · 읽기 · 뜻 · 여분) |
|---|---|---|---|
| 교재 단어장 5쪽 Vision (로컬) | 20 → **38** | 36 | 59/59 · 59 · 58/59 · 0 (그대로) |
| 같은 5쪽 ML Kit 조각 (로컬) | 37 → **38** | 37 | 58/59 · 58 · 57/58 · 1 (그대로) |
| 휜 쪽 실기기 (로컬, 기록 그대로 / 빈 칸 대시를 一 0.5로 읽은 변형) | 6 → **8** / 6 → **8** | 7 | 15/15 · 15 · 15 · 0 (그대로) |
| 다른 교재 3쪽 (로컬) | 8 → 8 | 8 | 15/15 · 15 · 11/15 · 4 (그대로) |
| 스캔 쌍 휜 쪽 원본 / 스캐너 앱 | 6 → 9 / 8 → 10 | 6 / 8 | 그대로 |
| 스캔 쌍 예문 쪽 원본 / 스캐너 앱 | 5 → 7 / 6 → 8 | 5 / 6 | 그대로 |
| 스캔 쌍 다른 교재 원본 / 스캐너 앱 | 8 → 8 / 6 → 8 | 8 / 6 | 원본 그대로, **스캐너 앱 14/15 → 15/15 · 15 · 9/14 → 10/15 · 여분 6 → 5** (22.4) |
| 합성 단어장 4쪽 / ML Kit형 2쪽 | 24 → 24 / 13 → 13 | 24 / 13 | 그대로 |
| 합성 범용 g01~g11 | 42 → **44** (g10의 표제어 0.3 `庭`, 읽기 0.3 `鏡`) | 44 | 70/70 · 70 · 68/68 · 0 (그대로) |
| 합성 Android / 함정 | 20 → 20 / 2 → 2 | 20 / 2 | 그대로 |

- **전 세트 높음인데 틀림 0, 여분인데 높음 0.** 모든 줄(두 패스, 일본어만, 한국어만)을 0.3으로 낮춘 시험에서도 0입니다(ML Kit 낱말 단위 참고 세트는 앱이 쓰지 않아 제외).
- 값 불변 확인: 로컬·합성 15세트의 검토 초안 값(표제어·읽기·뜻·예문, 순서)을 규칙 전에 기록해 두고 비교했습니다(기록은 로컬 전용). 채점기의 틀린 목록도 같습니다.

### 22.4 체크박스 열 자국

| 세트 | 바뀐 것 |
|---|---|
| 합성 s010 | `ちょっと`(왼쪽 `ロロレ`) 표제어 후보 2 → 0, 뜻 설명 「표제어 자리 판독 실패」 없어짐 |
| 합성 g01 | `すっかり`(열 위 홀로 `口`) 같은 설명 없어짐 |
| 다른 교재 3쪽·스캔 쌍 다른 교재 | 가나 표제어의 같은 설명 없어짐(신뢰도 그대로) |
| 스캔 쌍 다른 교재 스캐너 앱 1쪽 | 인쇄된 가타카나 표제어를 역조회로 한자로 바꾸던 것이 인쇄 그대로 → 찾음 +1, 여분 −1 |

진짜 흔적(표제어 열의 0.3 오독 `己`·`目` 등)은 그대로 되살립니다.

### 22.5 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/faint_read_test.dart` (새) | 0.3 표제어·읽기·뜻(기기 채널 값 포함) + 사전 읽기 + 뜻 사전 근거 + 강한 위치 → 높음. 하나씩 빼기(사전에 없는 읽기, 먼 읽기, 위치뿐인 뜻, 아래로 밀린 뜻, 읽기 없는 가나 낱말) → 높음 아님·설명. 이웃 같은 읽기(g21)·같은 뜻(g23)을 흐리게 읽어도 높음 아님. 사전 역조회 표제어·표제어 후보·흔적 있는 가나는 높음 아님. 합성 세트 높음 하한, 모든 줄 0.3 시험 |
| `packages/core/test/extract/checkbox_marks_test.dart` (새) | s010 `ちょっと` 후보 없음, 열 위 `ロロレ`·`ロレ`·`ロ`·`口口` → 흔적 아님(가나 그대로·후보 없음), 열 밖·체크 표시 둘·열 반복 없음 → 흔적, 표제어 열의 `己` → 후보 그대로 |
| `packages/jmdict_block/test/high_recovery_local_test.dart` (새, 로컬) | 16세트 하한·값·높음인데 틀림 0·여분인데 높음 0, 규칙 전 값 기록과 비교, 모든 줄 0.3 시험 세 변형 (숫자만 출력) |
| `packages/core/test/extract/confidence_rules_test.dart` | 「0.3이면 높음 아님」 → 「0.3이고 뜻이 뒷받침하지 않으면 높음 아님」 |

### 22.6 시뮬레이터 (iPhone 17, 합성 샘플만)

`flutter drive … --target=integration_test/faint_read_screenshots_test.dart` (실제 JMdict·한국어 뜻 사전 asset):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `67_review_checkbox_no_candidates.png` | s010 검토: 체크 표시된 상자 옆 `ちょっと`에 표제어 후보 칩 없음 |
| `68_review_faint_read.png` | s140 검토: 읽기를 흐리게 읽고 뜻이 없는 `到着時刻`는 읽기 중간 |
| `69_evidence_faint_read.png` | 그 읽기의 근거 조각: 「출처: 사진 · 짝 신뢰도 중간 · 글자가 흐릿하게 읽힘」 |

합성 샘플 쪽에는 규칙으로 높음이 된 낱말이 없습니다(합성 0.3 줄이 있는 g10은 샘플이 아님). 높음 수가 늘어나는 것은 22.3절의 숫자로 확인했습니다.

## 23. 사전 asset 무결성 검사와 정기 갱신 도구 (2026-11-06)

자세한 절차는 docs/dictionary.md 12절입니다. 앱은 여전히 네트워크를 쓰지 않습니다.

### 23.1 바꾼 것

| 무엇 | 어디 | 내용 |
|---|---|---|
| 앱 풀기 검증 | `app/lib/adapters/unpacked_asset.dart` | 풀 때 gzip 크기 → 푼 크기 → sha256(백그라운드 isolate, 맞을 때만 파일을 씀), 평소에는 파일 크기만. 어긋나면 `UnpackedAssetMismatch`, 파일·표시 남기지 않음 |
| 원인 갈래 | `app/lib/adapters/dictionary_problem.dart`, `bundled_dictionary.dart`, `bundled_glossary.dart` | `missing`·`damaged`·`failed` (`problemKind`) |
| 다시 시도 | `app/lib/app/startup.dart` | 시작 때 연 것은 첫 build만 쓰고, 다시 build되면 새로 엶 |
| 안내 | `app/lib/shared/dictionary_notice.dart`, 캡처·검토·정보 화면 | 「사전을 열지 못했어요」+ 원인별 문구 + 「다시 시도」, 검토 화면은 한 줄(사전 없이 읽은 쪽은 다시 시도가 성공해도 「다시 등록하면 사전으로 읽어요」로 남음). 문구는 `DictionaryNoticeText` 한 곳 |
| 정보 화면 | `app/lib/features/about/about_screen.dart` | JMdict 카드에 「변환(가공)한 사본, CC BY-SA 4.0」과 CC BY-SA 4.0 링크, 손상·실패면 원인별 안내 |
| 배포 전 검사 | `tools/dict/asset_check.py`, `build_app_asset.py --check`, `build_ko_glossary.py --check` | 필드·크기·sha256·DB 안 meta, `--max-age-days`(기본 꺼짐) |
| 갱신 도구 | `tools/dict/refresh.py` | 조건부 요청 → 내려받기 확인 → 후보 빌드 → 정확도 관문 → 채택(`--dry-run`) |
| 의존성 | `app/pubspec.yaml` | `crypto`(이미 간접 의존성, BSD-3-Clause) |

### 23.2 측정

| 측정 | 결과 |
|---|---|
| 지금 asset 4개 대조 (JMdict 2026-11-04판, 한국어기초사전 2026-10-19판) | gzip 크기·푼 크기·sha256 모두 판 정보와 같음 |
| Dart `gzip.decode`에 잘린 gzip | 앞 절반: 오류 없이 절반 크기로 풀림. 끝 8바이트·1바이트 없음: 오류 없음. CRC·본문 비트 변경: `FormatException` |
| sha256 (`package:crypto`, 데스크톱 Apple Silicon, AOT) | JMdict 30.5 MB 123–145 ms, 한국어 뜻 9.4 MB 37 ms (gzip 풀기는 각각 47–69 ms, 14 ms) |
| 시뮬레이터 iPhone 17 Pro (debug), 실제 asset, 처음 실행(풀기+검증) | JMdict **477 ms**, 한국어 뜻 **110 ms** (배경 isolate, 첫 화면을 기다리게 하지 않음) |
| 같은 시뮬레이터, 다음 실행(크기만) | JMdict **3 ms**, 한국어 뜻 **1 ms** |

### 23.3 새 판 시험 (`refresh.py --dry-run`, asset은 바꾸지 않음)

JMdict 2026-11-04판 → **2026-11-06판**(gzip 12,200,998 → 12,202,352, SQLite 30,539,776 → 30,543,872). 한국어기초사전은 같은 판이라 변화 없음. 내려받기·빌드·관문 약 43초.

| 세트 | 찾음 | 읽기 | 뜻 | 여분 | 높음 | 높음인데 틀림 | 여분인데 높음 |
|---|---|---|---|---|---|---|---|
| 합성 범용 | 70 → 70 | 70 → 70 | 68 → 68 | 0 → 0 | 42 → 42 | 0 → 0 | 0 → 0 |
| 합성 단어장 | 33 → 33 | 33 → 33 | 32 → 32 | 2 → 2 | 24 → 24 | 0 → 0 | 0 → 0 |
| 합성 ML Kit형 | 17 → 17 | 17 → 17 | 16 → 16 | 1 → 1 | 13 → 13 | 0 → 0 | 0 → 0 |
| 로컬 기록 6세트(단어장 Vision·ML Kit, 휜 쪽, 다른 교재, 예문 쪽 원본·스캔 앱) | 모두 같음 | 모두 같음 | 모두 같음 | 모두 같음 | 모두 같음 | 0 | 0 |
| 로컬 하한 테스트(새 asset) | 12개 통과 | | | | | | |

관문 통과. 새 판으로 바꿔도 점수 변화가 없었습니다.

### 23.4 스크린샷 (iPhone 17 Pro, 합성 샘플만)

`flutter drive -d <iPhone 17 Pro> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/dictionary_check_screenshots_test.dart` (메모리 DB, 실제 asset; 시간 측정은 임시 폴더에 풂):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `70_about_dictionary_converted.png` | 정보: JMdict 변환(가공) 표시·CC BY-SA 4.0 링크·판, 한국어기초사전 출처 |
| `71_capture_dictionary_damaged.png` | 캡처: 사전 손상 안내와 「다시 시도」 |
| `72_review_without_dictionary.png` | 검토: 「사전 없이 읽은 결과예요」 한 줄과 「다시 시도」 |
| `73_about_dictionary_damaged.png` | 정보: 손상 안내(「들어 있지 않아요」가 아님) |

### 23.5 테스트

| 파일 | 내용 |
|---|---|
| `tools/dict/test_asset_check.py` (새, 17) | 맞으면 통과, sqlite sha256·gzip 크기·sqlite 크기 불일치, 잘린 gzip, 필드 빠짐(6가지), 파일 없음, JSON 아님, DB meta와 판 정보 불일치, 나이 검사(기본 꺼짐), 빌드 스크립트 `--check` |
| `tools/dict/test_refresh.py` (새, 20) | 304·같은 파일·같은 zip이면 변화 없음(파일 그대로), 새 JMdict·새 기초사전 → 빌드·관문·채택, `--dry-run`, 보고서, 관문 미달(종료 1), 내려받기 실패·잘림·gzip 아님·머리말 날짜 없음(종료 2, 그대로), 점수표 읽기·나빠짐 판정 |
| `app/test/adapters/unpacked_asset_test.dart` (새) | 맞는 asset, sha256·크기·gzip 크기 불일치, 잘린 asset, 새 판 거부 뒤 다음 실행, 평소 실행(크기만), 판 정보 필드 |
| `app/test/adapters/bundled_dictionary_test.dart`·`bundled_glossary_test.dart` | 원인 갈래(`missing`·`damaged`·`failed`), 불일치면 남기지 않음 |
| `app/test/features/dictionary_notice_test.dart` (새) | 캡처·검토·정보 화면 안내, 손상이 실패보다 먼저, asset 없는 빌드는 안내 없음, 다시 시도 성공·실패, 학습 화면은 그대로 |
| `app/test/features/about_editions_test.dart` (새) | 정보 화면의 두 사전 출처·판·라이선스·가공 표시 |
| `app/test/app/no_network_test.dart` (새) | 앱·패키지 직접 의존성에 네트워크 클라이언트 없음, `lib/`에 연결 코드 없음, Android 배포 매니페스트에 INTERNET 없음 |
| `app/test/app/startup_test.dart` | 다시 시도 = 다시 열기 |

결과: tools/dict **70** · app **201** · dict_jmdict **11** · jmdict_block **15**(로컬 지정 포함) · krdict_block **80** 통과, analyze 문제 없음, 생성기 `--check` 3개 통과.


## 24. 뜻 품질: 품사 힌트, 한자음 일치, 예문 번역, 뜻 후보 칩 4개 (2026-11-06)

사진에 뜻이 없어 한국어 뜻 사전으로 채우는 뜻의 1순위와, 검토 화면의 「뜻 후보」 칩을 고쳤습니다. 사진에서 읽은 뜻·표제어·읽기·여분·짝 신뢰도는 바꾸지 않았습니다.
규칙은 `docs/extraction.md` 4.5절, 뜻 사전의 품사 칸은 `docs/dictionary.md` 11.2·11.4절입니다. 교재 쪽은 숫자만 적습니다.

### 24.1 측정 (규칙을 정하기 전, 실제 JMdict·한국어 뜻 사전 2026-10-19판)

- 전 세트(15)에서 사전으로 채운 뜻 465개. 그중 정답 파일에 뜻이 있는 것은 15개(1순위 맞음 12)이고, 나머지는 예문에서 나온 낱말입니다.
- 11.5절의 74단어 표본(정답 표제어·읽기로 조회): 1순위 47(63.5%), 3순위 안 58, 5순위 안 61.
- 1순위를 놓친 27개의 갈래: 숫자 한자 3, 한자어·고유어 동의 4, 품사 다름 2, 다의어 4, 같은 뜻 안의 낱말 순서 5, 구로 옮기는 말·사전에 없음 9.
- 사진 뜻인데 칩이 보이는 항목 77개(사진 뜻이 틀렸고 정답이 칩에 있는 것 6). 그대로 둡니다.
- 품사 힌트의 출처: 채운 뜻 465개 중 사진 배지가 있는 것 0(배지는 뜻 조각 앞에 있어 함께 없음) → 채우는 뜻은 JMdict 품사, 사진 뜻의 칩은 배지.

### 24.2 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 뜻 사전 스키마 2 | `tools/dict/build_ko_glossary.py`, `tools/dict/testdata/ko_pos_codes.json` | 뜻마다 한국어 품사 `sense.pos`(정수). 같은 원본·판, lean 9,478,144 bytes / gzip 3,664,720 |
| 포트 | `packages/core/lib/src/ports/korean_glossary.dart` | `lookup(..., pos: PartOfSpeech?)` |
| 블록 | `packages/krdict_block/lib/src/krdict_glossary.dart`, `korean_pos.dart` | 스키마 1·2를 엶. 힌트 갈래의 뜻을 「맞은 방식」 다음 열쇠로 앞에(굵은 갈래, 접사·어미·품사 없음은 중립). 스키마 1이면 힌트 무시 |
| 채우는 뜻·후보 | `packages/core/lib/src/extract/meaning_senses.dart`, `general_extractor.dart` | 짝짓기 조회(묶음 3, 힌트 없음)와 뜻 조회(묶음 5, 힌트: 배지 > JMdict)를 나눔. 한자음 일치(2음절 이상, 숫자 1음절, 접사 제외) → 예문 낱말은 번역에 나오는 묶음 → 1순위 뜻, 후보 최대 4개 |
| 배지 | `extracted_word.dart` | `ExtractedWord.printedPos`(뜻 앞에 인쇄된 배지) |
| 신뢰도 | — | 바꾸지 않음(`confidence.dart` 그대로). 채운 뜻은 언제나 중간 |

### 24.3 결과

| 측정 | 전 | 후 | 하한 |
|---|---|---|---|
| 74단어 1순위 | 47 (63.5%) | **54 (73.0%)** | 54 |
| 74단어 5순위 안(칩 범위) | 61 (82.4%) | **63 (85.1%)** | 63 |
| 세트의 정답 있는 채운 뜻 1순위 | 12/15 | 12/15 | 12 |
| 전 세트 채운 뜻 465개 중 1순위가 바뀐 것 | — | 54 | |

세트별 회귀(표제어 기준, 실제 JMdict·새 뜻 사전): 찾음·읽기·뜻·여분과 높음 수가 15세트 모두 규칙 전과 같습니다.

| 세트 | 높음 (하한) | 찾음 · 읽기 · 뜻 · 여분 |
|---|---|---|
| 교재 단어장 5쪽 Vision (로컬) | 38 (36) | 59/59 · 59 · 58/59 · 0 |
| 같은 5쪽 ML Kit 조각 (로컬) | 38 (37) | 58/59 · 58 · 57/58 · 1 |
| 휜 쪽 실기기 (로컬) | 8 (7) | 15/15 · 15 · 15 · 0 |
| 다른 교재 3쪽 (로컬) | 8 (8) | 15/15 · 15 · 11/15 · 4 |
| 스캔 쌍 휜 쪽 원본 / 스캐너 앱 | 9 / 10 | 15 · 15 · 15 · 0 / 14 · 14 · 14 · 1 |
| 스캔 쌍 예문 쪽 원본 / 스캐너 앱 | 7 / 8 | 12 · 12 · 12 · 0 / 같음 |
| 스캔 쌍 다른 교재 원본 / 스캐너 앱 | 8 / 8 | 15 · 15 · 11 · 6 / 15 · 15 · 10 · 5 |
| 합성 단어장 4쪽 / ML Kit형 2쪽 | 24 / 13 | 33 · 33 · 32 · 2 / 17 · 17 · 16 · 1 |
| 합성 범용 g01~g11 | 44 (44) | 70/70 · 70 · 68/68 · 0 |
| 합성 Android / 함정 | 20 / 2 | 29 · 29 · 21 · 3 / 6 · 6 · 6 · 0 |

- **전 세트 높음인데 틀림 0, 여분인데 높음 0, 사전으로 채운 뜻 중 높음 0.**
- 값 불변 확인: 15세트 검토 초안의 항목 값(표제어·읽기·품사·뜻·뜻 출처·칸 신뢰도·표제어 후보·예문·표시)을 규칙 전에 기록해 두고 비교했습니다(기록은 로컬 전용).
  바뀐 것은 사전으로 채운 뜻과 뜻 후보뿐입니다.
- 옛 뜻 사전(스키마 1)으로 열면 품사 힌트 없이 전과 같은 순서입니다(앱이 새 asset으로 바뀌기 전에도 동작).
  판 정보 JSON이 바뀌므로(`schema` 2, `sqlite_sha256`) 앱은 다음 실행 때 asset을 다시 풉니다(`unpacked_asset.dart`가 판 정보 글을 비교).
- 같은 줄 뒤의 뜻(`관련어 … 명 도착 시각`)은 보류했습니다(`docs/extraction.md` 11절).

### 24.4 테스트

| 파일 | 내용 |
|---|---|
| `packages/krdict_block/test/pos_hint_test.dart` (새, 12) | 힌트 갈래가 앞으로·걸러 내지 않음·맞는 갈래가 없으면 그대로·상한 전에 적용, 용언 갈래(일본어 동사 → 한국어 형용사), 접사는 내리지 않음, 맞은 방식이 먼저, 스키마 1 견본은 모든 힌트에 같은 순서·스키마 2와 같은 묶음, 품사 코드표 |
| `packages/core/test/extract/meaning_fill_test.dart` (새, 17) | 힌트 출처(배지 > JMdict > 없음), 짝짓기 조회 불변(묶음 3·힌트 없음), 한자음 일치(2음절·하다·숫자·1음절 아님·접사 아님), 후보 최대 4개·순서, 사진 뜻 불변, 예문 번역(명사·활용한 동사·안 나오면 그대로) |
| `packages/jmdict_block/test/meaning_quality_local_test.dart` (새, 로컬, 3) | 74단어 하한, 세트의 채운 뜻 12/15, 15세트 값 비교(채운 뜻·후보만 바뀜)·점수·높음 하한·틀림 0 |
| `app/test/features/meaning_candidates_test.dart` (새, 2) | 검토 화면: 첫 묶음이 뜻, 다음 4개 칩이 순서대로, 6번째 없음, 고른 뜻이 저장됨 |
| `tools/dict/test_build_ko_glossary.py` | 스키마 2·품사 칸·코드표 |
| 고친 것 | 포트 인자에 맞춘 테스트 대역 3곳, `ranking_extra_test.dart`(견본 행에 품사 칸), `high_recovery_local_test.dart`(채운 뜻은 값 비교에서 뺌 — 위 로컬 테스트가 지킴) |

다시 만드는 명령(asset, 원본 zip은 저장소 밖):

```bash
python3 tools/dict/build_ko_glossary.py --source <krdict_json.zip> \
    --expect-sha256 c8f9ffbf7e9be1f1ec86fa29e4160a75eee8044fc081c27788dadf3ceb66d34e --built-on 2026-11-06
python3 tools/dict/asset_check.py
```


## 25. release 빌드의 사전 검사 (2026-11-06)

release 빌드가 `python3 tools/dict/asset_check.py --release`를 돌려, 판 정보와 어긋난 사전과 35일보다 오래된 JMdict의 배포를 막습니다.
debug·profile은 막지 않습니다. 규칙과 이유는 `docs/dictionary.md` 12.2·12.4절, 빌드 단계는 `docs/architecture.md` 5.2절입니다.

| 무엇 | 어디 | 내용 |
|---|---|---|
| 검사 | `tools/dict/asset_check.py --release` | 두 사전의 판 정보 대조 + JMdict `built_on` 기한 `RELEASE_MAX_AGE_DAYS`(35, 한 곳). 실패하면 고치는 명령 |
| Android | `app/android/app/build.gradle.kts` `checkReleaseDictionary` | 파일 있음 → PATH의 python3 → 검사. `preProdReleaseBuild`가 의존 |
| iOS | Runner 셸 단계 「Release checks (flavor, dictionary)」 | `Release*`에서 같은 순서. 실패 출력의 줄마다 `error:` |

### 25.1 확인 (Apple Silicon 데스크톱, 서명 없음)

「오래됨」은 asset 복사본의 판 정보 두 개 모두 `built_on`을 40일 전(2026-09-27)으로 바꾼 것입니다. 확인 뒤 되돌렸습니다.

| 빌드 | asset | 결과 |
|---|---|---|
| `flutter build ios --flavor prod --release --no-codesign` | 지금 판(JMdict·한국어 뜻 2026-11-06 빌드) | 성공 |
| 같은 명령 | 오래됨 | 실패: `jmdict-full-lean: built_on 2026-09-27 is 40 days old (limit 35)` · `Too old (JMdict, limit 35 days): refresh with: python3 tools/dict/refresh.py` (한국어 뜻 사전은 40일이어도 ok) |
| `flutter build ios --flavor prod --profile --no-codesign` | 오래됨 | 성공 |
| `flutter build apk --flavor prod --release` | 지금 판 | `checkReleaseDictionary` 통과(두 사전 ok) 뒤 `preProdReleaseBuild`의 서명 검사에서 멈춤(이 컴퓨터에 `key.properties` 없음) |
| 같은 명령 | 오래됨 | `checkReleaseDictionary`에서 실패, 위와 같은 메시지 |
| `./gradlew :app:checkReleaseDictionary` (PATH에 python3 없음) | 지금 판 | 실패: `python3 is not on PATH; the release dictionary check (tools/dict/asset_check.py) needs it.` |
| iOS 셸 단계 (PATH에 python3 없음, 단계만 실행) | 지금 판 | 같은 뜻의 `error:`로 실패 |
| `./gradlew :app:<작업> --dry-run` | | `assembleProdRelease`·`bundleProdRelease`에 `checkReleaseDictionary` 있음. `assembleProdDebug`·`assembleProdProfile`·`assembleDevDebug`·`assembleDevProfile`에는 없음 |

### 25.2 테스트

| 파일 | 내용 |
|---|---|
| `tools/dict/test_asset_check.py` (+9) | 기한 35일, JMdict 35일 통과·36일 실패(날짜 주입, `--max-age-days 35`도 같은 경계), 한국어 뜻 사전은 36일이어도 통과·어긋나면 실패, `--release`가 오늘 기준 35·36일, 오래됨 → `refresh.py` 안내, 어긋남 → 그 사전의 빌드 명령만 안내, `--release`와 `--max-age-days`는 함께 못 씀 |

결과: tools/dict **82**(macOS 기본 python3 3.9로도 `test_asset_check` 통과) · app **203** 통과, `flutter analyze` 문제 없음, 생성기 `--check` 3개 통과.


## 26. 활용형 원형, 한국어 판독의 영문 찌꺼기, 문장 안 쓰임 (2026-11-06)

실기기(iPhone) 실사용 쪽 하나(대화 + 단어 상자)에서 나온 세 문제를 고쳤습니다. 규칙은 `docs/extraction.md` 3.2·3.3·14절입니다. 교재 쪽은 숫자만 적습니다.

### 26.1 측정 (규칙을 정하기 전, 실제 JMdict 2026-11-06판·한국어 뜻 사전)

**활용형.** 16세트(15세트 + 실사용 쪽)의 문장 166개, lattice 토큰 1,024개에서 원형이 아닌 채 나온 문장 낱말은 활용 어간이 명사로 읽힌 것 8곳(4쪽, 같은 낱말)뿐이었습니다.
어간형 명사인데 뒤에 활용 꼬리가 없는 것 23곳(진짜 명사·부사)은 보존 대상입니다. 원인은 문법 표현 항목이 활용 꼬리를 먹는 것(`docs/extraction.md` 3.2절).
되읽기 규칙은 8곳을 모두 원형으로 바꾸고 그 밖에는 바꾸지 않았고, 지어낸 구 30개(실제 JMdict)에서 명사 그대로여야 할 것을 하나도 바꾸지 않았습니다.

**영문 찌꺼기.** 로컬 판독 242쪽의 「한글 + 라틴 글자」 고유 줄 402개를 사람이 판정했습니다: 실제 한국어 + 찌꺼기 154, 줄 전체가 엉터리 161, 실제 한국어 + 진짜 영문 26, 쪽 머리·꼬리 띠 61.
지어낸 「진짜 영문이 든 뜻」 40줄(TV를 보다, e메일, T셔츠, 1kg, A4, 비타민C …)로 오탐을 따로 쟀습니다.

| 규칙 (줄에 하나라도 걸리면 찌꺼기) | 402줄 정밀도 · 재현율 | 한국어가 있는 241줄 정밀도 · 재현율 | 지어낸 진짜 영문 40줄 오탐 |
|---|---|---|---|
| 대소문자 섞임 | 0.959 · 0.295 | 0.913 · 0.273 | 1 |
| 숫자 바로 뒤 영문 | 0.913 · 0.302 | 0.866 · 0.377 | 4 |
| 한글에 바로 붙음 | 0.989 · 0.578 | 0.973 · 0.461 | 13 |
| 괄호 짝 안 맞음 | 1.000 · 0.159 | 1.000 · 0.169 | 0 |
| `~` 바로 뒤 영문 | 1.000 · 0.022 | 1.000 · 0.045 | 0 |
| 「진짜 영문 꼴」이 아니면 찌꺼기 | 0.953 · 0.959 | 0.909 · 0.968 | 19 |
| **채택**: 위 + 단위·대문자 한 자·`e`+한글·하이픈 낱말 허용 + `~` 뒤 | **0.952 · 0.756** | **0.912 · 0.812** | **0** |

- 채택 규칙의 오탐 12(241줄)는 모두 판독 오류가 섞인 쪽 머리 띠·음원 안내 줄(숫자와 붙어 읽힌 대문자, 숫자를 글자로 읽은 파일 확장자)이고, 놓침 29는 대부분 て형의 て를 대문자로 읽은 문형 상자의 표지 줄(조각 수집에서 이미 잡음)입니다.
- **최종 뜻 칸 기준:** 채점 16세트 918항목(사진 뜻 386) 중 라틴 글자가 든 뜻 3개는 모두 찌꺼기이고 모두 골라냄. 전 242쪽 6,048항목에서는 찌꺼기 6개 6/6, 진짜 영문(머리 띠가 뜻으로 들어간 것) 8개 중 오탐 0.
- 처리 방식 비교(찌꺼기가 든 괄호만 지움 / 갈래 지움 / 같은 자리 일본어로 바꿈 / 표시만)는 실사용 쪽 뜻 1개에서 「괄호만 지움」만 정답과 같아졌고, 「같은 자리 일본어」는 바꿀 조각이 없었습니다 → 괄호 → 갈래 → 표시 순서로 정함(`docs/extraction.md` 14절).

**같은 쪽의 다른 관찰.** 사전으로 채운 뜻 하나가 드문 부사 뜻이 된 것은 2026-11-06 뜻 품질(24절)의 회귀가 아니었습니다(그 전에도 다른 틀린 뜻).
문장에서 な형용사로 쓰였는데 JMdict 첫 품사 부사가 힌트가 된 것이 원인이라 문장 안 쓰임 품사를 넣었습니다. 쪽 아래 단원 번호 띠는 쪼갠 한자어 줄이 문장으로 처리된 것이었습니다.

### 26.2 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 활용 어간 되읽기, な 명령형 제한 | `packages/core/lib/src/extract/lattice.dart` (`readStem`) | 3.2절 |
| 쓰임 품사, 숫자 뒤 조수사, 쪼갠 줄 예문, 어간 흡수 | `sentence_usage.dart`, `general_extractor.dart` | 3.3절. 뜻 조회 힌트: 배지 > 쓰임 품사 > JMdict |
| 영문 찌꺼기 | `latin_debris.dart`, `general_extractor.dart`, `extracted_word.dart` | 14절. 검토 초안의 뜻 칸에 「영문 찌꺼기 뺌」(자동 보정됨) 또는 「판독 불확실: 영문 찌꺼기」 |
| 신뢰도·저장 | — | 바꾸지 않음(`confidence.dart`, 저장 스키마 그대로) |

### 26.3 결과 (실제 JMdict·한국어 뜻 사전)

| 세트 | 높음 (하한) | 찾음 · 읽기 · 뜻 · 여분 (전 → 후) |
|---|---|---|
| 교재 단어장 5쪽 Vision (로컬) | 38 (36) | 59/59 · 59 · 58/59 · 0 (그대로) |
| 같은 5쪽 ML Kit 조각 (로컬) | 38 (37) | 58/59 · 58 · 57/58 · 1 (그대로) |
| 휜 쪽 실기기 (로컬) | 8 (7) | 15/15 · 15 · 15 · 0 (그대로) |
| 다른 교재 3쪽 (로컬) | 8 (8) | 15/15 · 15 · 뜻 11 → **12**/15 · 여분 4 → **3** |
| 스캔 쌍 휜 쪽 원본 / 스캐너 앱 | 9 / 10 | 그대로 |
| 스캔 쌍 예문 쪽 원본 / 스캐너 앱 | 7 / 8 | 그대로 |
| 스캔 쌍 다른 교재 원본 | 8 (8) | 뜻 11 → **12** · 여분 6 → **5** |
| 스캔 쌍 다른 교재 스캐너 앱 | 8 (6) | 뜻 10 그대로 · 여분 5 → **4** |
| 실사용 쪽 (로컬, 다른 교재 정답의 같은 쪽으로 채점) | 8 | 13/13 · 13 · 뜻 11 → **12**/13 · 여분 1 → **0** |
| 합성 단어장 / ML Kit형 / 범용 / Android / 함정 | 24 / 13 / 44 / 20 / 2 | 그대로 |

- **전 세트 높음인데 틀림 0, 여분인데 높음 0.** 높음 수는 모든 세트에서 그대로입니다.
- 항목 값 비교(규칙 전 기록과): 바뀐 것은 활용 어간 낱말이 없어지고 원형 하나로 합쳐짐(예문은 원형이 처음 나온 문장), 찌꺼기를 뺀 뜻 1개, 쓰임 품사로 1순위가 바뀐 사전 뜻
  (실사용 쪽의 낱말 4쪽, 단어장의 な형용사 활용 낱말 4쪽 — 후자는 문맥 뜻이 뜻 사전 후보에 없어 좋아짐·나빠짐 없음), 숫자 뒤 조수사 낱말이 없어짐
  (단원 번호 띠 5곳, 체크박스 잡음 줄 `번호+口` 2곳), 단원 번호 띠의 예문 2곳.
- 쓰임 품사는 다음 토큰만이 아니라 토큰 자체의 な형용사 활용(`〜で`·`〜な`·`〜だ`)도 보므로, 26.1의 측정(다음 토큰만 봄)보다 넓게 듣습니다: 단어장 4쪽의 な형용사 활용 낱말 하나도 사전 뜻 1순위가 바뀌었습니다(사전 뜻이라 점수·높음 영향 없음).
- 메모리 사전 합성 세트(`tool/eval_extract.dart`) 점수 그대로.

### 26.4 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/conjugated_stems_test.dart` (새) | 1단·5단·する·い형의 부정 조건·부정 て·과거·정중 → 원형(읽기·품사 원형), 꼬리 없는 명사 보존(`〜なので` 포함), 같은 쪽 흡수(예문 유지·넘김, 독립 명사 근거면 둘 다) |
| `packages/core/test/extract/sentence_usage_test.dart` (새) | 쓰임 품사(だ·な → な형, 동사 → 부사, が → 명사, 근거 없음 → JMdict, 짝짓기 조회 불변), 숫자 뒤 조수사·쪼갠 줄 예문·보관함 |
| `packages/core/test/extract/latin_debris_test.dart` (새) | 찌꺼기 양성 9줄·진짜 영문 42줄, 괄호 → 갈래 → 표시, 검토 초안의 표시 |
| `packages/jmdict_block/test/conj_mixed_local_test.dart` (새, 로컬) | 16세트 값·높음 하한·틀림 0·여분 높음 0, 실사용 쪽 판정 파일(로컬) |
| 고친 것 | 앞 작업의 로컬 테스트 3개: 다른 교재 3판의 값, 규칙 전 기록과의 비교에서 이 작업이 바꾸도록 승인된 항목(로컬 목록 파일)만 뺌 |


## 27. 뒤 부정 부사, 표현 항목의 동사, 문장 낱말 여분, 한국어 설명, 낱말 상자 잇기 (2026-11-06)

다섯 가지 작은 품질 문제를 고쳤습니다. 규칙은 `docs/extraction.md` 2절(관련어 줄, 낱말 상자 잇기)·3.2절(표현 항목 되읽기)·3.3절(뒤 부정, 숫자 뒤 한자 한 글자, 가나 한 글자)·4.5절(뒤 부정의 뜻 순서)입니다.
교재 쪽은 숫자만 적습니다. 신뢰도 규칙(`confidence.dart`)·저장 스키마·사전 asset은 바꾸지 않았습니다.

### 27.1 측정 (규칙을 정하기 전, 실제 JMdict 2026-11-06판·한국어 뜻 사전)

**뒤 부정 부사.** 문장 낱말 중 부사 토큰은 채점 세트 95개, 전 로컬 판독 242쪽 585개이고, 같은 절 뒤에 부정이 있는 것은 28 / 182개입니다.
그중 사전 뜻 후보에 「부정과 함께 쓰는 한국어 부사」(별로·그다지 …)와 아닌 것이 섞인 낱말은 3개뿐이고, 1순위가 바뀌는 것은 1낱말(4쪽)입니다(나머지 둘은 이미 1순위이거나 예문 번역이 1순위를 지킴).
뜻 사전에는 「부정과 함께」 표시가 없어(정의 글을 싣지 않음) 한국어 쪽 닫힌 목록 24개로 정했습니다.

**표현 항목의 동사.** 품사가 `exp`·`adj-f`뿐이고 한자가 든 문장 토큰 중 동사 활용형으로 되읽히는 것은 채점 세트 1,272토큰 중 5곳, 전 242쪽 7,004토큰 중 47곳이고 모두 같은 1낱말입니다.
인사·고정 표현은 쪽에 0곳이라, 사전 전체(그런 표현 316개)와 지어낸 54문장으로 「바꾸지 않을」 조건을 쟀습니다.

| 조건 (하나라도 걸리면 그대로) | 사전 316개 중 막는 수 |
|---|---|
| 품사에 `exp`가 없음(`adj-f`만인 연체 표현) | 85 |
| 정중형 끝(`ます`·`ません`·`ください` …) | 20 |
| 표현의 한자가 동사 원형에 남지 않음 | 16 |
| 부정 활용 | 96 |
| **되읽음** | **119** |

지어낸 54문장에서 인사·고정 표현이 바뀐 것은 0입니다(`お願いします`류는 사전에 그 동사형 항목이 없어 처음부터 해당 없음, 정중형 고정 표현 7개는 조건으로 그대로).

**다른 교재 3판의 여분 12개(3·5·4).** 원인: 줄 끝에서 잘린 낱말의 가나 한 글자가 동사로 읽힘 1, 판독 오류 1, 관련어 줄(`*낱말：뜻`)의 뜻 자리를 일본어 패스가 한자로 읽어 쪼개짐 5,
숫자에 붙은 한자 한 글자 2, 줄 끝이 잘린 낱말의 뒷부분·접두 한자 2, 판독 찌꺼기 조각 속 진짜 낱말 1. 앞의 셋(8개)에 일반 규칙을 넣고 남는 4개는 보류했습니다.
규칙마다 전 242쪽 값을 비교했습니다: 빠지는 것은 모두 문장 낱말(판독 찌꺼기 줄·조수사 쓰임)이고 단어 목록 낱말 손실은 0입니다.
일본어 줄의 `：`를 모두 자르는 안은 합성 g01 대화의 말하는 사람 이름을 깨뜨려 별표로 시작하는 줄로 한정했습니다.

**낱말 상자.** ML Kit 낱말 단위 판독(앱이 쓰지 않는 채널, 참고 세트)의 높음인데 틀림 5는 모두 한 줄이 낱말 상자 여러 개로 와서 뜻 한 조각만 짝지어진 것입니다(상자 간격은 높이의 0.4~0.8배).
간격·높이만 보는 잇기는 조각 단위·Vision 판독에서도 따로 읽힌 배지(`명`·`8`)와 뜻을 이어 값이 바뀌었고(높음 38 → 39 등), 방향이 틀린 판독 변형에서는 다른 뜻 칸끼리 이었습니다 →
배지만·숫자만인 상자, 배지로 시작하는 상자, 옆으로 누운 글을 빼는 조건을 넣었습니다.

### 27.2 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 뒤 부정 부사 | `sentence_usage.dart` (`negatedLater`), `extracted_word.dart` (`negated`), `meaning_senses.dart` (`negativePolarityWords`, `orderMeaningSenses(negated:)`), `general_extractor.dart` | 3.3·4.5절. 사전으로 채우는 뜻과 후보 칩의 순서만 |
| 표현 항목의 동사 | `lattice.dart` (`readExpression`) | 3.2절. 표면·위치 그대로, 읽기·품사는 동사 |
| 문장 낱말 여분 | `general_extractor.dart` (`_isSentenceWord`), `sentence_usage.dart` (`isCounterAfterNumber`), `fragment_collector.dart` (관련어 줄) | 2·3.3절 |
| 한국어 설명 | `general_extractor.dart` | 짝 설명 `사전 뜻`·`사전 읽기가 여럿`·`사전에는 다른 읽기`(검토 화면 근거 조각에 보임). 판정·값은 그대로 |
| 낱말 상자 잇기 | `touching_boxes.dart` (새), `fragment_collector.dart` | 2절 |

### 27.3 결과 (표제어 기준, 실제 JMdict·한국어 뜻 사전)

| 세트 | 높음 (하한) | 찾음 · 읽기 · 뜻 · 여분 (전 → 후) |
|---|---|---|
| 교재 단어장 5쪽 Vision (로컬) | 38 (36) | 59/59 · 59 · 58/59 · 0 (그대로) |
| 같은 5쪽 ML Kit 조각 (로컬) | 38 (37) | 58/59 · 58 · 57/58 · 1 (그대로) |
| 같은 5쪽 ML Kit 낱말 단위 (로컬, 참고) | 27 → **36** (36) | 57/59 · 57 · 뜻 30 → **56**/57 · 9, 높음인데 틀림 5 → **0** |
| 휜 쪽 실기기 (로컬) | 8 (7) | 15/15 · 15 · 15 · 0 (그대로) |
| 다른 교재 3쪽 (로컬) | 8 (8) | 15/15 · 15 · 12/15 · 여분 3 → **1** |
| 스캔 쌍 휜 쪽 원본 / 스캐너 앱 | 9 / 10 | 그대로 |
| 스캔 쌍 예문 쪽 원본 / 스캐너 앱 | 7 / 8 | 그대로 |
| 스캔 쌍 다른 교재 원본 | 8 (8) | 15 · 15 · 12 · 여분 5 → **2** |
| 스캔 쌍 다른 교재 스캐너 앱 | 8 (6) | 15 · 15 · 10 · 여분 4 → **1** |
| 실사용 쪽 (로컬) | 8 | 13/13 · 13 · 12/13 · 0 (그대로) |
| 합성 단어장 / ML Kit형 / 범용 / Android / 함정 | 24 / 13 / 44 / 20 / 2 | 그대로 |

- **전 세트 높음인데 틀림 0, 여분인데 높음 0**(낱말 단위 참고 세트 포함). 높음 수는 낱말 단위 세트 밖에서 그대로입니다. 모든 줄을 0.3으로 낮춘 시험(22절)도 그대로 0입니다.
- 값 비교(규칙 전 기록과, 검토 초안의 모든 칸·근거 조각 설명): 낱말 단위 세트 밖에서 바뀐 것은 승인한 항목뿐입니다 — 뒤 부정 낱말의 사전 뜻 1순위(4쪽)·후보 순서(1쪽),
  표현 항목이 동사로(5쪽), 빠진 문장 낱말(가나 한 글자 2쪽, 숫자 뒤 한자 한 글자 7쪽, 관련어 줄 조각 4쪽), 관련어 줄의 낱말(4쪽, 뜻은 짝짓기로, 중간).
- **낱말 상자 잇기는 조각 단위·Vision 판독에서 한 번도 일어나지 않습니다**: 앱 채널 세트의 검토 초안 값이 바이트 단위로 같고, 전 로컬 판독 242쪽에서 이어지는 곳은 낱말 단위 쪽뿐입니다.
- 한국어 설명 3개는 채점 세트의 값에 나타나지 않고(전 242쪽에서 3항목), 메모리 사전 합성 세트(`tool/eval_extract.dart`) 점수 그대로입니다.

### 27.4 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/negated_adverb_test.dart` (새) | 뒤 부정이면 부정과 함께 쓰는 뜻이 1순위, 없으면 그대로, 이미 1순위·그런 뜻 없음·번역이 부름, 목록 24개, 문장 낱말(절이 끊기면 그대로) |
| `packages/core/test/extract/expression_verbs_test.dart` (새) | 과거형 표현 항목 → 동사(읽기·품사·위치), 문장 낱말, 그대로인 것(정중형·부정·adj-f만·동사형 아님) |
| `packages/core/test/extract/sentence_noise_test.dart` (새) | 가나 한 글자 표면, 숫자 뒤 한자 한 글자(숫자 없음·두 글자는 낱말), 관련어 줄(별표·전각 별표, 별표 없는 대화 줄은 그대로) |
| `packages/core/test/extract/korean_notes_test.dart` (새) | 세 설명 문구, 합성 쪽 모든 설명에 라틴 글자 없음 |
| `packages/core/test/extract/touching_boxes_test.dart` (새) | 맞닿은 상자 잇기·순서 무관·좁은 한 글자, 따로 두는 것(간격·줄·높이·배지만·숫자만·배지로 시작·옆으로 누운 글·일본어), 이을 것 없으면 같은 목록, 조각 수집 |
| `packages/jmdict_block/test/small_quality_local_test.dart` (새, 로컬) | 16세트 값·높음 하한·틀림 0·여분 높음 0, 규칙 전 기록과 값 비교(승인 항목만 뺌), 낱말 단위 세트 하한, 승인 항목 판정(로컬 판정 파일) |
| 고친 것 | 앞 작업의 로컬 테스트 4개: 다른 교재 3판의 여분 값. 규칙 전 기록과의 비교에서 빼는 승인 항목 목록(로컬 파일)에 이 작업의 항목을 더함 |

결과: core **554**(새 39) · jmdict_block **27**(로컬 포함) · app **203** 통과, analyze 문제 없음, 생성기 `--check` 3개 통과.

### 27.5 시뮬레이터 (iPhone 17, 합성 샘플만)

`flutter drive … --target=integration_test/korean_notes_screenshots_test.dart` (실제 JMdict·한국어 뜻 사전 asset):

| 파일 (`docs/screenshots/`) | 화면 |
|---|---|
| `74_evidence_dictionary_meaning.png` | s147 문장 낱말 `返品`의 사전 뜻 근거 조각: 「출처: 사전 · 짝 신뢰도 중간 · 사전 뜻」, 영문 설명 없음 |

읽기 칸의 두 설명(`사전 읽기가 여럿`·`사전에는 다른 읽기`)은 합성 샘플에 해당 항목이 없어 단위 테스트(`korean_notes_test.dart`)로 확인했습니다.

## 28. 발음: 기기 안 VOICEVOX, 음 높이 선, 예문 재생 (2026-11-06)

학습 카드에 단어·예문 재생 버튼과 음 높이 선을 넣었습니다. 설계와 흐름은 `docs/pronunciation.md`, 엔진·데이터 정확도 측정은 `research/tts/README.md`입니다.
학습 순서(SRS) 규칙·저장 스키마·추출기·사전 색인은 바꾸지 않았습니다. 자동 재생은 없고 버튼으로만 재생합니다.

### 28.1 방식 비교 측정 (이 기능을 넣기 전)

기기 내장 TTS도 같은 28단어(「단어+が」, `research/tts/words.tsv`)로 녹음해 `research/tts/tools/measure_wavs.py`로 쟀습니다(macOS Kyoko 기준선의 README 숫자를 그대로 재현해 도구를 확인).

| 방식 | 엄격 일치 | 마지막 박 제외 | 최소쌍 대비 | 같은 읽기를 같은 소리로 |
|---|---|---|---|---|
| iOS 시뮬레이터 AVSpeechSynthesizer Kyoko(기본 품질, 시뮬레이터에 있는 유일한 일본어 음성) | 12/28 | 18/28 | 7/8 | 箸=端 |
| Android 에뮬레이터 Google TTS 기기 음성 `ja-jp-x-htm-local` | 13/28 | 18/28 | 7/8 | 없음 |
| VOICEVOX + 악센트 지정(README 3절) | 엔진 악센트 값 28/28 | | 24/24 (3음성) | 없음 |

- 기기 내장 TTS는 악센트를 지정할 수단이 없었습니다: iOS `AVSpeechSynthesisIPANotationAttribute`는 「첫머리를 높일지」만 바뀌고 일부 음이 빠졌고, Android SSML `phoneme`은 음성마다 해석이 달랐습니다.
- iOS enhanced·premium 음성은 시뮬레이터에서 받지 못해(음성 목록이 빔) 재지 못했습니다. Android의 다른 기기 음성 3개는 에뮬레이터에서 엔진이 멈춰(SIGILL) 재지 못했습니다.
- 그래서 VOICEVOX를 앱에 넣고, Kanjium에 없는 단어까지 엔진이 읽도록 Open JTalk 사전 전체를 함께 넣었습니다.

### 28.2 동작 확인 (iPhone 17 Pro 시뮬레이터, iOS 26.5)

`integration_test/speech_screenshots_test.dart`(메모리 DB, 지어낸 카드 2장: Kanjium에 있는 「箸」·예문 「箸で食べます。」, 없는 「食べました」).

| 확인 | 결과 |
|---|---|
| 첫 재생에서 발음 asset 풀기·대조 | 약 1.4초(`unpacked voicevox-0.17.1-0vvm-style2`) |
| 단어 재생 → 캐시 WAV | 1개, 실패 안내 없음 |
| 예문 재생(표제어 악센트 고정) | 캐시 2개, 실패 안내 없음 |
| Kanjium에 없는 단어: 읽기를 열면 엔진 추정 선 + 「추정」, 재생 | 食べました가 LHHLLL(3)로 그려짐, 캐시 3개 |
| 정보 화면 「발음」 카드 | 크레딧·라이선스·Kanjium 문구 |

| 스크린샷 | 내용 |
|---|---|
| `80_study_word_speech.png` | 단어 재생 뒤 카드(읽기·뜻 가림, 예문 옆 재생 버튼) |
| `81_study_pitch_line.png` | 읽기를 연 「箸」: はし 위 음 높이 선(높음→낮음, 조사 자리 옅게) |
| `82_study_example_speech.png` | 예문 재생 뒤, 뜻·번역을 연 카드 |
| `83_study_estimated_accent.png` | Kanjium에 없는 「食べました」: 엔진 추정 선과 「추정」 |
| `84_about_voice_credits.png` | 정보 → 발음: VOICEVOX:四国めたん, VOICEVOX core·ONNX Runtime·Open JTalk 사전·Kanjium(CC BY-SA 4.0) |

Android 에뮬레이터(Medium Phone, Android 16, arm64, Google Play 이미지)에서도 같은 시나리오가 통과했습니다: 발음 asset 풀기 약 2.5~3.0초, 단어·예문·추정 단어 재생 후 캐시 WAV 3개, 실패 안내 없음, 정보 화면 크레딧.
엔진은 `jniLibs/arm64-v8a`의 `.so` 세 개(16KB 정렬), 재생은 `MediaPlayer`입니다. 스크린샷은 iOS 것만 저장소에 둡니다.

### 28.3 테스트

| 묶음 | 파일 | 내용 |
|---|---|---|
| 요청 → 엔진 입력 | `packages/voicevox_block/test/{pronunciation,speech_plan,speech_renderer}_test.dart` | 발음 가나(おう·えい·ー, 동사 끝 う), 악센트 표시 가나, 값 없음 → 표기·읽기 순서로 엔진 읽기, 예문의 표제어 고정(긴 말 안이면 고정 안 함, 평판은 구 박 수), 엔진 추정 악센트(「+が」, 한 구일 때만) |
| 악센트 표 | `accent_table_test.dart`, `morae_test.dart`, app `accent_data_test.dart` | (표기, 읽기) 조회·여러 값·가나 단어·없음, 박 나누기와 높낮이 패턴, asset 크기·sha256 대조 |
| 캐시 | `speech_cache_test.dart`, `speech_renderer_test.dart` | 두 번째는 합성 안 함, 크기 상한(오래 안 쓴 것부터), 망가진 WAV 다시 합성, 키 형식 |
| 재생 버튼 | app `word_card_speech_test.dart`, `study_speech_test.dart` | 한 번 누르면 요청 한 번, 다시 누르면 다시 재생, 합성 중 「불러오는 중」·누름 무시, 실패해도 카드 유지·안내, 예문 버튼, 음 높이 선(읽기 열 때만, 추정 표시, 추정은 한 번만 물음) |
| asset 무결성 | app `voice_assets_test.dart`, `voicevox_speech_test.dart`; `tools/dict/test_asset_check.py`, `tools/voice/test_*.py` | 크기·sha256이 다르거나 파일이 없으면 엔진을 열지 않고 안내, 경로 탈출 거부, 다시 풀기; 같은 내용의 빌드 도구·release 검사 |
| 표기 | app `about_voice_credits_test.dart` | 정보 화면의 크레딧과 Kanjium 문구 |
| 엔진 파일·압축 풀기 | `tools/dict/test_speech_engine_check.py`, `tools/voice/test_voice_native_links.py` | release 검사의 `--engine android|ios`(엔진 파일이 없거나 비면 실패), 앱과 같은 gzip 이름 규칙, 링크 연쇄·같은 이름 두 번 거부 |
| 재생 경로 | Android `AudioPathTest.kt` | 캐시 폴더 안 실제 파일만, 옆 폴더·`..`·폴더 자체·없는 파일·밖을 가리키는 링크 거부(API 24에서도 도는 문자열 비교) |
| 네트워크 | app `no_network_test.dart` (검사 목록에 `packages/voicevox_block` 추가) | 통과 |

결과: core **555** · voicevox_block **63**(새) · app **248** · tools/dict **112**(+30) · tools/voice **47**(새) · iOS RunnerTests · Android 단위 **15**개(+4, `AudioPathTest`) 통과, `flutter analyze`·`dart analyze` 문제 없음, 생성기 `--check` 3개 통과, `asset_check.py`·`--release` 모두 ok.

- `no_network_test.dart`가 새 패키지 `packages/voicevox_block`도 검사합니다(의존성 `crypto`·`shiori_core`, 연결 코드 없음).

## 29. 학습한 단어 다시 학습: 더 학습하기, 처음부터 다시 학습, 전체 초기화 (2026-11-07)

새 단어를 처음 보자마자 「알고있음」하면 4단계(21일 뒤)로 가고, 학습은 때가 된 카드만 고르므로 그동안 그 단어를 다시 볼 길이 없었습니다.
복습 간격 규칙(4절 학습 규칙)은 그대로 두고, 학습한 단어로 돌아가는 길을 셋 더했습니다. 저장 스키마는 v4 그대로입니다(카드 행만 지움).

### 29.1 동작

| 기능 | 자리 | 동작 |
|---|---|---|
| 더 학습하기 | 홈 큰 버튼, 재생목록 화면 학습 버튼(오늘 할 것이 없을 때 그 자리), 학습 화면 「지금 학습할 카드가 없어요」·「오늘 학습 끝」 | 복습할 때가 안 된 카드만, 기억 단계 낮은 것 → 복습 날짜 이른 것 → 단어 순서로 최대 10장(`dailyGoal`). 숨긴 단어·때가 된 카드·새 단어는 고르지 않습니다. 고를 카드가 없으면 버튼이 없습니다(홈·재생목록은 지금처럼 꺼진 버튼). 세션 머리 글자는 「더 학습하기」 |
| ㄴ 알고있음 | | 카드(단계·다음 복습·횟수) 그대로. 누른 기록은 남아 「오늘 n개 외움」에 셉니다. 버튼 아래 시간은 남은 시간(다음 복습까지) |
| ㄴ 다시 학습 | | 평소와 같음: 1단계·지금 복습·잊은 횟수 +1. 같은 세션에서 다시 나와 알고있음하면 평소 규칙(min(현재, 2) 또는 1단계) |
| 처음부터 다시 학습 | 재생목록 화면 단어 줄 ⋮ 메뉴(카드가 있는 단어만) | 그 단어의 카드를 지워 새 단어로. 확인 창 없이 바로, 스낵바 「「語」 새 단어로 돌렸어요 · 되돌리기」. 되돌리기는 그 사이 다시 학습하지 않았으면 원래 카드로. 누른 기록·숨김은 그대로 |
| 모든 단어 처음부터 다시 학습 | 설정 → 학습 기록 | 확인 창(「모든 단어를 처음부터 다시 학습할까요?」, 학습한 단어 수, 「취소」/「처음부터」) 뒤에만 모든 카드를 지움. 누른 기록·숨김·재생목록·단어는 그대로. 학습한 단어가 없으면 줄이 꺼짐 |

### 29.2 설계

- 포트 `ReviewRepository`에 `deleteCards(wordIds, {scope})`(지운 카드를 돌려줌, 없는 id는 건너뜀)와 `deleteAllCards({scope})`(null이면 모든 scope, 지운 수)를 더했습니다. 하나로 합치지 않은 것은 인자를 빠뜨려 전부 지우는 일을 막기 위해서입니다.
  drift는 500개씩 `IN`으로 읽은 뒤 같은 조각을 지우고, 모두 트랜잭션 하나입니다. `review_logs`에는 FK가 없어 카드를 지워도 기록은 남습니다.
- `StudyService`: `startMoreSession`(`SessionBuilder.buildMore`), `resetWords`·`restoreCards`·`resetAll`(각각 트랜잭션 하나), `StudySummary.aheadCount`(숨기지 않은 단어 중 때가 안 된 카드 수 — 버튼을 보일지 정함).
- 앞당긴 카드는 `SessionItem.ahead`로 표시합니다(세션을 만들 때 정함, 다시 학습해도 유지). `answer`는 `ahead`이고 이 세션에서 다시 학습하지 않은 카드의 알고있음만 카드를 쓰지 않고 기록만 남깁니다. 평소 세션의 결과는 바뀌지 않습니다.
- 앱: 학습 화면 컨트롤러의 키가 `({scope, more})` 레코드입니다. 학습 화면 안의 「더 학습하기」는 그 화면을 앞당긴 세션으로 바꿉니다(뒤로 가면 원래 화면). 문구는 `app/lib/features/study/restudy_labels.dart` 한 곳에 있습니다.
- G2: 테이블·열 변경 없음, `schemaVersion` 4 그대로, `dart run build_runner build --delete-conflicting-outputs` 뒤 생성 코드 diff 없음.

### 29.3 테스트

| 묶음 | 파일 | 내용 |
|---|---|---|
| 앞당긴 세션 고르기 | core `test/study/session_builder_more_test.dart` | 때가 안 된 카드만·단계 → 날짜 → 단어 순서, 숨김·때가 된 카드·새 단어 제외, 상한, 지금 막 때가 된 카드는 제외, `ahead` 표시가 다시 학습 뒤에도 유지 |
| 유스케이스 | core `test/study/restudy_service_test.dart` | 단어 초기화(새 단어로 다음 세션에 나옴, 다른 카드·기록 그대로, 없는 id, 숨김 유지, 되돌리기·그 사이 학습한 단어 건너뜀), 전체 초기화(모든 scope, 기록·숨김·재생목록 그대로), 앞당긴 알고있음(카드 그대로·기록·오늘 외운 수), 다시 학습·그 뒤 알고있음 평소 규칙, 미리보기 시간, 평소 세션 회귀 |
| 저장소 계약 | storage_drift `test/contract/card_reset_contract.dart`(메모리·drift 같은 테스트) | 지정 scope·단어만 지움, 돌려준 카드, 중복·없는 id, 1,200개(조각 넘김), scope별·전체 삭제 수, 기록 유지, 실패한 트랜잭션은 되돌림 |
| 화면 | app `restudy_playlist_test.dart`, `restudy_study_test.dart`, `settings_reset_test.dart` | ⋮ 메뉴 → 새 단어 → 되돌리기, 새 단어엔 메뉴 없음, 재생목록·홈·학습 화면의 「더 학습하기」(있을 때만), 설정 확인 창·취소·처음부터 |
| 재시작 | app `integration_test/persistence_test.dart` 단계 `restudy`·`restudy-reopen` | 빈 앱에 지어낸 단어 3개(2·4·3단계, 때가 안 됨)를 넣고 홈 「더 학습하기」에서 다시 학습 1번, 재생목록에서 한 단어 처음부터 → 앱을 끄고 다시 열어도 그대로(1단계·잊은 횟수 1, 카드 없음, 나머지 3단계, 기록 1개, 홈 「오늘 학습 시작 · 2장」) |

결과: core **585**(+30) · storage_drift **174**(+20) · app **262**(+14) 통과, `dart analyze`·`flutter analyze` 문제 없음.

### 29.4 시뮬레이터 (iPhone 17, iOS 26.5, 합성 샘플만)

- `persistence_test.dart` 단계 `restudy` → 앱 종료 → `restudy-reopen`: 둘 다 통과(실제 DB 파일).
- `restudy_screenshots_test.dart`(메모리 DB, 샘플 쪽 「DAY 20 여행·교통」을 모두 알고있음으로 학습한 뒤): 통과.

| 스크린샷 | 내용 |
|---|---|
| `85_playlist_word_reset_menu.png` | 재생목록 단어 줄 ⋮ 메뉴: 이 목록에서 빼기 · 다른 목록에 추가 · 처음부터 다시 학습 |
| `86_playlist_word_reset.png` | 처음부터 다시 학습 뒤 스낵바 「「乗り換える」 새 단어로 돌렸어요 · 되돌리기」 |
| `87_playlist_study_more.png` | 모두 때가 안 된 재생목록: 학습 버튼 자리의 「더 학습하기」와 안내 글 |
| `88_home_study_more.png` | 홈: 복습 0 · 새 단어 0일 때 큰 버튼 「더 학습하기」 |
| `89_settings_reset_all_confirm.png` | 설정 → 모든 단어 처음부터 다시 학습의 확인 창 |

## 30. 문장 부호로 끝나는 낱말 상자, 남은 문장 낱말 여분, 재시작 테스트의 샘플 단어 수 (2026-11-07)

남은 작은 품질 세 가지를 다시 봤습니다. 추출 규칙은 바꾸지 않았고, 테스트와 문서만 바꿨습니다.

### 30.1 문장 부호로 끝나는 한국어 상자 (`touching_boxes.dart`)

낱말 상자 잇기(27절)가 잇는 글자는 한글·숫자·뜻 줄 부호뿐이라 `?`·`!`·`？`·`！`·`。`가 든 상자는 처음부터 잇지 않습니다. 이어질 수 있는 문장 끝 부호는 `.`·`．`입니다.
세 가지 안을 실제 JMdict·한국어 뜻 사전으로 쟀습니다. 셋 다 전 로컬 판독 242쪽 중 낱말 단위 판독(앱이 쓰지 않는 참고 채널) 밖에서는 이어지는 줄이 0곳이라,
앱 채널 판독의 검토 초안 값이 바이트 단위로 같습니다. 낱말 단위 세트는 아래처럼 같거나 나빠집니다.

| 안 | 낱말 단위 세트에서 이어지는 줄 | 높음 · 높음인데 틀림 · 뜻 · 여분 | 바뀐 값 |
|---|---|---|---|
| 지금 | 67 | 36 · 0 · 56/57 · 9 | — |
| `.`·`．`로 끝난 상자 뒤로 잇지 않음 | 68 | 36 · 0 · **55**/57 · 9 | 정의 두 개를 `.`으로 이은 뜻 줄이 끊겨 뜻 하나가 반쪽, 짝 없는 조각 1개 더 |
| `?`·`!`·`？`·`！`도 잇는 글자로 | 67 | 36 · 0 · 56/57 · 9 | 판독 찌꺼기와 예문 번역 줄이 이어져 한 예문의 번역 짝이 다른 칸의 뜻으로 바뀜(낱말 8개의 예문) |
| 둘 다 + 그 부호 뒤로 잇지 않음 | 68 | 36 · 0 · **55**/57 · 9 | 위 두 손실이 겹침 |

예문 번역 줄은 일본어 예문도 줄바꿈 자리에서 끊겨 읽히므로 한국어 쪽만 이으면 두 쪽 줄 수가 어긋납니다. 그래서 지금 동작을 그대로 두고 단위 테스트로 못 박았습니다(`docs/extraction.md` 2절).

### 30.2 남은 문장 낱말 여분 (다른 교재 3판 1·2·1)

남은 4개의 원인: 판독 오류로 생긴 낱말 1, 줄바꿈에서 잘린 낱말의 뒷부분 1, 줄 끝에서 잘린 낱말의 앞 한자 1, 판독 찌꺼기 조각 속 진짜 낱말 1. 두 규칙 후보를 쟀습니다.

| 후보 | 여분 (다른 교재 3판) | 문장 단어 재현율 | 전 242쪽 | 판단 |
|---|---|---|---|---|
| 조각 첫 토큰이 가나면 문장 낱말 아님 | 1 · 1 · 1 | 30/33 → 28 · 29 · 28 | 문장 낱말 198개가 빠짐(진짜 낱말 포함) | 넣지 않음 |
| 문장 부호 없이 조각 끝에 걸친 한자 한 글자는 문장 낱말 아님 | 1 · **1** · 1 | 그대로 | 빠지는 문장 낱말 45개(쪽 머리 찌꺼기 등), 단어 목록 낱말 손실 0. 그러나 낱말이 하나도 안 남은 조각 32개가 앱 채널 판독에서도 짝 없는 조각으로 새로 보임 | 넣지 않음 |

둘째 후보는 이득이 여분 1개이고, 앱 채널의 검토 화면이 바뀌며, 부호 없이 한자 한 글자로 끝나는 제목 줄의 낱말을 뺄 수 있어 넣지 않았습니다(`docs/extraction.md` 11절).

### 30.3 재시작 테스트의 샘플 단어 수 (`app/integration_test/persistence_test.dart`)

`save` 단계가 시뮬레이터에서 「단어 6개 추가」를 찾지 못해 실패했습니다(main에서도 같음). 실제 사전으로 예문 샘플 쪽(「DAY 20 여행·교통」)을 읽으면
단어 목록 7개에 예문의 문장 낱말 22개를 더한 29개가 나오고 모두 기본으로 담깁니다. 학습 시작은 하루 목표 10장입니다.
앱 동작은 설계대로이고(3.3절 문장 안 쓰임), 메모리 사전으로 도는 위젯 테스트는 문장 낱말을 내지 않아 차이가 드러나지 않았습니다.

테스트가 단어 수를 박지 않도록 고쳤습니다.

| 단계 | 확인 |
|---|---|
| `save` | 추가 버튼과 학습 시작 버튼의 글에서 단어 수 N·카드 수 M을 읽음, M = min(N, 하루 목표), 첫 카드 다시 학습 + M번 알고있음, 「오늘 M개 외움」, 파일 DB 단어 N개 |
| `reopen` | 「오늘 M개 외움」에서 M, 앱의 추출기·사전으로 같은 샘플을 다시 읽은 단어 수 = 파일 DB 단어 수, 카드 단계 [2, 4 × (M−1)], 기록 M+1 |

iPhone 17 시뮬레이터(실제 사전·발음 asset)에서 `save` → 앱 종료 → `reopen`, `restudy` → 앱 종료 → `restudy-reopen` 모두 통과했습니다(단어 29 · 카드 10 · 기록 11).
`reopen`이 찍는 `16_textbook_after_restart.png`는 바꾸지 않았습니다. `upgrade` 단계는 옛 스키마 빌드가 필요해 이번에는 돌리지 않았습니다.

### 30.4 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/touching_boxes_test.dart` | 맞닿은 상자가 `?`·`!`·`？`·`！`·`。`로 끝나거나 그 부호가 든 상자 앞이면 잇지 않음(같은 목록), `.`·`．`로 끝나는 뜻 줄은 이음, 한 줄씩 떨어진 상자는 같은 목록 |
| `app/integration_test/persistence_test.dart` | 30.3절 |

결과: core **598**(+13) · jmdict_block **27**(로컬 포함) · app **262** 통과, analyze 문제 없음, 생성기 `--check` 3개 통과. 로컬 세트 값은 27절 그대로입니다.


## 31. 위키낱말사전 보조 사전: 기초사전에 없는 낱말의 뜻 (2026-11-07)

사진에 뜻이 없는 사전 낱말 가운데 **한국어기초사전 역색인이 뜻을 하나도 주지 못하는 것만** 위키낱말사전(한국어판 일본어 항목 → 없으면 영어판 번역표)으로 채웁니다.
규칙·판·라이선스는 `docs/dictionary.md` 13절, 원천 조사는 `research/meaning/README.md`입니다. 교재 쪽은 숫자만 적습니다.

### 31.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 영어판 행 | `tools/dict/wikt_en_rows.py` (새) | 영어판 원자료(3.08 GB gzip)를 읽으면서 sha256·크기를 재고, 번역표에 일·한이 함께 있는 영어 뜻만 남김(27,578행) |
| 보조 사전 빌드 | `tools/dict/build_wikt_glossary.py` (새) | 키마다 한국어판 → 없으면 영어판, 기초사전이 답하는 키는 뺌, 기초사전과 같은 schema 2. `--sample-sql`·`--check` |
| 검사 | `tools/dict/asset_check.py` | `wikt-glossary`: release에 필수(없음·깨짐·판 어긋남·곁의 기초사전과 `krdict_sqlite_sha256` 다름 → 실패), 일반 실행은 있으면 검사·없으면 한 줄 |
| core | `ports/fallback_glossary.dart` (새), `general_extractor.dart`, `extracted_word.dart` | `FallbackKoreanGlossary`, `GeneralExtractor(meaningFallback:)` — 빈 뜻을 채울 때만, 모든 표기가 기초사전에 없을 때. `ExtractedWord.meaningGlossary` → 근거 `사전 뜻: 위키낱말사전` |
| 블록 | — | 그대로(`KrdictGlossary`가 보조 사전 파일도 엶, `sense.source` 1 = 위키낱말사전) |
| 앱 | `bundled_glossary.dart`, `blocks.dart`, `about_screen.dart` | 두 asset을 함께 풂(보조 사전이 없으면 로그 한 줄), `wiktionaryGlossaryProvider` → 추출기, 정보 화면 카드·라이선스 페이지 항목 |

### 31.2 결과 (실제 JMdict·기초사전 2026-10-19판·보조 사전)

| 측정 | 전 | 후 |
|---|---|---|
| 74단어 1순위 · 5순위 안 | 54 · 63 | **56 · 65** |
| 15세트 + 실기기 쪽 검토 초안의 빈 뜻 | 49 | 30 (19개 채움: 문맥상 맞음 17, 틀림 1, OCR 조각에 뜻 1) |
| JLPT N5 · N4 · N3 (718 · 668 · 2,140) 중 기초사전이 비는 낱말 | 44 · 49 · 159 | 채움 25 · 27 · 79 (합 131/252) |
| 위 131개의 1순위, 눈으로 본 판정 | — | 맞음 24 · 25 · 73 = **122 (93%)** |
| 앱 asset 증가 | — | gzip 1,461,627 B (SQLite 4,079,616 B) |

- 세트별 찾음·읽기·여분·높음은 모두 그대로이고, 뜻 맞음은 줄지 않았습니다(세트 정답에 있는 낱말 중 채워진 것은 0). **높음인데 틀림 0, 여분인데 높음 0, 보조 사전 뜻 중 높음 0.**
- 값 불변: 같은 실행에서 보조 사전 없이·있이 두 번 뽑아 항목마다 모든 값(표제어·읽기·품사·뜻·예문·표시·칸별 출처·신뢰도·근거·후보·조각 수)을 비교했습니다. 바뀐 항목은 **전에 뜻이 비어 있던 19개뿐**입니다.
- ML Kit 낱말 상자 세트도 하한(높음 36·뜻 56) 그대로입니다.
- JLPT에서 틀린 꼴: 쓰임 설명이나 다른 뜻이 첫 묶음(대표 낱말 하나에 「많이」, 영어 뜻이 넓은 번역표의 다른 낱말). 같은 한자의 다른 읽기를 가리지 못하는 경우는 읽기 칸을 따라 걸렀습니다.

### 31.3 테스트

| 파일 | 내용 |
|---|---|
| `tools/dict/test_build_wikt_glossary.py` (새, 20) | W1: 뜻풀이·번역어 규칙, 오쿠리가나 읽기·옛 표기 거부, 키 규칙, 한국어판이 영어판보다 앞, 중복 제거, 기초사전 키·짝 읽기 빼기, 판 정보, 같은 입력 같은 바이트, sha256 고정, 행 파일 머리말·잘린 파일 거부, 견본 SQL |
| `tools/dict/test_asset_check_wikt.py` (새, 11) | W2: release에서 없음·깨짐·판 어긋남·다른 기초사전이면 실패와 만드는 명령, 일반 실행은 없어도 통과, 나이 제한 없음, `--check` |
| `tools/dict/test_asset_check.py` | 결정에 따라 견본 asset을 만드는 함수가 보조 사전도 만듦(한 줄) |
| `packages/core/test/ports/fallback_glossary_test.dart` (새, 5) · `extract/meaning_fallback_test.dart` (새, 7) | W3: 주 사전에 뜻이 있으면 같은 결과·보조 사전을 묻지 않음, 비면 보조 사전 뜻(같은 인자), 둘 다 비면 없음. 추출기: 빈 뜻만 채움, 중간·「위키낱말사전」 표시, 사진 뜻·짝짓기는 그대로, 나머지 항목 값 같음 |
| `packages/krdict_block/test/wikt_glossary_test.dart` (새, 8) | W4: 메모리 SQLite(견본)로 판·출처, 묶음, 읽기, 오쿠리가나, 키 규칙, 영어판 행, 기초사전 낱말 없음 |
| `app/test/adapters/bundled_wikt_glossary_test.dart` (새, 6) · `features/about_wikt_test.dart` (새, 3) · `features/review_wikt_source_test.dart` (새, 2) | W5: 두 asset 풀기, 없거나 깨지면 기초사전만·로그 한 줄, 추출기에 연결, 정보 화면 카드·없을 때 문구, 라이선스 항목, 검토 화면의 추정 표시와 근거 출처 |
| `packages/jmdict_block/test/meaning_gap_local_test.dart` (새, 로컬, 3) | W6: 31.2절 하한 |
| 보완 | `packages/core/test/extract/meaning_fallback_prefix_test.dart` (2): `(お)X`에서 기초사전의 `おX`가 보조 사전의 `X`보다 앞. `app/test/features/about_wikt_damaged_test.dart` (2): 열지 못한 보조 사전과 없는 보조 사전의 문구. `tools/dict/test_build_wikt_glossary_extra.py` (5): 한자 괄호·일본어 조각·괄호 안 구분자, 잘린 행 파일, 임시 파일 없음 |
| `app/integration_test/wikt_screenshots_test.dart` (새) | 스크린샷 90~93 |

결과: core **612**(+14) · krdict_block **100**(+8) · jmdict_block **30**(+3, 로컬 포함) · app **275**(+13) · tools/dict **148**(+36) · research/meaning **20** 통과, analyze 문제 없음,
생성기 `--check` 3개 통과, `asset_check.py --release --engine ios` 모두 ok(이 체크아웃 asset).

### 31.4 스크린샷 (iPhone 17 시뮬레이터, dev, 실제 asset, 합성 샘플)

`cd app && flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/wikt_screenshots_test.dart`

| 파일 | 화면 |
|---|---|
| `90_about_wikt.png` | 정보: 위키낱말사전 카드(출처 두 줄, CC BY-SA 4.0, 한국어판·영어판 링크, 만든 날) |
| `91_license_wikt.png` | 라이선스 페이지의 위키낱말사전 항목 |
| `92_review_wikt_meaning.png` | 검토: DAY 20 예문 낱말 大阪 → 오사카(사전·중간·추정) |
| `93_evidence_wikt.png` | 근거 조각: 출처 사전 · 짝 신뢰도 중간 · 사전 뜻: 위키낱말사전 |

## 32. 발음 목소리 바꾸기: VOICEVOX Nemo 女声4, 1.0배 (2026-11-11)

예전 목소리(`0.vvm` 四国めたん ノーマル, 0.85배)가 캐릭터 성우처럼 들린다는 평이 있어, 캐릭터 없는 읽기용 음성 **VOICEVOX Nemo 女声4 ノーマル(`n0.vvm`, 스타일 10003)** 로 바꾸고 빠르기를 엔진 기본(1.0배)으로 했습니다.
후보 조사·견본은 `research/tts/voices/README.md`입니다. 엔진·FFI·악센트 지정(Kanjium)·예문 처리·캐시 구조는 그대로입니다.

### 32.1 바꾼 것

| 어디 | 무엇 |
|---|---|
| `tools/dict/speech_check.py` | 앱이 싣는 목소리를 한 곳에 고정(`VOICE_VARIANT` `voicevox-0.17.1-n0vvm-style10003`, `VOICE_MODEL_FILE`, `VOICE_STYLE_ID`, `VOICE_CREDIT`). 다른 목소리의 판이면 실패하고 다시 만드는 명령을 알림. 판에 없는 gzip이 폴더에 있어도 실패(앱이 `assets/voice/`를 통째로 싣기 때문) |
| `tools/voice/build_voice_asset.py` | `n0.vvm`(75,175,864바이트, sha256 고정), 스타일·판 이름은 위 상수, 크레딧 「VOICEVOX Nemo」. 다시 만들 때 판에 없는 gzip(예전 `0.vvm.gz`)을 지움 |
| `packages/voicevox_block` | `speechSpeedScale` 0.85 → 1.0 |
| `app/lib/adapters/voicevox_engine.dart` | 캐시 이름을 `speechVoiceId(edition)`으로 뺌(판·스타일·빠르기, 값은 그대로) |
| `app/lib/adapters/voice_assets.dart` | 판이 바뀌어 다시 풀 때 새 판에 없는 풀린 파일을 지움. 예전 판을 쓰던 기기에 `0.vvm`(59.3MB)이 남지 않게 |
| 정보 화면·라이선스 페이지 | 「음성 · VOICEVOX Nemo」, Nemo 규약 주소와 요점(크레딧 필요, 기계학습 이용 금지). 四国めたん 문구 없음 |

### 32.2 확인

| 확인 | 결과 |
|---|---|
| 예전 asset(main 체크아웃의 `0.vvm` 판)을 넣고 `asset_check.py --release` | 실패: `voice: edition variant is 'voicevox-0.17.1-0vvm-style2', this app ships 'voicevox-0.17.1-n0vvm-style10003'` 외 2줄 + 다시 만드는 명령 |
| `build_voice_asset.py --native` 뒤 `asset_check.py --release --engine ios` / `--engine android` | 모두 ok, 예전 `0.vvm.gz`는 지워짐 |
| 실제 엔진 통합 테스트(iPhone 17 Pro 시뮬레이터, `integration_test/speech_screenshots_test.dart`) | 2/2 통과, `unpacked voicevox-0.17.1-n0vvm-style10003 in 1363 ms`, 단어·예문·추정 단어 재생 |
| 악센트 재측정(`research/tts/voices/remeasure.py`, 앞 실험과 같은 28단어·7문장) | 아래 표 |

| 목소리 | 단어 엔진 값(가나 지정) | 최소쌍 대비 | 모라 판독 | 예문 악센트구: 기본 / 사용자 사전 |
|---|---|---|---|---|
| 예전 四国めたん (0.vvm, 2) | 28/28 | 8/8 | 11/28 | 16/19 / 17/19 |
| **Nemo 女声4 (n0.vvm, 10003)** | **28/28** | **8/8** | **16/28** | **16/19 / 17/19** |

- 예전 목소리 줄은 `research/tts/README.md`의 숫자(28/28, 16/19, 17/19)를 그대로 재현해 도구를 확인한 것입니다.
- 악센트구 나눔과 악센트 값은 Open JTalk가 정해 목소리와 상관없이 같습니다. 목소리마다 다른 것은 높낮이 모양(대비·모라 판독)입니다.

### 32.3 크기

| 무엇 | 예전 | 지금 |
|---|---|---|
| 음성 모델 gzip / 풀린 크기 | 59.3MB / 59.3MB | 75.2MB / 75.2MB |
| 발음 asset gzip 합계 | 82.8MB | 98.7MB (+15.9MB) |

- 모델은 이미 압축된 파일이라 iOS 앱(zip)·APK 모두 약 +15.9MB, 기기의 풀린 사본도 +15.9MB로 계산됩니다(예전 판을 쓰던 기기는 처음 재생할 때 예전 모델을 지우고 새로 풂). release 빌드로 다시 재지는 않았습니다.
- 새 asset 만들기: `python3 tools/voice/build_voice_asset.py --native` → `python3 tools/dict/asset_check.py --release --engine ios`(android도). 앞서 받은 공식 파일이 있으면 `--source-dir <폴더> --offline`.

### 32.4 테스트

| 파일 | 내용 |
|---|---|
| `tools/voice/test_build_voice_asset.py` | V1: `n0.vvm` 주소·크기·sha256, 판 정보의 스타일 10003·판 이름·크레딧, 다른 sha256이면 거부, 다시 만들 때 판에 없는 gzip 지움(새 1) |
| `tools/dict/test_asset_check.py` | V2: 앱이 싣는 목소리 상수, 예전 목소리 판(판 이름·모델·스타일 각각)이면 실패와 다시 만드는 명령, 판에 없는 gzip이면 실패(새 3) |
| `app/test/adapters/speech_voice_id_test.dart` (새, 3) · `packages/voicevox_block/test/speech_speed_test.dart` | V3: 빠르기 1.0, 캐시 이름에 판·스타일·빠르기, 하나만 달라도 다른 이름 |
| `app/test/features/about_voice_credits_test.dart` | V4: 「VOICEVOX Nemo」가 보이고 「四国めたん」이 없음 |
| `app/test/adapters/voice_assets_stale_test.dart` (새, 2) | 판이 바뀌면 옛 판에만 있던 풀린 파일(모델·사전 파일)이 지워지고 같은 판이면 그대로 |
| `app/integration_test/speech_screenshots_test.dart` | V5: 실제 엔진, 크레딧 확인을 Nemo로, 스크린샷 94 |

결과: tools/voice **48** · tools/dict **151** · voicevox_block **66** · app **280** · research/tts/voices **26** 통과, analyze 문제 없음.

| 스크린샷 | 내용 |
|---|---|
| `94_about_voice_nemo.png` | 정보 → 발음: 「음성 · VOICEVOX Nemo」(캐릭터 없는 읽기용 목소리), core·ONNX Runtime·Open JTalk 사전·Kanjium |

- `80`~`84`는 예전 목소리 때 찍은 그대로 둡니다(84의 크레딧은 예전 목소리).

## 33. 학습 방식 네 가지와 방식별 기억 기록, 예문 눌러 듣기 (저장 스키마 v5, 2026-11-12)

지금까지의 학습(일본어를 보고 뜻 떠올리기)에 방식 셋을 더했습니다. 같은 단어라도 방식마다 기억 단계·복습 날짜가 따로 갑니다. 복습 간격 규칙(architecture.md 4절 학습 규칙)은 그대로이고 방식마다 똑같이 적용합니다.

### 33.1 방식

| 방식 (`StudyMode`) | 앞면 | 답하기 |
|---|---|---|
| 뜻 맞히기 (`meaning`, 지금까지의 방식) | 지금 그대로 | 다시 학습 / 알고있음 |
| 일본어 떠올리기 (`recall`) | 품사·뜻, 예문 번역. 표제어·읽기·일본어 예문은 「일본어 보기」를 누르기 전에는 화면에 만들지 않음 | 다시 학습 / 알고있음 |
| 듣고 맞히기 (`listening`) | 카드가 나오면 단어 발음을 한 번 저절로 재생(이 방식만), 「다시 듣기」, 뜻 보기 4개. 표제어·읽기·예문은 고른 뒤에만 | 고른 순간 저장: 맞으면 알고있음, 틀리면 다시 학습과 같은 처리. 결과(정답 표시·표제어·읽기·예문 번역)는 「다음」까지 |
| 객관식 (`choice`) | 표제어·일본어 예문, 뜻 보기 4개(예문 번역은 고른 뒤에) | 듣고 맞히기와 같음 |

- **고르는 곳**: 홈 「오늘」 카드와 재생목록 화면의 칩 4개(같은 값). 한 세션은 한 방식이고 마지막에 고른 방식은 설정 표 `study.mode`에 남습니다(뜻 맞히기면 행 없음). 학습 화면 머리 글자는 「오늘 학습 · 객관식」처럼 방식 이름을 붙입니다(뜻 맞히기는 지금 그대로).
- **고를 수 없을 때**: 듣고 맞히기는 발음 블록이 없으면(`Speech.isAvailable` 거짓), 객관식·듣고 맞히기는 뜻이 비지 않고 서로 겹치지 않는 단어가 4개 미만이면 칩을 누를 때 이유만 알립니다(「발음을 들을 수 없어 고를 수 없어요」, 「뜻이 서로 다른 단어가 4개 이상 있어야 해요」). 저장된 방식을 지금 쓸 수 없으면 뜻 맞히기로 보이고 저장값은 남깁니다.
- **새 단어**: 방식마다 처음부터 모든 단어가 새 단어입니다(한 방식에서 학습해도 다른 방식에서는 새 단어). 일본어 떠올리기는 뜻이 빈 단어를, 객관식·듣고 맞히기는 보기 4개를 만들 수 없는 단어를 고르지 않습니다(숫자에서도 빠짐).
- **숫자**: 홈의 복습할 단어·새 단어·학습 시작 n장·더 학습하기와 「오늘 n개 외움」은 고른 방식 것이고, 「오늘 n개 외움」 아래에 방식 이름을 작게 붙입니다. 재생목록 단어 줄에는 방식마다 작은 기억 막대 4개(뜻·일·듣·객)가 있습니다.
- **처음부터 다시 학습·모든 단어 처음부터**: 모든 방식의 카드를 함께 지웁니다. 되돌리기는 방식마다 원래 카드로(그 사이 그 방식에서 다시 학습한 카드는 건너뜀). 확인 창과 알림의 수는 어느 방식이든 카드가 있는 단어 수입니다. 단어 ⋮ 메뉴는 어느 방식이든 카드가 있으면 보입니다.
- **예문 눌러 듣기**: 예문 글자를 눌러도 🔊 버튼과 같은 소리를 요청합니다(모든 방식, 예문이 보일 때만). 발음 블록이 없으면 눌러도 아무 일 없습니다.

### 33.2 보기 고르기 (`ChoiceMaker`, core `study/choice_maker.dart`)

- 오답 후보는 학습 범위와 상관없이 라이브러리의 모든 단어(숨긴 단어 포함)입니다.
- 뜻을 낱뜻으로 나눠 비교합니다: 괄호 속 설명 `(…)` `（…）` `[…]`을 빼고, `,` `;` `/` `·` `、` 등에서 나누고, 공백을 하나로. 낱뜻이 하나라도 같으면 겹치는 뜻입니다. 정답과 겹치는 단어, 서로 겹치는 단어, 뜻이 빈 단어는 보기에 함께 나오지 않습니다.
- 같은 품사를 먼저, 나머지를 뒤에 두고 각각 시드로 섞은 뒤 겹치지 않게 3개를 고릅니다. 섞은 순서로 3개를 못 고르면 단어 id 순서로 다시 고르고, 그래도 못 고르면 문제를 만들지 않습니다(그 단어는 그 방식에서 고르지 않음).
- 시드는 「세션 시작 시각(마이크로초)|단어 id|이 세션에서 다시 학습한 횟수」의 FNV-1a 32비트입니다. 같은 제시는 언제나 같은 보기, 다시 나온 카드는 다른 순서입니다.

### 33.3 저장 스키마 v5

- `review_cards`에 `mode`(기본 `meaning`), 기본 키 (scope, mode, word_id). `review_logs`에 `mode`(기본 `meaning`).
- v4 → v5: `review_cards`는 표를 다시 만들어(`alterTable`) 모든 행을 `meaning`으로 옮기고, `review_logs`는 열만 더합니다. 트랜잭션 하나라 중간에 실패하면 v4 파일이 그대로 남고 다음 연결이 다시 시도합니다. v1~v3 파일은 지금처럼 비운 뒤 v5로 시작합니다(21절).
- 포트 `ReviewRepository`의 읽기·쓰기에 `mode`(기본 `meaning`), `deleteAllCards`·`logs`는 `mode: null`이면 모든 방식.
- 덤프 `drift_schemas/shiori_database/drift_schema_v5.json`, 도우미 `test/migrations/generated/schema_v5.dart`, 단계 파일 `lib/src/database.steps.dart`(`make-migrations`). G2: `dart run build_runner build --delete-conflicting-outputs`·`schema generate` 뒤 생성물 차이 없음.

### 33.4 테스트

| 묶음 | 파일 | 내용 |
|---|---|---|
| 방식별 기록 | core `test/study/study_mode_records_test.dart` | 한 방식의 답이 다른 방식 카드를 바꾸지 않음, 4방식 모두 네 단계 규칙 그대로, 다시 학습 임시 카드·기록의 방식, 세션 scope가 기록을 정함, 앞당긴 카드, 되돌리기 |
| 세션·숫자 | core `test/study/study_mode_session_test.dart` | 방식마다 새 단어, 때가 된 카드 먼저, 숨김·뜻 빈 단어·보기 못 만드는 단어 제외, 보기 후보(라이브러리 전체), 현재 카드 문제와 시드, 방식별 요약·오늘 외운 수, 고를 수 있는 방식 |
| 초기화 | core `test/study/study_mode_reset_test.dart` | 단어 하나·전체 초기화가 모든 방식, 방식별 되돌리기 |
| 보기 | core `test/study/choice_maker_test.dart`, `choice_maker_fallback_test.dart` | 4개·정답 1개·중복·겹치는 뜻 없음, 같은 품사 먼저, 시드 재현, 오답 모자라면 문제 없음, 시드와 무관하게 만들 수 있는지(`canAskFor`) |
| 저장소 계약 | storage_drift `test/contract/study_mode_contract.dart`(메모리·drift), `test/study_mode_preferences_test.dart` | 단어 하나에 방식별 카드 공존, 방식별 읽기·지우기·기록, 기본값, 실패한 트랜잭션, 마지막 방식 저장·모르는 값 |
| 마이그레이션 | storage_drift `test/migrations/migration_test.dart`, `migration_version_test.dart` | v4 파일(단어·재생목록·숨김·카드·기록·설정) → v5에서 모든 행 그대로 + `mode` = meaning, 덤프 일치, 디스크 파일 재열기, 실패 주입 시 v4 그대로·다음 연결에서 변환. 새 버전 기록(`user_version`)은 표 변경과 같은 트랜잭션 안에서 씀(중간에 멈춰도 「v5 모양인데 v4」 파일이 남지 않음) |
| 화면 | app `study_mode_picker_test.dart`, `study_mode_cards_test.dart`, `study_mode_playlist_test.dart`, `study_mode_pick_write_test.dart` | 칩·숫자·기억·이유 알림, 방식별 카드, 고른 순간 저장과 「다음」(저장이 끝날 때까지 꺼짐, 저장 실패한 고르기는 다시 시작한 세션에 남지 않음), 자동 재생 1번·다시 듣기, 예문 눌러 듣기, 막대 4개, 모든 방식 초기화 |
| 재시작·업그레이드 | app `integration_test/persistence_test.dart` 단계 `modes`·`modes-reopen`, `upgrade-v5` | 객관식으로 답한 카드와 고른 방식이 재시작 뒤 그대로. v4 빌드의 `restudy` 단계로 만든 파일을 지우지 않고 이 빌드로 열면 카드·기록이 뜻 맞히기로 그대로, 다른 방식은 비어 있음 |

결과: core **713** · storage_drift **210** · app **306** 통과, `dart analyze`·`flutter analyze` 문제 없음. 시뮬레이터(iPhone 17, iOS 26.5): `modes` → 앱 종료 → `modes-reopen`, `restudy`(v4 빌드) → 앱 종료 → `upgrade-v5` 모두 통과.

### 33.5 스크린샷 (iPhone 17, 메모리 DB, 지어낸 단어, `study_modes_screenshots_test.dart`)

| 스크린샷 | 내용 |
|---|---|
| `95_home_mode_chips.png` | 홈: 방식 칩 4개(뜻 맞히기) |
| `96_home_listening.png` | 홈: 듣고 맞히기를 고른 숫자 |
| `97_recall_front.png` | 일본어 떠올리기 앞면: 품사·뜻·예문 번역, 「일본어 가림」 |
| `98_recall_shown.png` | 「일본어 보기」 뒤: 읽기·표제어·일본어 예문 |
| `99_listening_front.png` | 듣고 맞히기: 재생 버튼과 뜻 보기 4개 |
| `100_listening_answered.png` | 맞게 고른 뒤: 「맞았어요」, 정답 표시, 표제어·읽기·예문, 「다음」 |
| `101_choice_front.png` | 객관식 앞면: 표제어·예문·보기 4개 |
| `102_choice_wrong.png` | 틀리게 고른 뒤: 고른 보기 빨강, 정답 초록 「정답」, 「틀렸어요」 |
| `103_playlist_mode_meters.png` | 재생목록: 같은 칩, 단어마다 막대 4개(뜻·일·듣·객) |
| `104_listening_unavailable.png` | 발음 없는 상태에서 듣고 맞히기를 누른 알림 |

## 34. Tatoeba 예문: 사진에 예문이 없던 낱말의 카드 예문 (2026-11-12)

사진에 예문이 없던 낱말의 학습 카드에, 그 낱말의 JMdict 항목에 붙은 Tatoeba 문장 하나를 보여 주고 같은 예문 경로로 읽어 줍니다.
번역은 한국어 직접 번역이 있으면 한국어, 없으면 영어입니다. 규칙·판·라이선스는 `docs/dictionary.md` 14절, 원천 조사는 `research/examples/README.md`입니다. 교재 쪽은 숫자만 적습니다.
저장 스키마·추출기·사전 색인은 바꾸지 않았습니다(카드를 띄울 때 찾음).

### 34.1 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 예문 빌드 | `tools/dict/build_examples.py` (새) | Tatoeba 내보내기 7개 → 원형 색인으로 JMdict 항목에 잇기 → 거르기 → 항목·읽기마다 1문장(한국어 > `~` > 영어 > 쉬운 한자 > 길이). 입력 sha256 기록·`--expect-sha256`, `--sample-sql`·`--check` |
| 검사 | `tools/dict/asset_check.py` | `examples`: release에 필수(없음·깨짐·판 어긋남 → 실패와 만드는 명령), 일반 실행은 있으면 검사·없으면 한 줄, 나이 제한 없음 |
| core | `ports/example_sentences.dart` (새), `study/card_example.dart` (새) | 포트 `ExampleSentences`·`StoredExample`·`EmptyExampleSentences`, `CardExample`(사진/Tatoeba), `cardExampleOf`(사진 예문이면 조회 없음, 아니면 표제어 → 항목 → 예문, 카드 읽기 행 먼저), `kanaEntries` |
| 블록 | `packages/example_block` (새) | `TatoebaExamples`(스키마 1 검사, 항목 번호 묶음 조회, 판·라이선스) |
| 앱 | `bundled_examples.dart` (새), `blocks.dart`, `word_card.dart`, `word_speech.dart`, `study_screen.dart`, `about_parts.dart`·`examples_card.dart` (새), `about_screen.dart`, `main.dart` | asset 풀기·대조(없으면 로그 한 줄), `cardExampleProvider`, 카드의 예문 자리·번역(영어는 기울임)·「예문: Tatoeba」, 같은 `SentenceSpeech`, 정보 화면 「예문」 카드·라이선스 항목. 정보 화면의 공용 위젯(카드·링크·한 줄 사실)을 `about_parts.dart`로 옮김 |

### 34.2 결과

| 측정 | 값 |
|---|---|
| 예문 asset (2026-11-07 내보내기, JMdict 2026-11-06) | 28,060행 · 27,067항목, 한국어 1,231 · 영어 26,648 · 번역 없음 181 |
| asset 크기 | gzip 1,671,255 B (SQLite 3,383,296 B) |
| 로컬 교재 세트 10개에서 예문 없이 나온 낱말 | 82개 중 **73개 채움** (한국어 24 · 영어 49 · 없음 0) — 조사 때 73/82와 같음 |
| 같은 세트의 사진 예문 | 413항목 모두 사진 예문 그대로(일본어·번역 바이트 같음) |

- 사진 예문이 있는 낱말은 예문 asset을 묻지 않습니다(core 테스트가 호출 수로 확인).
- 추출기·검토 초안 값은 바뀌지 않습니다(추출 코드를 건드리지 않음).
- 채운 예문은 「뜻 맞히기」 카드에만 보입니다. 33절의 「일본어 떠올리기」·「객관식」·「듣고 맞히기」 카드는 지금처럼 사진 예문만 보여 줍니다.

### 34.3 테스트

| 파일 | 내용 |
|---|---|
| `tools/dict/test_build_examples.py` (새, 17) | X1: 지어낸 Tatoeba 문장·연결·색인 + JMdict 견본 → 항목마다 1문장, 원형 색인으로 활용형(汚して → 汚す), 읽기 행(七 しち/なな, 空 から), 민감 낱말·짧은 문장·태그 거르기, 한국어 > 영어 > 없음, 문장 번호, 판 정보, 같은 입력 같은 바이트, bz2·tar 내보내기도 같은 결과, sha256이 다르면·파일이 없으면·날짜가 틀리면 멈춤, `--sample-sql` 견본 = 고정 파일, `--check` |
| `tools/dict/test_asset_check_examples.py` (새, 8) | X2: 맞으면 통과, release에서 없음·깨짐·판 어긋남·판 정보 칸 빠짐이면 실패와 만드는 명령, 일반 실행은 없어도 통과하고 한 줄, 나이 제한 없음 |
| `packages/core/test/study/card_example_test.dart` (새, 12) | X3: 사진 예문이 먼저(조회 없음), 번역 없는 사진 예문, 항목 문장(한자 표기는 읽기로 좁힘), 영어, 활용형, 카드 읽기 행 먼저·다른 읽기만이면 없음, 가타카나 읽기, 가나 낱말의 항목 고르기, 사전에 없는 낱말·문장 없는 항목은 없음 |
| `packages/example_block/test/tatoeba_examples_test.dart` (새, 11) | X4: 메모리 SQLite로 판·라이선스, 항목·읽기 행, 번역 칸, 문장 번호, 묻는 순서, 빈 조회, 2,500개 묶음, 다른 스키마·표 없음 거부, 파일 열기 |
| `app/test/adapters/bundled_examples_test.dart` (새, 5) · `features/word_card_filled_example_test.dart` (새, 6) · `features/word_speech_filled_test.dart` (새, 3) · `features/about_examples_test.dart` (새, 4) · `features/study_filled_example_test.dart` (새, 1) | X5: asset 풀기·없음·깨짐(로그 한 줄), 카드의 한국어·기울인 영어·번역 없음·사진 예문 우선·버튼, 소리 요청이 사진 예문과 같은 `SentenceSpeech`, 정보 카드·없음·깨짐·라이선스 항목, 학습 화면에서 채운 예문 표시와 재생 |
| `packages/jmdict_block/test/example_fill_local_test.dart` (새, 로컬, 1) | X6: 34.2절 채움 하한(65)과 사진 예문 바이트 비교 |
| `app/test/features/word_card_filled_tap_test.dart` (새, 1) | 33절의 예문 눌러 듣기가 채운 예문에도 동작 |
| 고친 것 | `tools/dict/test_asset_check.py`: 견본 asset을 만드는 함수가 예문 asset도 만듦(한 줄). `app/test/support/harness.dart`: 예문 없음을 기본으로 끼움. `app/test/app/no_network_test.dart`: 검사 목록에 `packages/example_block` |

결과(33절 병합 뒤): core **725**(+12) · storage_drift **210** · example_block **11**(새) · krdict_block **100** · dict_jmdict **11** · voicevox_block **66** · jmdict_block **31**(+1, 로컬 포함) · app **326**(+20) · tools/dict **177**(+26) · research/examples **25** 통과, analyze 문제 없음,
생성기 `--check` 3개 통과, `asset_check.py --release --engine ios` 모두 ok(이 체크아웃 asset).

### 34.4 스크린샷 (iPhone 17 시뮬레이터, dev, 실제 asset, 테스트가 넣은 낱말 2개)

`cd app && flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/examples_screenshots_test.dart`

| 파일 | 화면 |
|---|---|
| `105_study_tatoeba_example.png` | 사진 예문이 없는 낱말 傘: Tatoeba 문장과 「예문: Tatoeba」, 번역 가림 |
| `106_study_tatoeba_korean.png` | 뜻을 연 뒤: 한국어 직접 번역 (예문 재생 뒤, 실제 엔진) |
| `107_study_tatoeba_english.png` | 毎朝: 한국어가 없어 기울인 영어, 「예문: Tatoeba · 영어 번역」 |
| `108_about_examples.png` | 정보 → 예문: Tatoeba 카드(출처 줄, CC BY 2.0 FR, tatoeba.org, 내보낸 날·만든 날) |
| `109_license_examples.png` | 라이선스 페이지의 Tatoeba 항목 |

## 35. 괄호 밖 꼬리·앞 お/ご, 붙은 체크박스, 최저 신뢰도 괄호 줄, 비침 부호, 실패 화면의 판독 기록 내보내기 (2026-11-12)

실사용 단어장 쪽 하나(15줄, `□ 漢字(かな)　뜻`, 빨간 악센트 선, 뒷면 비침)에서 맨 아래 줄이 빠지고, 그 두 줄만 잘라 찍은 사진은 단어가 0개였습니다.
원인은 판독이 아니라 추출 규칙이었습니다: 괄호 뒤 어미(`…(かな)だ`)·앞 `お`를 읽기 분리가 받지 않아 문장 경로로 가고, 빨간 선 줄을 Vision이 최저값(0.3)으로 읽어
문장 경로·찌꺼기 판정에서 버려졌습니다. 줄이 둘뿐인 사진은 체크박스 열이 서지 않아 붙은 `ロ`가 남았고, 뜻 줄 뒤의 비침 `!`가 그 줄을 문장으로 만들었습니다.
규칙은 `docs/extraction.md` 2절(사전이 확인한 괄호 줄, 붙은 口·ロ, 괄호 밖 꼬리·앞 お/ご, 띄어 쓴 외톨이 부호)과 11절(한계)입니다. 교재 쪽은 숫자만 적습니다.
신뢰도 규칙(`confidence.dart`)·저장 스키마·사전 asset은 바꾸지 않았습니다.

### 35.1 측정 (규칙을 정하기 전, 실제 JMdict·한국어 뜻 사전·위키낱말사전 보조 사전 = 앱 구성)

- 로컬 판독 242쪽의 일본어 패스 줄 중 `漢字(かな)` 꼴 46줄, 그중 괄호 뒤 꼬리 2줄·앞 お/ご 2줄. 붙은 口·ロ로 시작하는 줄 1,074개(대부분 체크박스 열 위).
  한국어 패스에서 「공백 + 외톨이 부호」로 끝나는 줄 51개: 배지 + 마침표 25, 숫자 줄 23, 인쇄된 번역 문장(`…입니다 .`) 2, 비침 `!` 1.
- 최저 신뢰도 괄호 줄의 후보 세 가지:

| 안 | 합성 범용 g01~g11 (높음 · 뜻) | 보관함 | 판단 |
|---|---|---|---|
| 사전이 확인하면 일본어가 이김(같은 자리 한국어 구간 버림) | 44 → **39** · 68 → **66** (g05 섞인 줄의 진짜 뜻이 지워짐) | — | 넣지 않음 |
| 사전이 확인하면 둘 다 남김(언제나) | 그대로 | 한국어 찌꺼기 조각이 새로 보임 | 넣지 않음 |
| **질 자리에서만 둘 다 남김** | 그대로 | 그대로 | 채택 |

- 띄어 쓴 부호는 `!`·`?`·`！`·`？`만 비침으로 봅니다. 마침표까지 넣으면 인쇄된 번역 2줄이 짧은 뜻이 됩니다.
- 문장 경로의 0.3 차단은 바꾸지 않았습니다. 사전이 확인한 괄호 줄은 단어 목록 낱말이 되어 문장 경로에 가지 않습니다.

### 35.2 바꾼 것

| 항목 | 위치 | 내용 |
|---|---|---|
| 괄호 밖 꼬리·앞 お/ご | `packages/core/lib/src/extract/paren_reading.dart` (새), `fragment_collector.dart`, `general_extractor.dart` | 사전이 「접두 + 한자부 + 꼬리」를 「(접두) + 괄호 + 꼬리」로 읽을 때만 표제어·읽기로 나눔, する는 する 명사. 추출기가 물을 표기(`fragmentProbes`)를 먼저 조회한 뒤 조각 수집에 사전 판정(`FragmentDictionary`)을 넘김 |
| 붙은 체크박스 | `fragment_collector.dart`, `paren_reading.dart` (`isGluedBox`) | 체크박스 열이 없어도 붙은 口·ロ 뒤가 한자·히라가나이고 뗀 쪽만 사전 낱말이면 뗌 |
| 최저 신뢰도 괄호 줄 | `fragment_collector.dart` (`confirmsBracketedReading`) | 사전이 확인한 괄호 줄은 질 자리에서 버리지 않고 둘 다 남김 |
| 비침 부호 | `fragment_collector.dart` | 한국어 줄 끝 「공백 + `!?！？` 하나」를 지움(보정 표시) |
| 실패 화면 내보내기 | `app/lib/features/capture/capture_controller.dart`·`capture_screen.dart`·`ocr_export.dart` | 판독은 됐는데 단어가 0개이거나 추출기가 예외로 멈춘 실패 상자 안, 메시지 아래에 「판독 기록 내보내기」(검토 화면과 같은 2파일 `<이름>.ja.json`·`<이름>.ko.json`, 사진 제외, release가 아닌 빌드에서만). 판독 자체가 실패하면 없음. 공유·실패 스낵바는 검토 화면 버튼과 같은 함수 |
| 합성 쪽 | `tools/synthetic/make_general_pages.py`, `synthetic_general/g40`·`g41`, `ground_truth_paren.json` | g40 꼬리·접두 단어 상자(최저 신뢰도 줄 하나, 괄호가 든 문장), g41 두 줄을 잘라 찍은 쪽(붙은 ロ, 최저 신뢰도 줄, 비침 `!`). 메모리 사전 +2항목, 뜻 흉내 +1. 기존 쪽 파일은 그대로 |

### 35.3 결과 (표제어 기준, 앱 구성의 실제 사전)

| 세트 | 높음 (하한) | 찾음 · 읽기 · 뜻 · 여분 (전 → 후) |
|---|---|---|
| 실사용 두 쪽 (로컬, 새: 쪽 전체 15단어 + 두 줄 2단어) | 10 → **13** (13) | 13/17 · 13 · 13/13 · 0 → **17/17 · 17 · 17/17 · 0** |
| 교재 단어장 5쪽 Vision / ML Kit 조각 (로컬) | 38 / 38 (36 / 37) | 그대로 |
| 휜 쪽 실기기, 스캔 쌍 휜 쪽·예문 쪽 (로컬) | 8 · 9 / 10 · 7 / 8 | 그대로 |
| 다른 교재 3쪽 · 스캔 쌍 원본 · 스캐너 앱, 실사용 쪽 (로컬) | 8 · 8 · 8, 8 | 그대로 (값은 아래 35.4) |
| 합성 단어장 / ML Kit형 / 범용 / Android / 함정 | 24 / 13 / 44 / 20 / 2 | 그대로 |
| 합성 괄호 꼬리 g40·g41 (새, 실제 사전) | 1 → **9** (9) | 6/10 · 6 · 4/6 · 2 → **10/10 · 10 · 10/10 · 0** |
| 같은 쪽, 메모리 사전 (`tool/eval_extract.dart --gt ground_truth_paren.json`) | 1 → **9** | 3/10 → **10/10** · 읽기 10 · 뜻 10/10 · 여분 1 → **0** |

- **전 세트 높음인데 틀림 0, 여분인데 높음 0.** 모든 줄을 0.3으로 낮춘 시험(22절, 두 패스·일본어만·한국어만)도 0이고, 찾음은 오히려 늘었습니다(다른 교재 스캐너 앱 13 → 14, 합성 범용 일본어만 0.3 61 → 67).
- 실사용 두 줄 사진을 폰처럼 두 일본어 줄 모두 0.3으로 낮춘 변형도 2/2(둘 다 읽기·뜻 높음).
- 메모리 사전 합성 범용 세트 점수 그대로(쪽당 시간 8.9 → 9.5 ms, 데스크톱).

### 35.4 전 로컬 판독 244쪽에서 바뀐 값

로컬 판독은 실사용 두 쪽을 더해 244쪽입니다. 규칙 전 검토 초안 값(모든 칸·근거 설명·짝 없는 조각)을 기록해 두고 비교했습니다. 바뀐 것은 아래뿐입니다.

| 쪽 | 바뀐 것 |
|---|---|
| 실사용 쪽 전체 | 빠지던 맨 아래 단어가 나옴(읽기·뜻 높음), 보관함의 그 뜻 조각 없어짐. 앞 お 단어가 문장 경로(사전 뜻) → 단어 목록(사진 뜻, 정답과 같음) |
| 실사용 두 줄 | 단어 0(폰)·1(Mac, 문장 경로) → 2(단어 목록, 읽기·뜻 높음) |
| 다른 교재 한 쪽의 세 판(기록·스캔 쌍 원본·스캐너 앱) | 한국어 설명 단락 속 접두 낱말 2개(정답의 무시 낱말 1, 정답 단어 1 — 스캐너 앱판만)가 문장 경로(사전 뜻, 중간) → 단어 목록(읽기 높음, 뜻은 옆 설명 줄 찌꺼기 **낮음**, 「확인 필요」). 점수(찾음·뜻)·높음 그대로(정답 단어의 뜻은 전에도 틀림). 스캐너 앱판 문장 낱말 예측 30/31 → 29/30. 승인한 부작용(`docs/extraction.md` 11절) |

### 35.5 테스트

| 파일 | 내용 |
|---|---|
| `packages/core/test/extract/paren_tail_test.dart` (새, 16) | P1 꼬리(な형 だ·送り仮名·する 명사)·앞 お(괄호가 접두를 감싼 꼴 포함) 나눔, 사전 읽기가 다르거나 사전형이 아니면·문장 속이면·사전이 없으면 안 나눔. P2 두 줄 쪽의 붙은 ロ 떼기, 口로 시작하는 낱말·ロ 뒤 가타카나는 그대로. P3 0.3 괄호 줄(기기 채널 값 포함)이 같은 자리 한글 찌꺼기에 지지 않음, 사전이 확인 못 한 줄·0.3 한자는 그대로 버림, 섞인 줄의 뜻 유지. P4 띄어 쓴 `!`·`？`는 뜻, 붙은 `!`·띄어 쓴 `.`는 문장 |
| `packages/core/test/extract/paren_pages_test.dart` (새, 3) | P6 g40·g41 메모리 사전: 찾음·읽기·뜻 전부, 여분 0, 틀림 0·여분 높음 0, 높음 하한(7·2), 괄호가 든 문장의 낱말 |
| `packages/jmdict_block/test/paren_tail_local_test.dart` (새, 로컬, 6) | P5 19세트 값·높음 하한·틀림 0·여분 높음 0(실사용 두 쪽은 로컬 기대값 파일), 244쪽 검토 초안 값 = 규칙 전 기록(승인 항목 제외, 로컬 파일), ML Kit 낱말 단위 세트 하한, 모든 줄 0.3 세 변형 |
| `app/test/features/failure_export_test.dart` (새, 5) | V11 단어 0개 실패·추출기 예외 실패에 내보내기 버튼, 파일 2개를 다시 읽으면 같은 줄, 판독 실패면 없음, release면 없음, 공유 실패 스낵바 |
| 고친 것 | `packages/jmdict_block/test/meaning_quality_local_test.dart` M6: 사전으로 채운 뜻 중 정답 있는 것 15 → 14개(35.4의 정답 단어가 사진 뜻으로 바뀜, 맞음 12 그대로, 승인). 앞 작업 로컬 테스트들의 승인 항목 목록(로컬 파일)에 35.4의 다른 교재 항목을 더함 |

결과: core **744**(+19) · jmdict_block **37**(+6, 로컬 포함) · app **331**(+5) 통과, analyze 문제 없음, 생성기 `--check` 3개 통과.

### 35.6 스크린샷 (iPhone 17 시뮬레이터, dev, 실제 asset, 합성 쪽만)

`cd app && flutter drive -d <iPhone 17> --flavor dev --driver=test_driver/integration_test.dart --target=integration_test/paren_tail_screenshots_test.dart`

| 파일 | 화면 |
|---|---|
| `110_capture_no_words_export.png` | 일본어가 없는 사진: 「이 사진에서 단어를 찾지 못했어요…」 아래 「판독 기록 내보내기」 |
| `111_capture_extractor_error_export.png` | 추출기가 멈춘 실패: 「단어를 정리하다가 문제가 생겼어요…」 아래 같은 버튼 |
| `112_review_two_rows.png` | g41 두 줄 쪽: 親切だ·有名だ 2단어, 읽기·뜻 모두 높음 |
| `113_evidence_lowest_reading.png` | 0.3으로 읽힌 줄의 읽기 근거 조각: 「출처: 사진 · 짝 신뢰도 높음」 |
| `114_review_endings_honorifics.png` | g40 단어 상자: 練習(する 꼬리)·お茶·ご飯·走る |
