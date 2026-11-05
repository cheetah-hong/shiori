# 검증 기록 (앱 뼈대)

- 날짜: 2026-11-05 (KST), MacBook arm64 · macOS 26.3.1
- 도구: Flutter 3.41.5 · Dart 3.11.3, Xcode 26.6, CocoaPods 1.16.2, Android SDK 36.1 (JBR 21)
- 시뮬레이터: iPhone 17 Pro, iOS 26.5. 실제 iPhone은 쓰지 않았습니다.

## 0. 테스트 데이터

- **합성 세트 (저장소):** `packages/core/test/fixtures/synthetic/`, 앱 샘플은 같은 파일의 사본 `app/assets/dev_samples/`.
  지어낸 단어 35개를 교재와 같은 배치로 놓은 4쪽(목록형 `s010`·`s011`, 항목형 `s140`·`s147`)의 두 번 판독 기록, 정답, 기준 구현 출력입니다.
  해석·보정 규칙이 다루는 OCR 실수를 일부러 넣었습니다(체크박스 잡음, ★ 기호 잡음, 기울기, 옆 페이지 번호, 읽기 없음 `-`·`–`·`一`,
  한자 사이 가타카나, 품사 배지 오인식, 후리가나, 관련어·문형 상자, DAY 오인식 등). 만드는 법: `python3 tools/synthetic/make_pages.py`
  (`--check`는 저장소의 파일이 생성기 출력과 같은지 확인).
- **교재 세트 (로컬 전용):** 측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했습니다.
  `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/`(기본 `<저장소>/.private`)에 있을 때만 해당 테스트가 돌고, 없으면 이유를 적고 건너뜁니다.

## 1. 완료 조건

| 항목 | 명령 | 결과 |
|---|---|---|
| core 정적 분석 | `cd packages/core && dart analyze` | 문제 없음 |
| core 테스트 | `cd packages/core && dart test` | **302개 통과**, 교재 세트 10개 건너뜀 (10절 ★ 걷어냄 반영 뒤) |
| core 테스트 (교재 세트 포함) | `SHIORI_PRIVATE_DIR=<로컬 폴더> dart test` | **314개 통과** |
| core 커버리지 | `dart run coverage:test_with_coverage -o coverage` | 줄 커버리지 **97.7%** (1805/1847줄, 교재 세트 없이. `InMemoryLibraryRepository.textbookStats`는 저장 패키지의 계약 테스트가 돌려서 core 숫자에는 안 잡힘) |
| 사전 패키지 | `cd packages/dict_jmdict && dart analyze && dart test` | 문제 없음, **63개 통과** (테스트 DB 103개 항목) |
| 사전 블록 (어댑터) | `cd packages/jmdict_block && dart analyze && dart test` | 문제 없음, **19개 통과** (8절) |
| 사전 asset 스크립트 | `python3 -m unittest discover -s tools/dict -p 'test_*.py'` | **6개 통과** (네트워크 없음) |
| 저장 패키지 | `cd packages/storage_drift && dart analyze && dart test` | 문제 없음, **74개 통과** (7절, 9절, 스키마 v2 마이그레이션 10절) |
| app 정적 분석 | `cd app && flutter analyze` | 문제 없음 |
| app 테스트 | `cd app && flutter test` (기본 flavor = dev), `flutter test --flavor dev` | **101개 통과** (11절 반영 뒤. 그 전 79개, 사전 asset 있음·없음 둘 다) |
| iOS 채널 순수 로직 | `cd app/ios && xcodebuild test -workspace Runner.xcworkspace -scheme dev -destination 'id=<시뮬레이터>' -only-testing:RunnerTests` (11절부터 스킴 `dev`) | **5개 통과** (회전 투표·가로세로 바꿈·방향 합성, 6.4절) |
| Android 채널 순수 로직 | `cd app/android && ./gradlew :app:testDevDebugUnitTest` (JDK 21, 11절부터 flavor 이름이 붙음) | **11개 통과** (조각 자르기·회전·상자 없는 글자, 6.5절) |
| app 커버리지 | `flutter test --coverage` | 줄 커버리지 **92.2%** (1902/2064줄, 11절 반영 뒤. 10절 뒤 91.6%) |
| iOS 흐름 | `flutter drive ... integration_test/flow_screenshots_test.dart` | 통과, 스크린샷 15장 (3절, 시뮬레이터 디버그 빌드) |
| Android 빌드 | `flutter build apk --debug` (= dev flavor, `app-dev-debug.apk`) | 성공 (Kotlin ML Kit 채널 컴파일, 디버그 APK 약 186MB = 177MiB, 빌드 환경에 따라 조금 다름) |
| 합성 세트 점수표 | `cd packages/core && dart run tool/eval_capture.dart` | 31/35, 기준 구현과 다른 칸 0개 (2.1절) |
| 합성 세트 점수표 (ML Kit형) | `dart run tool/eval_capture.dart --fixtures test/fixtures/synthetic_mlkit` | 16/18 (6.3절) |
| 교재 세트 점수표 | `dart run tool/eval_capture.dart --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3"` | 55/59, 기준 구현과 다른 칸 0개 (2.2절) |
| 합성 생성기 | `python3 tools/synthetic/make_pages.py --check` | 저장소 파일과 같음 |
| 배포 빌드 (prod) | `flutter build apk --flavor prod --release`, `flutter build appbundle --flavor prod --release`, `flutter build ios --flavor prod --release --no-codesign` | 사전 asset과 서명 키(Android)가 있으면 **성공**, 결과물에 `dev_samples` 없음. 사전 asset이나 `key.properties`가 없으면 **분명한 메시지로 실패** (11절) |
| 배포 빌드 차단 (dev) | `flutter build apk --flavor dev --release`, `flutter build ios --flavor dev --release --no-codesign` (`--flavor` 없는 release도 dev) | **의도대로 실패**: dev flavor는 개발 샘플을 묶으므로 release로 빌드하지 않음 (11절) |
| 연구 도구 테스트 | `python3 -m unittest test_tools` (`research/scan/tools`, `research/ocr-android/tools`) | 27개, 16개 통과 |
| ML Kit 판독 앱 | `cd research/ocr-android/mlkit_probe && ./gradlew :app:testDebugUnitTest` | 5개 통과 |

## 2. 캡처 회귀 점수표

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

- 지금 `schemaVersion = 2` (10절). 덤프: `packages/storage_drift/drift_schemas/shiori_database/drift_schema_v1.json`, `drift_schema_v2.json`,
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
