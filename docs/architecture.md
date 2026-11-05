# 시오리 앱 구조: 블록 교체형

> 사용자 요구: "유지보수 즉 블록처럼 끼웠다 교체했다가 각 기능별로 용이하게"
>
> 기능마다 **포트**(끼우는 자리, 인터페이스)를 두고, 실제 구현은 **블록**(어댑터)으로 끼웁니다.
> 블록을 바꾸는 일은 Riverpod provider override **한 줄**입니다.

## 1. 폴더와 의존 방향

```
nihongo-app/
├── packages/core/          순수 Dart (Flutter 의존 없음)
│   ├── lib/src/models/     OcrScan, CapturedEntry, CaptureDraft, Textbook·TextbookDay·Word, ReviewCard·ReviewLog
│   ├── lib/src/ports/      포트 11개 (아래 블록 지도)
│   ├── lib/src/capture/    캡처 파이프라인: 줄 정리(ML Kit 낮은 신뢰도 줄, 기호 잡음), 교재 템플릿 A(목록형)·B(항목형), 보정기 체인, 템플릿 자동 판별
│   ├── lib/src/study/      라이트너 4단계 스케줄러, 세션 빌더, 세션, 학습 일 경계, StudyService
│   ├── lib/src/library/    LibraryService (검토 초안 저장, 교재 › DAY 보기)
│   ├── lib/src/storage/    InMemory 저장소 (테스트용 블록, 트랜잭션 포함)
│   ├── lib/src/eval/       채점기 (lib/eval.dart로만 공개, 앱은 쓰지 않음)
│   ├── test/               단위·회귀 테스트, fixtures/synthetic/ (합성 페이지 판독 기록·정답), fixtures/synthetic_mlkit/ (같은 단어의 ML Kit형 판독)
│   └── tool/eval_capture.dart   점수표 출력
├── packages/storage_drift/ 순수 Dart, SQLite 저장 블록 (drift): 테이블, 저장소 두 개, 스키마 덤프 drift_schemas/ (v1·v2), 마이그레이션 단계
├── packages/dict_jmdict/   순수 Dart, JMdict SQLite 조회 (core를 모름). 테스트 DB test/fixtures/mini_jmdict.sql
├── packages/jmdict_block/  순수 Dart, 사전 블록: dict_jmdict를 core `Dictionary` 포트에 맞춘 어댑터.
│                           tool/eval_capture_dict.dart (사전 끔/켬 점수표)
├── app/                    Flutter (iOS·Android)
│   ├── lib/app/blocks.dart 블록 지도: 끼우는 자리를 모두 이 파일 하나에
│   ├── lib/app/theme.dart  디자인 토큰 (기획 페이지 팔레트)
│   ├── lib/app/data.dart   화면이 같이 쓰는 읽기 모델 (저장·답변 뒤 새로고침)
│   ├── lib/adapters/       기기 블록: OCR 채널, image_picker, 개발용 샘플, 사전 asset 풀기(bundled_dictionary.dart)
│   ├── lib/features/       home · capture(등록·검토) · library(교재) · study(학습) · about(정보: 사전 출처·라이선스)
│   ├── ios/Runner/OcrChannel.swift                         Apple Vision 채널 (회전 판별)
│   ├── android/app/src/main/kotlin/.../OcrChannel.kt       ML Kit 채널 (조각 단위, 회전),
│   │                                                       OcrGeometry.kt (순수 로직)
│   ├── assets/dev_samples/ 합성 샘플 페이지의 판독 기록 (개발용, 배포 빌드에서 막음, 5절)
│   ├── assets/dict/        JMdict full-lean gzip + 판 표시 파일 (빌드해서 만듦, git 제외, 5절)
│   └── integration_test/   시뮬레이터 흐름 스크린샷, 실제 OCR 채널 탐침
├── tools/reference/        Python 기준 구현 (parse_eval.py), 판독 도구, 기준 출력 덤프 도구
├── tools/synthetic/        합성 페이지 생성기 (make_pages.py)
├── tools/dict/             JMdict → SQLite (build_jmdict_db.py), 앱 asset (build_app_asset.py), 효과 측정
└── docs/                   이 문서, verification.md, dictionary.md, screenshots/
```

**의존 규칙**

1. `app → core` 한 방향입니다. `packages/core`는 Flutter도, 어떤 어댑터도 import하지 않습니다
   (pubspec 의존성은 NFKC 정규화용 `unorm_dart` 하나).
   사전은 `app → jmdict_block → (core, dict_jmdict)`입니다. core와 `dict_jmdict`는 서로를 모르고,
   어댑터 패키지가 Flutter 없이 둘을 잇습니다(사전을 켠 점수 측정을 `dart run`으로 돌리기 위해).
2. 화면(`features/`)은 포트와 `core`의 유스케이스(`CapturePipeline`, `LibraryService`, `StudyService`)만 부릅니다.
   구체 블록 클래스는 `blocks.dart`만 압니다.
3. 포트 수준의 실패는 `core`의 예외로 올라옵니다(`TextRecognitionException`, `ImageSourceException`, `LibraryException`).
   화면은 이것들을 잡아 한국어 문구를 보여 주고, 그 밖의 예외는 로그·보고 뒤 "다시 시도" 상태로 바꿉니다(화면이 멈추지 않게).
   OCR 블록이 돌려준 JSON이 형식에 맞지 않으면 `FormatException`으로 바로 실패합니다(좌표를 0으로 채우지 않음).
4. 모델은 불변입니다. 검토 수정, 세션 진행은 모두 새 객체를 돌려줍니다(`CapturedEntry.edit`, `StudySession.afterKnown`).
5. 콘텐츠(`Word`)와 학습 상태(`ReviewCard`)는 다른 저장소입니다. 단어를 다시 찍어 갱신해도 학습 기록은 그대로 남습니다.

## 2. 블록 지도

| 포트 (core) | 지금 끼운 블록 | provider (`blocks.dart`) | 다음 블록 |
|---|---|---|---|
| `TextRecognizer` | iOS `OcrChannel.swift` (Apple Vision, ja·ko 두 번, 글 방향으로 회전 판별), Android `OcrChannel.kt` (ML Kit japanese → korean, 조각 단위, 줄 각도로 회전 판별) → `PlatformTextRecognizer` | `textRecognizerProvider` | Cloud Vision, Claude |
| `TextRecognizer` (샘플) | `FixtureTextRecognizer` + `assets/dev_samples/` (합성 페이지). dev flavor에서만 켜짐(5.1절) | `sampleRecognizerProvider` (켜짐: `devSamplesEnabledProvider`) | (개발용 전용) |
| `TextbookTemplate` | `ListPageTemplate`(A 목록형), `EntryPageTemplate`(B 항목형) + `TemplateRegistry` 자동 판별 | `templateRegistryProvider` | 다른 교재 템플릿 |
| `EntryCorrector` (체인) | `ConfusableGlyphCorrector` → `KanaOkuriganaCorrector` → `ReadingLookalikeCorrector` → `BadgeMisreadCorrector` → `MeaningPunctuationCorrector` → `PosInferenceCorrector` → `CutMeaningFlagger` → `DictionaryCandidateCorrector`(표제어 빈 줄에 후보, 품사 힌트) → `DictionaryPairCorrector`(표제어·읽기 짝 확인: 규칙이 망친 단어 되돌리기, 헷갈리는 글자 고치기, "사전에 없음") → `MissingFieldFlagger` (`standardCorrectors()`) | `entryCorrectorsProvider` | |
| `Dictionary` (`byReading(pos:)`, `byHeadword`, `checkPair` → `PairStatus`, `fixHeadword`) | `JmdictDictionaryAdapter` (`packages/jmdict_block`, JMdict full-lean SQLite, CC BY-SA 4.0). 사전 asset이 없거나 열지 못하면 `EmptyDictionary` | `dictionaryProvider` (열기: `bundledDictionaryProvider`) | 데이터 정기 갱신 자동화 |
| `Lexicon` (`lookup(forms)`: 표기 여러 개 → 읽기·품사·빈도, 범용 단어 추출용) | `JmdictLexiconAdapter` (`packages/jmdict_block`), 테스트·합성 세트는 `InMemoryLexicon`. 앱에는 아직 연결하지 않음 (`docs/extraction.md`) | (없음) | 앱 연결, 한국어 뜻 조회 주입 |
| `KoreanGlossary` (`lookup(headword, readings:)` → 뜻 묶음 `KoreanSense`, `sources` 출처·판) | `KrdictGlossary` (`packages/krdict_block`, 한국어기초사전 일본어 대역어 역색인 SQLite, CC BY-SA 2.0 KR, `app/assets/dict/ko-glossary.*`, docs/dictionary.md 11절). 체인의 `KoreanMeaningFiller`가 `DictionaryPairCorrector` 뒤·`MissingFieldFlagger` 앞에서 빈 뜻 칸만 1순위 뜻으로 채움("추정"). asset이 없으면 `EmptyKoreanGlossary`, 체인에 채우기 없음 | `koreanGlossaryProvider` (열기: `bundledGlossaryProvider`) | 위키낱말사전(같은 DB), 뜻 묶음 후보 칩, 기기 번역 |
| `ImageSource` | `ImagePickerSource` (카메라·앨범, 판독 뒤 임시 파일 `discard`) | `imageSourceProvider` | 문서 스캐너(cunning_document_scanner), 굽은 페이지 펴기 |
| `LibraryRepository` | `DriftLibraryRepository` (SQLite, `packages/storage_drift`). 테스트: `InMemoryLibraryRepository`. 홈 교재 목록은 `textbookStats()`(교재별 단어 수·DAY를 한 번에) | `libraryRepositoryProvider` (DB: `appDatabaseProvider`) | 백업·동기화 |
| `HiddenWordRepository` (「이미 알아요」 숨기기·되살리기, `hiddenWords()`) | 서재 블록이 함께 구현(`DriftLibraryRepository`는 `words.hidden_at`, 스키마 v3). `words()`는 숨긴 단어도 돌려주고 `Word.isHidden`으로 구분, 학습 세션·오늘 학습 수에서 빠짐 (verification.md 16절) | (없음: `StudyService`·`LibraryService`가 서재 블록에서 꺼냄) | 백업·동기화 |
| `ReviewRepository` | `DriftReviewRepository` (같은 DB 파일). 테스트: `InMemoryReviewRepository` | `reviewRepositoryProvider` | 백업·동기화 |
| `ReviewScheduler` | `LeitnerFourStepScheduler` (30분·3일·7일·21일) | `reviewSchedulerProvider` | FSRS |
| `Clock` | `SystemClock` (테스트: `FixedClock`) | `clockProvider` | |
| `Speech` (선택) | `SilentSpeech` (발음 버튼 숨김) | `speechProvider` | flutter_tts, 클라우드 음성 |
| 설정값 | `StudySettings` (간격, 하루 시작 04시, 세션 10장) | `studySettingsProvider` | 설정 화면 |
| `CrashReporter` / `CrashLog` (앱, `lib/app/crash_reporting.dart`) | `FileCrashLog` (앱 지원 폴더의 텍스트 파일, 64KiB, 전송 없음). `main.dart`의 `installCrashHandlers`가 전역 오류 처리기에 연결 | `crashLogProvider` | 충돌 보고 서비스(5.3절) |

조립만 하는 provider(교체 대상 아님): `capturePipelineProvider`, `libraryServiceProvider`, `studyServiceProvider`.

## 3. 블록 교체 예시 (한 줄)

```dart
// app/lib/main.dart
runApp(ProviderScope(
  overrides: [
    textRecognizerProvider.overrideWithValue(CloudVisionRecognizer()),   // OCR 바꾸기
    // reviewSchedulerProvider.overrideWithValue(FsrsScheduler()),       // 복습 방식 바꾸기
    // dictionaryProvider.overrideWithValue(EmptyDictionary()),          // 사전 끄기 (기본: 번들 JMdict)
  ],
  child: const ShioriApp(),
));
```

새 블록이 지켜야 할 것은 포트 인터페이스 하나입니다. 예를 들어 OCR 블록은
`Future<OcrScan> recognize(PageImage)`만 구현하고, 일본어 우선·한국어 우선 두 판독을
`OcrScan(japanese:, korean:)`에 담으면 템플릿·보정기·검토 화면은 그대로 동작합니다.
테스트에서도 같은 방식입니다(`app/test/app/blocks_test.dart`의 "swapping a block is one override").

## 4. 흐름

```
사진(ImageSource) ─┐
샘플(dev_samples) ─┴→ TextRecognizer ──OcrScan(ja, ko)──→ prepareScan (줄 정리: ML Kit 낮은 신뢰도 줄,
                      (세운 좌표)                              기호 잡음 ★·☆·*·＊ 떼어 버리기)
                                                             ▼
                                         TemplateRegistry.detect (예문 줄 0 → A형, 3 이상 → B형, 그 사이는 번호 간격 > 0.08 → B형)
                                                             │ 칸 위치 = 상수 × 쪽마다 잰 배율 (번호 → 읽기 칸 거리)
                                                             ▼
                                         TextbookTemplate.parse → 원본 항목 + PageMeta(DAY·제목·쪽)
                                                             ▼
                                         EntryCorrector 체인 (사전 포함) → CaptureDraft (칸별 상태: 정상·추정·자동 보정됨·사전에 없음·의심·확인 필요)
                                                             ▼
                                         검토 화면(수정·제외·교재 선택) → LibraryService.saveDraft
                                                             ▼                    (단어 id = 교재id:번호, 다시 찍으면 갱신)
                                         StudyService: 복습할 카드 먼저 + 새 단어로 채운 세션
                                                             ▼
                                         알고있음 / 다시 학습 → ReviewScheduler → ReviewRepository
```

### 학습 규칙

복습 간격은 30분·3일·7일·21일 네 단계입니다.

| 상황 | 결과 |
|---|---|
| 새 단어, 처음부터 알고있음 | 4단계, 21일 뒤 |
| 새 단어, 다시 학습 1번 뒤 알고있음 | 2단계, 3일 뒤 |
| 새 단어, 다시 학습 2번 이상 뒤 | 1단계, 30분 뒤 |
| 복습 카드, 알고있음 | 한 단계 위(최대 4) |
| 복습 카드, 다시 학습 1번 뒤 | min(현재, 2) |
| 복습 카드, 다시 학습 2번 이상 뒤 | 1단계 |
| 다시 학습을 누른 순간 | 카드는 세션 맨 뒤로, 진행도는 그대로. 저장소에는 1단계·지금 복습으로 임시 저장(중간에 나가도 다시 나옴) |

간격(`StudySettings.intervals`), 하루 시작 시각(`dayStartHour`, 기본 04시), 세션 크기(`dailyGoal`, 기본 10)는 설정값입니다.

## 5. 배포 준비 (flavor, 차단 검사, 충돌 기록, 서명)

교재 본문(판독 기록, 정답, 사진)은 저장소에 넣지 않습니다. 로컬 전용 폴더 `$SHIORI_PRIVATE_DIR/textbook/`
(기본 `<저장소>/.private`)에 두고, 실제 교재 회귀 테스트와 기준 구현 대조 테스트는 그 자료가 있을 때만 돕니다(없으면 건너뜀).
저장소의 테스트와 앱의 "샘플 페이지로 해 보기"는 **합성 페이지**를 씁니다. 지어낸 단어를 교재와 같은 배치로 놓고,
해석 규칙이 다루는 OCR 실수를 일부러 넣었습니다(`tools/synthetic/make_pages.py`, 4쪽 35단어).
실제 OCR 탐침(`integration_test/vision_channel_probe_test.dart`)은 저장소 밖의 사진과 정답 경로를 `--dart-define`으로 받습니다.

### 5.1 flavor: dev와 prod

| | dev (개발) | prod (배포) |
|---|---|---|
| 앱 ID | `com.nihongoapp.shiori.dev` | `com.nihongoapp.shiori` |
| `assets/dev_samples/` | 들어감 (pubspec `flavors: [dev]`) | 들어가지 않음 |
| "샘플 페이지로 해 보기"·샘플 판독기 | 켜짐 | 꺼짐 |
| release 빌드 | **항상 실패** | 사전 asset·서명 키가 있으면 성공 |

- pubspec `default-flavor: dev`라서 `--flavor` 없는 명령(`flutter run`, `flutter test`, `flutter build apk --debug`, `flutter drive`)은 dev로 돕니다.
  `--flavor` 없는 release 빌드도 dev라서 실패합니다. 배포 빌드는 언제나 `--flavor prod`를 붙입니다.
- 샘플 켜짐은 build mode가 아니라 flavor로 정합니다: `devSamplesEnabledFor(appFlavor)`(`lib/adapters/dev_samples.dart`)는 `dev`일 때만 참이고,
  flavor가 없거나 다른 이름이면 거짓입니다. 화면과 판독기는 `devSamplesEnabledProvider`를 봅니다(테스트는 이 provider를 덮어씀).
- Android: `productFlavors` `dev`(`applicationIdSuffix = ".dev"`)·`prod`, 차원 `channel`(`app/android/app/build.gradle.kts`).
- iOS: 빌드 구성 `Debug-dev`·`Profile-dev`·`Release-dev`·`Debug-prod`·`Profile-prod`·`Release-prod`, 스킴 `dev`·`prod`.
  구성마다 `Flutter/<구성>.xcconfig`가 CocoaPods 설정과 `Flutter/Shared.xcconfig`(Generated + `Local.xcconfig`)를 읽습니다. Podfile도 여섯 구성을 압니다.
  RunnerTests는 스킴 `dev`로 돌립니다.
- **dev 앱 ID에 `.dev`를 붙인 이유:** 한 기기에 두 앱을 같이 깔 수 있고, 개발 빌드(샘플·실험 중인 코드)가 학습자의 실제 단어·복습 기록(prod 앱의 데이터)을 건드리지 않습니다.
  비용은 iOS에서 App ID가 하나 더 드는 것입니다. 무료(개인) 팀은 7일마다 다시 설치해야 하고, 새 App ID 수와 한 기기에 동시에 둘 수 있는 앱 수에 제한이 있으므로
  두 앱을 다 깔면 그 자리를 둘 씁니다. 자리가 모자라면 실제 학습에는 prod만 깔고(`flutter run --flavor prod --release`), dev는 시뮬레이터에서 씁니다.
  접미사를 없애려면 iOS `*-dev` 구성의 `PRODUCT_BUNDLE_IDENTIFIER`와 Android `applicationIdSuffix`를 지웁니다(두 앱이 같은 데이터를 쓰게 됨).

### 5.2 release 차단 검사

개발용 자료가 배포판에 들어가는 길과, 사전이나 서명 없이 배포판이 만들어지는 길을 막습니다. 검사는 두 겹입니다: 빌드 전에 flavor·사전·서명을 보고, 빌드 뒤에 결과물 안을 봅니다.

| 검사 | Android (`build.gradle.kts`) | iOS (Runner 셸 단계) |
|---|---|---|
| dev flavor의 release | `preDevReleaseBuild`에서 실패 | "Release checks (flavor, dictionary)": `Release-dev`면 실패 |
| 사전 asset 없음 (`app/assets/dict/`) | `preProdReleaseBuild`에서 실패 | 같은 단계: `Release*`에서 실패 |
| 서명 키 없음·빈 값·keystore 없음 | `preProdReleaseBuild`에서 실패 (5.4절) | (Xcode 서명 단계가 막음) |
| 결과물에 `dev_samples` | `copyFlutterAssets*Release` 뒤 출력 폴더를 보고 실패 | 마지막 단계 "Release bundle check (no dev samples)": 앱의 `App.framework/flutter_assets`를 보고 실패 |

- 결과물 검사는 flavor 이름과 상관없이 모든 release에 걸립니다. pubspec의 `flavors: [dev]`가 빠지거나 flavor가 늘어도 dev 자료가 배포판에 들어가지 않습니다.
- Flutter는 이전 빌드의 asset 폴더를 빌드 폴더에서 지우지 않습니다(Android `build/app/intermediates/flutter/<변형>/`, iOS `build/ios/<구성>/`).
  pubspec이 맞는데 결과물 검사가 실패하면 그렇게 남은 파일이니 `flutter clean` 뒤 다시 빌드합니다. 검사는 이런 남은 파일도 막습니다.
- **사전 asset**(`app/assets/dict/`)은 git에 없고 `python3 tools/dict/build_app_asset.py`로 만듭니다. 없으면 debug 빌드는 사전 없이 동작합니다.
  첫 실행 때 앱 캐시 폴더로 풀고(백그라운드 isolate, 기기 백업에서 빠지게. 지워지면 다시 풂), 판 표시 파일이 바뀌면 다시 풉니다(`lib/adapters/bundled_dictionary.dart`).

### 5.3 충돌 기록

- 포트 `CrashReporter`(`record`는 절대 예외를 내지 않음)와 읽고 지울 수 있는 `CrashLog`가 `lib/app/crash_reporting.dart`에 있습니다(Flutter 오류 정보를 다루므로 core가 아니라 앱).
- `main.dart`가 `installCrashHandlers(crashLog)`로 `FlutterError.onError`(화면 오류)와 `PlatformDispatcher.instance.onError`(아무도 기다리지 않은 비동기 오류 등)를 연결합니다.
  원래 처리는 그대로입니다: 화면 오류는 콘솔에 찍히고, 비동기 오류는 `false`를 돌려 엔진 기본 처리도 돕니다. 기록은 백그라운드로 하고 실패해도 처리기를 깨지 않습니다.
  zone 처리기(`runZonedGuarded`)는 쓰지 않습니다. 루트 zone의 잡히지 않은 오류는 `PlatformDispatcher.onError`로 옵니다.
- 기본 블록 `FileCrashLog`(`lib/adapters/file_crash_log.dart`): 앱 지원 폴더의 `crash_log.jsonl`, 한 줄에 기록 하나(시각, 출처, 오류 글, 스택, 위치).
  파일은 **64KiB 상한**이고 넘으면 오래된 기록부터 지웁니다. 기록 하나는 오류 글 4000자·스택 60줄까지 남기고, 그래도 상한보다 크면 스택을 빼고 글을 줄입니다.
  쓰기는 한 번에 하나씩, 임시 파일에 쓴 뒤 바꿔치기합니다. 같은 오류(출처·글·위치)가 1분 안에 되풀이되면 다시 쓰지 않습니다(매 프레임 나는 오류가
  디스크를 두드리거나 처음 기록을 밀어내지 않게). 형식이 맞지 않는 줄은 읽을 때 건너뜁니다. 네트워크로 보내지 않습니다.
  iOS는 앱 지원 폴더가 기기 백업(iCloud·컴퓨터)에 들어가므로 기록도 백업에 함께 들어갈 수 있고, 화면 안내에 그렇게 적었습니다(Android는 `allowBackup="false"`).
- 정보 화면 → "오류 기록 보기"(`lib/features/about/crash_log_screen.dart`): 최근 것부터 보여 주고, 복사(클립보드)와 지우기가 있습니다.
  무엇이 기록되는지와 사진 경로 같은 개인 정보가 섞일 수 있다는 안내를 화면 맨 위에 둡니다.
- **충돌 보고 서비스를 끼우는 방법**(지금은 넣지 않음. 계정·비용·개인 정보 처리 방침을 먼저 정해야 함):
  1. 서비스 SDK를 감싼 `CrashReporter` 구현을 `lib/adapters/`에 둡니다(`record`에서 SDK 호출, 예외는 삼킴).
  2. `main.dart`에서 로컬 기록과 함께 쓰려면 둘에 차례로 넘기는 작은 reporter로 묶어 `installCrashHandlers`에 넘깁니다. 정보 화면은 그대로 `crashLogProvider`(로컬 기록)를 봅니다.
  3. SDK가 자체 전역 처리기를 설치하는 방식(Crashlytics의 `recordFlutterFatalError` 등)이면 `installCrashHandlers`의 `present` 자리에 넘기거나, 그 SDK 문서대로 하고 로컬 기록만 `CrashReporter`로 둡니다.
  4. 개인 정보: 오류 글에 파일 경로가 들어갈 수 있으므로 보내기 전에 경로를 지우는 처리와 학습자 동의(설정 화면)를 함께 넣습니다.

### 5.4 release 서명

- **Android:** `app/android/key.properties`(git 제외)에 upload 키를 적습니다. 틀은 `app/android/key.properties.example`, 키 만드는 명령은 README "배포 빌드".
  파일이 없거나, 네 값(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) 중 빈 것이 있거나, `storeFile`이 파일이 아니면 prod release가 `preProdReleaseBuild`에서
  `Release signing: … A release is never signed with the debug key.`로 실패합니다. debug 키로 조용히 서명하지 않습니다(이전에는 release가 debug 키로 서명됐음).
  상대 경로 `storeFile`은 `app/android/` 기준이고, keystore는 저장소 밖에 두는 것을 권합니다.
- **iOS:** 서명은 `app/ios/Flutter/Local.xcconfig`(git 제외)의 `DEVELOPMENT_TEAM`으로 하고 자동 서명입니다. 모든 구성이 `Shared.xcconfig`를 거쳐 이 파일을 읽습니다.
  틀은 `Local.xcconfig.example`(배포용 수동 서명 자리 `CODE_SIGN_STYLE`·`CODE_SIGN_IDENTITY`·`PROVISIONING_PROFILE_SPECIFIER`를 주석으로 둠). 키·프로필 파일은 저장소에 두지 않습니다.
  App Store·TestFlight 배포는 유료 Apple Developer Program 팀이 있어야 합니다.

## 6. 다음 블록 (이번에 하지 않은 것, 포트와 TODO만 있음)

| 순서 | 블록 | 끼울 자리 | 메모 |
|---|---|---|---|
| 1 | ~~drift 저장소~~ (완료) | `LibraryRepository`, `ReviewRepository` | 앱을 꺼도 단어와 학습 상태가 남습니다. 포트에 트랜잭션 추가. 스키마 v2(★ 열 걷어냄)와 v1 → v2 마이그레이션(verification.md 7.2절). 남은 일: 백업(3단계) |
| 2 | 기기 판독 고정 데이터 | 로컬 전용 회귀 세트 | 실제 iPhone·Android에서 같은 쪽을 판독해 `$SHIORI_PRIVATE_DIR/textbook/`의 회귀 세트에 추가 (verification.md 4절) |
| 3 | 문서 스캐너 | `ImageSource` | 옆으로 누운 사진은 OCR 채널이 세웁니다(verification.md 6절). 해석기는 칸 위치를 내용에서 재므로 스캐너가 자른 페이지도 읽음. 남은 일: 펼친 책에서 페이지 찾기(모서리 고치기 화면) |
| 4 | ~~JMdict~~ (완료) | `Dictionary` | 읽기로 표제어 후보, 짝 확인("사전에 없음"), 헷갈리는 글자 고치기, 정보 화면의 출처 표기. 남은 일: 데이터 정기 갱신 자동화(라이선스 의무, `docs/dictionary.md` 8·9절) |
| 5 | flutter_tts | `Speech` | 블록만 바꾸면 카드에 발음 버튼이 나타남 |
| 6 | FSRS | `ReviewScheduler` | 복습 기록이 쌓인 뒤 |
| 7 | Claude (선택) | `TextRecognizer` 또는 `EntryCorrector` | 비용 문제로 나중. 서버 함수 필요 |
| - | 홈 화면 위젯, 백업 | 새 포트 | 3단계 |
