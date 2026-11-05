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
│   ├── lib/src/ports/      포트 9개 (아래 블록 지도)
│   ├── lib/src/capture/    캡처 파이프라인: 교재 템플릿 A(목록형)·B(항목형), 보정기 체인, 템플릿 자동 판별
│   ├── lib/src/study/      라이트너 4단계 스케줄러, 세션 빌더, 세션, 학습 일 경계, StudyService
│   ├── lib/src/library/    LibraryService (검토 초안 저장, 교재 › DAY 보기)
│   ├── lib/src/storage/    InMemory 저장소 (첫 저장 블록)
│   ├── lib/src/eval/       채점기 (lib/eval.dart로만 공개, 앱은 쓰지 않음)
│   ├── test/               단위·회귀 테스트, fixtures/synthetic/ (합성 페이지 판독 기록·정답)
│   └── tool/eval_capture.dart   점수표 출력
├── app/                    Flutter (iOS·Android)
│   ├── lib/app/blocks.dart 블록 지도: 끼우는 자리를 모두 이 파일 하나에
│   ├── lib/app/theme.dart  디자인 토큰 (기획 페이지 팔레트)
│   ├── lib/app/data.dart   화면이 같이 쓰는 읽기 모델 (저장·답변 뒤 새로고침)
│   ├── lib/adapters/       기기 블록: OCR 채널, image_picker, 개발용 샘플
│   ├── lib/features/       home · capture(등록·검토) · library(교재) · study(학습)
│   ├── ios/Runner/OcrChannel.swift                         Apple Vision 채널
│   ├── android/app/src/main/kotlin/.../OcrChannel.kt       ML Kit 채널
│   ├── assets/dev_samples/ 합성 샘플 페이지의 판독 기록 (개발용, 배포 빌드에서 막음, 5절)
│   └── integration_test/   시뮬레이터 흐름 스크린샷, 실제 OCR 채널 탐침
├── tools/reference/        Python 기준 구현 (parse_eval.py), 판독 도구, 기준 출력 덤프 도구
├── tools/synthetic/        합성 페이지 생성기 (make_pages.py)
└── docs/                   이 문서, verification.md, dictionary.md, screenshots/
```

**의존 규칙**

1. `app → core` 한 방향입니다. `packages/core`는 Flutter도, 어떤 어댑터도 import하지 않습니다
   (pubspec 의존성은 NFKC 정규화용 `unorm_dart` 하나).
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
| `TextRecognizer` | iOS `OcrChannel.swift` (Apple Vision, ja·ko 두 번), Android `OcrChannel.kt` (ML Kit japanese·korean) → `PlatformTextRecognizer` | `textRecognizerProvider` | Cloud Vision, Claude |
| `TextRecognizer` (샘플) | `FixtureTextRecognizer` + `assets/dev_samples/` (합성 페이지) | `sampleRecognizerProvider` | (개발용 전용) |
| `TextbookTemplate` | `ListPageTemplate`(A 목록형), `EntryPageTemplate`(B 항목형) + `TemplateRegistry` 자동 판별 | `templateRegistryProvider` | 다른 교재 템플릿 |
| `EntryCorrector` (체인) | `ConfusableGlyphCorrector` → `KanaOkuriganaCorrector` → `DictionaryCandidateCorrector` → `MissingFieldFlagger` | `entryCorrectorsProvider` | JMdict 읽기 검증 |
| `Dictionary` | `EmptyDictionary` | `dictionaryProvider` | JMdict (SQLite, CC BY-SA 4.0) |
| `ImageSource` | `ImagePickerSource` (카메라·앨범, 판독 뒤 임시 파일 `discard`) | `imageSourceProvider` | 문서 스캐너(cunning_document_scanner), 굽은 페이지 펴기 |
| `LibraryRepository` | `InMemoryLibraryRepository` | `libraryRepositoryProvider` | drift (SQLite) |
| `ReviewRepository` | `InMemoryReviewRepository` | `reviewRepositoryProvider` | drift (SQLite) |
| `ReviewScheduler` | `LeitnerFourStepScheduler` (30분·3일·7일·21일) | `reviewSchedulerProvider` | FSRS |
| `Clock` | `SystemClock` (테스트: `FixedClock`) | `clockProvider` | |
| `Speech` (선택) | `SilentSpeech` (발음 버튼 숨김) | `speechProvider` | flutter_tts, 클라우드 음성 |
| 설정값 | `StudySettings` (간격, 하루 시작 04시, 세션 10장) | `studySettingsProvider` | 설정 화면 |

조립만 하는 provider(교체 대상 아님): `capturePipelineProvider`, `libraryServiceProvider`, `studyServiceProvider`.

## 3. 블록 교체 예시 (한 줄)

```dart
// app/lib/main.dart
runApp(ProviderScope(
  overrides: [
    textRecognizerProvider.overrideWithValue(CloudVisionRecognizer()),   // OCR 바꾸기
    // reviewSchedulerProvider.overrideWithValue(FsrsScheduler()),       // 복습 방식 바꾸기
    // dictionaryProvider.overrideWithValue(JmdictDictionary(db)),       // 사전 끼우기 → 체인이 후보를 채움
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
샘플(dev_samples) ─┴→ TextRecognizer ──OcrScan(ja, ko)──→ TemplateRegistry.detect
                                                             │ (번호 간격 중앙값 > 0.08 → B형)
                                                             ▼
                                         TextbookTemplate.parse → 원본 항목 + PageMeta(DAY·제목·쪽)
                                                             ▼
                                         EntryCorrector 체인 → CaptureDraft (칸별 상태: 정상·자동 보정됨·확인 필요)
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

## 5. 배포 전에 할 일 (개발용 샘플과 교재 데이터)

- 교재 본문(판독 기록, 정답, 사진)은 저장소에 넣지 않습니다. 로컬 전용 폴더 `$SHIORI_PRIVATE_DIR/textbook/`
  (기본 `<저장소>/.private`)에 두고, 실제 교재 회귀 테스트와 기준 구현 대조 테스트는 그 자료가 있을 때만 돕니다(없으면 건너뜀).
- 저장소의 테스트와 앱의 "샘플 페이지로 해 보기"는 **합성 페이지**를 씁니다. 지어낸 단어를 교재와 같은 배치로 놓고,
  해석 규칙이 다루는 OCR 실수를 일부러 넣었습니다(`tools/synthetic/make_pages.py`, 4쪽 35단어).
- 지금 `dev_samples`는 개발 편의를 위해 pubspec asset으로 묶여 있습니다. 개발용 자료가 배포판에 들어가지 않도록
  **배포 빌드는 일부러 실패합니다**:
  - Android: `app/android/app/build.gradle.kts`의 `preReleaseBuild` 검사
  - iOS: Runner 타깃 맨 앞 셸 단계 "Block development samples in Release"
  - Dart: 배포판에서는 샘플 버튼이 숨고(`devSamplesEnabled = !kReleaseMode`) 판독기도 막힘
- 첫 배포 전에 할 일(TODO): `dev_samples`를 flavor 조건부 asset(`flavors: [dev]`)으로 옮기거나 pubspec에서 빼기,
  release 서명 설정(지금은 `flutter create` 기본값인 디버그 키), 충돌 보고 블록(`main.dart`의 전역 오류 처리기에 연결).
- 실제 OCR 탐침(`integration_test/vision_channel_probe_test.dart`)은 저장소 밖의 사진과 정답 경로를 `--dart-define`으로 받습니다.

## 6. 다음 블록 (이번에 하지 않은 것, 포트와 TODO만 있음)

| 순서 | 블록 | 끼울 자리 | 메모 |
|---|---|---|---|
| 1 | drift 저장소 | `LibraryRepository`, `ReviewRepository` | 지금은 앱을 끄면 단어가 사라집니다. 가장 먼저 필요. 포트에 트랜잭션을 함께 넣기(`repositories.dart` TODO) |
| 2 | 기기 판독 고정 데이터 | 로컬 전용 회귀 세트 | 실제 iPhone·Android에서 같은 쪽을 판독해 `$SHIORI_PRIVATE_DIR/textbook/`의 회귀 세트에 추가 (verification.md 4절) |
| 3 | 문서 스캐너 | `ImageSource` | 사진이 옆으로 누워 있으면 지금은 해석이 안 됩니다. 스캐너가 똑바로 세운 이미지를 줌 |
| 4 | JMdict | `Dictionary` | OCR이 건너뛴 단순한 한자 표제어를 읽기로 후보 제시 (`DictionaryCandidateCorrector`가 이미 연결됨, `docs/dictionary.md`) |
| 5 | flutter_tts | `Speech` | 블록만 바꾸면 카드에 발음 버튼이 나타남 |
| 6 | FSRS | `ReviewScheduler` | 복습 기록이 쌓인 뒤 |
| 7 | Claude (선택) | `TextRecognizer` 또는 `EntryCorrector` | 비용 문제로 나중. 서버 함수 필요 |
| - | 홈 화면 위젯, 백업 | 새 포트 | 3단계 |
