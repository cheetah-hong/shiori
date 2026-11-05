# 검증 기록 (앱 뼈대)

- 날짜: 2026-11-05 (KST), MacBook arm64 · macOS 26.3.1
- 도구: Flutter 3.41.5 · Dart 3.11.3, Xcode 26.6, CocoaPods 1.16.2, Android SDK 36.1 (JBR 21)
- 시뮬레이터: iPhone 17 Pro, iOS 26.5. 실제 iPhone은 쓰지 않았습니다.

## 0. 테스트 데이터

- **합성 세트 (저장소):** `packages/core/test/fixtures/synthetic/`, 앱 샘플은 같은 파일의 사본 `app/assets/dev_samples/`.
  지어낸 단어 35개를 교재와 같은 배치로 놓은 4쪽(목록형 `s010`·`s011`, 항목형 `s140`·`s147`)의 두 번 판독 기록, 정답, 기준 구현 출력입니다.
  해석·보정 규칙이 다루는 OCR 실수를 일부러 넣었습니다(체크박스 잡음, ★, 기울기, 옆 페이지 번호, 읽기 없음 `-`·`–`·`一`,
  한자 사이 가타카나, 품사 배지 오인식, 후리가나, 관련어·문형 상자, DAY 오인식 등). 만드는 법: `python3 tools/synthetic/make_pages.py`
  (`--check`는 저장소의 파일이 생성기 출력과 같은지 확인).
- **교재 세트 (로컬 전용):** 측정은 저장소에 포함하지 않은 교재 5쪽(59단어) 비공개 세트로 했습니다.
  `$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3/`(기본 `<저장소>/.private`)에 있을 때만 해당 테스트가 돌고, 없으면 이유를 적고 건너뜁니다.

## 1. 완료 조건

| 항목 | 명령 | 결과 |
|---|---|---|
| core 정적 분석 | `cd packages/core && dart analyze` | 문제 없음 |
| core 테스트 | `cd packages/core && dart test` | **166개 통과**, 교재 세트 8개 건너뜀 |
| core 테스트 (교재 세트 포함) | `SHIORI_PRIVATE_DIR=<로컬 폴더> dart test` | **183개 통과** |
| core 커버리지 | `dart run coverage:test_with_coverage -o coverage` | 줄 커버리지 **97.1%** (교재 세트 없이) |
| 사전 패키지 | `cd packages/dict_jmdict && dart analyze && dart test` | 문제 없음, **63개 통과** |
| app 정적 분석 | `cd app && flutter analyze` | 문제 없음 |
| app 테스트 | `cd app && flutter test` | **36개 통과** |
| app 커버리지 | `flutter test --coverage` | 줄 커버리지 **89.9%** |
| iOS 흐름 | `flutter drive ... integration_test/flow_screenshots_test.dart` | 통과, 스크린샷 15장 (3절, 시뮬레이터 디버그 빌드) |
| Android 빌드 | `flutter build apk --debug` | 성공 (Kotlin ML Kit 채널 컴파일, 디버그 APK 약 186MB = 177MiB, 빌드 환경에 따라 조금 다름) |
| 합성 세트 점수표 | `cd packages/core && dart run tool/eval_capture.dart` | 기준 구현과 같음 (2.1절) |
| 교재 세트 점수표 | `dart run tool/eval_capture.dart --fixtures "$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3"` | 기준 구현과 같음 (2.2절) |
| 배포 빌드 차단 | `flutter build apk --release`, `flutter build ios --release --no-codesign` | **의도대로 실패**: 개발용 `assets/dev_samples/`가 pubspec에 있는 동안 막힘 |
| 연구 도구 테스트 | `python3 -m unittest test_tools` (`research/scan/tools`, `research/ocr-android/tools`) | 27개, 16개 통과 |
| ML Kit 판독 앱 | `cd research/ocr-android/mlkit_probe && ./gradlew :app:testDebugUnitTest` | 5개 통과 |

## 2. 캡처 회귀 점수표

`dart run tool/eval_capture.dart`의 출력은 `python3 tools/reference/parse_eval.py --data <같은 폴더>`와 **한 칸도 다르지 않습니다.**

### 2.1 합성 세트 (4쪽 35단어)

```
page tpl    n found head read  pos mean star  row exJA exKO meta
  10 list  12    12   10   12   12   11   12    9    -    - ok
  11 list  12    12   12   12   12   11   11   10    -    - ok
 140 entry  6     6    6    6    6    6    6    6    6    6 ok
 147 entry  5     5    5    5    5    5    5    5    4    4 ok

TOTAL  headword=33/35  readings=35/35  pos=35/35  meaning=33/35  important=34/35  ex_ja=10/11  ex_ko=10/11  row=30/35  found=35/35
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 4
```

틀린 칸은 모두 일부러 넣은 것입니다: 읽지 못한 표제어 2개(`日`, `空`, "표제어 없음"으로 표시), 잘못 읽은 뜻 1개(`구름`→`구룸`, 조용한 오류),
읽지 못한 뜻 1개("뜻 없음"으로 표시), 읽지 못한 ★ 1개, 읽지 못한 예문 1개. 자동 보정 4개(`ロ`→`口`, `タ日`→`夕日`, `光ル`→`光る`, `カ`→`力`)는 정답과 같아졌습니다.

- 회귀 테스트: `packages/core/test/capture/regression_test.dart` (합성 세트는 위 값을 정확히 단언)
- 경우별 테스트: `packages/core/test/capture/synthetic_pages_test.dart` (넣어 둔 OCR 실수마다 하나씩)

### 2.2 교재 세트 (로컬 전용, 5쪽 59단어)

```
page tpl    n found head read  pos mean star  row exJA exKO meta
  12 list  15    15   13   15   15   14   15   12    -    - ok
  13 list  16    16   16   16   16   16   15   15    -    - ok
  69 list  16    16   16   16   16   15   16   15    -    - ok
 157 entry  6     6    6    6    6    6    5    5    6    6 ok
 185 entry  6     6    6    6    6    6    5    5    6    6 ok

TOTAL  headword=57/59  readings=59/59  pos=59/59  meaning=57/59  important=56/59  ex_ja=12/12  ex_ko=12/12  row=52/59  found=59/59
core fields wrong but NOT flagged (silent errors): 1
core fields wrong and flagged for review: 3;  flagged but actually correct: 3
```

| 목표 | 결과 |
|---|---|
| 찾음 59/59 | 59/59 |
| 줄 전체 ≥ 52/59 | 52/59 |
| 예문 일·한 12/12 | 12/12 · 12/12 |
| 표시 없이 틀린 핵심 칸 ≤ 1 | 1 (한국어 OCR이 뜻 한 글자를 잘못 읽음) |

- 회귀 테스트와 기준 출력 대조는 같은 두 파일의 "recorded textbook pages (local only)" 그룹입니다.
- 기준 출력 대조: `packages/core/test/capture/reference_parity_test.dart`는 Python 기준 구현의 출력
  (`tools/reference/dump_reference.py --data <폴더>` → `reference_output.json`)과 **모든 항목의 모든 칸과 표시 코드**를 하나씩 비교합니다.
  합성 세트(35개)는 항상, 교재 세트(59개)는 로컬 자료가 있을 때 비교합니다.
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
사진과 정답은 저장소 밖 로컬 전용 폴더에 둡니다. EXIF 회전값이 있는 3장(69·157·185쪽)은 원본 그대로 넘겨 채널의 EXIF 처리를 확인했고,
EXIF 없이 옆으로 찍힌 2장(12·13쪽)은 연구 때처럼 미리 돌렸습니다(`research/OCR_TEST.md` 4절).

```
cd app && flutter test integration_test/vision_channel_probe_test.dart -d <시뮬레이터> \
  --dart-define=SHIORI_PROBE_PHOTOS=<쪽 이름.jpg 사진 폴더> --dart-define=SHIORI_PROBE_TRUTH=<ground_truth.json>
# 틀린 단어 목록(교재 본문이 찍힘)이 필요하면 --dart-define=SHIORI_PROBE_VERBOSE=true
```

OCR 블록이 돌려준 JSON을 엄격하게 파싱하도록 바꾼 뒤에도 같은 결과로 통과했습니다.

```
engine=apple-vision
p012: ja 119 lines 1789 ms, ko 78 lines 1387 ms
p013: ja 86 lines 1318 ms, ko 69 lines 1212 ms
p069: ja 90 lines 1400 ms, ko 78 lines 1314 ms
p157: ja 67 lines 1648 ms, ko 65 lines 1567 ms
p185: ja 61 lines 1583 ms, ko 47 lines 1673 ms
page tpl    n found head read  pos mean star  row exJA exKO meta
  12 list  15    15   13   15   15   14   15   12    -    - ok
  13 list  16    16   14   16   16   16   15   13    -    - ok
  69 list  16    16   16   16   16   16   15   15    -    - ok
 157 entry  6     6    6    6    6    6    6    6    6    6 ok
 185 entry  6     6    6    6    4    5    4    3    5    6 ok

TOTAL  headword=55/59  readings=59/59  pos=57/59  meaning=57/59  important=55/59  ex_ja=11/12  ex_ko=12/12  row=49/59  found=59/59
core fields wrong but NOT flagged (silent errors): 2
```

- 채널은 동작합니다: 59단어를 모두 찾았고 DAY·제목·쪽 5/5, 한 장 두 번 판독 합계 약 2.6~3.4초(시뮬레이터, Mac CPU).
- Mac에서 녹화한 판독(52/59)과 결과가 조금 다릅니다. 같은 Vision API라도 iOS 26.5 시뮬레이터와 macOS 26.3의 판독 결과가 다릅니다
  (예: 13쪽에서 표제어 앞에 잡음 글자가 붙음, 185쪽에서 품사 배지가 뜻 뒤에 붙어 품사를 못 읽음). **조용한 오류가 1 → 2로 늘었습니다.**
- 그래서 회귀 기준은 Mac 녹화 데이터로 두고, 다음 단계에서 **실제 iPhone으로 같은 쪽을 녹화한 고정 데이터**를 로컬 전용 회귀 세트에 더해야 합니다.
  실제 iPhone 측정은 아직 하지 않았습니다.

## 5. 하지 않은 것

- 실제 iPhone·Android 기기 실행 (Android 기기 없음). Android ML Kit 판독 정확도는 `research/ocr-android/README.md`(에뮬레이터).
- Android 에뮬레이터에서 앱 실행, 접근성 자동 점검, 다크 모드 스크린샷 (다크 토큰은 있고 위젯 테스트로 적용만 확인)
- 빌드를 위해 Android SDK 라이선스 동의(`sdkmanager --licenses`)를 했습니다. Gradle이 CMake 3.22.1을 내려받았습니다.
