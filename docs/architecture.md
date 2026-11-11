# 시오리 앱 구조: 블록 교체형

> 사용자 요구: "유지보수 즉 블록처럼 끼웠다 교체했다가 각 기능별로 용이하게"
>
> 기능마다 **포트**(끼우는 자리, 인터페이스)를 두고, 실제 구현은 **블록**(어댑터)으로 끼웁니다.
> 블록을 바꾸는 일은 Riverpod provider override **한 줄**입니다.

## 1. 폴더와 의존 방향

```
nihongo-app/
├── packages/core/          순수 Dart (Flutter 의존 없음)
│   ├── lib/src/models/     OcrScan, CapturedEntry, CaptureDraft, Word·Playlist·PlaylistEntry, ReviewCard·ReviewLog·CardScope, StudyPreferences
│   ├── lib/src/ports/      포트 11개 (아래 블록 지도)
│   ├── lib/src/extract/    단어 추출기(배치에 기대지 않음, docs/extraction.md)와 검토 초안 만들기(page_draft.dart)
│   ├── lib/src/capture/    검토 화면의 편집(후보 고르기, 조각 붙이기, 고치기), 녹화 판독 블록, 문자 분류
│   ├── lib/src/study/      라이트너 4단계 스케줄러, 세션 빌더, 세션, 학습 일 경계, StudyService
│   ├── lib/src/library/    LibraryService (재생목록 만들기·이름·순서·삭제, 검토 초안을 재생목록에 추가, 빼기·되돌리기)
│   ├── lib/src/storage/    InMemory 저장소 (테스트용 블록, 트랜잭션 포함)
│   ├── lib/src/eval/       채점기 (lib/eval.dart로만 공개, 앱은 쓰지 않음)
│   ├── test/               단위·회귀 테스트, fixtures/synthetic/ (합성 단어장 쪽 판독 기록·정답), fixtures/synthetic_mlkit/ (같은 단어의 ML Kit형 판독),
│   │                       fixtures/synthetic_general/ (배치가 다른 합성 쪽)
│   └── tool/eval_extract.dart   점수표 출력 (표제어 기준)
├── packages/storage_drift/ 순수 Dart, SQLite 저장 블록 (drift): 테이블, 저장소 세 개(라이브러리·학습 기록·설정), 스키마 덤프 drift_schemas/ (v1~v4), v3 이하 파일 비우기
├── packages/dict_jmdict/   순수 Dart, JMdict SQLite 조회(표기 여러 개를 한 번에, core를 모름). 테스트 DB test/fixtures/mini_jmdict.sql
├── packages/jmdict_block/  순수 Dart, 사전 블록: dict_jmdict를 core `Lexicon` 포트에 맞춘 어댑터.
│                           tool/eval_extract_dict.dart (실제 JMdict·한국어 뜻 사전 점수표)
├── packages/krdict_block/  순수 Dart, 한국어 뜻 사전 블록 (한국어기초사전 역색인 SQLite)
├── app/                    Flutter (iOS·Android)
│   ├── lib/app/blocks.dart 블록 지도: 끼우는 자리를 모두 이 파일 하나에
│   ├── lib/app/theme.dart  디자인 토큰 (기획 페이지 팔레트)
│   ├── lib/app/data.dart   화면이 같이 쓰는 읽기 모델 (저장·답변 뒤 새로고침)
│   ├── lib/adapters/       기기 블록: OCR 채널, image_picker, 개발용 샘플, 사전 asset 풀기(bundled_dictionary.dart)
│   ├── lib/features/       home · capture(등록·검토) · playlists(재생목록 고르기·화면·편집) · study(학습·범위 고르기) · settings(설정) · about(정보: 사전 출처·라이선스)
│   ├── ios/Runner/OcrChannel.swift                         Apple Vision 채널 (회전 판별)
│   ├── android/app/src/main/kotlin/.../OcrChannel.kt       ML Kit 채널 (조각 단위, 회전),
│   │                                                       OcrGeometry.kt (순수 로직)
│   ├── assets/dev_samples/ 합성 샘플 페이지의 판독 기록 (개발용, 배포 빌드에서 막음, 5절)
│   ├── assets/dict/        JMdict full-lean gzip + 판 표시 파일 (빌드해서 만듦, git 제외, 5절)
│   └── integration_test/   시뮬레이터 흐름 스크린샷, 실제 OCR 채널 탐침
├── tools/ocr/              사진 → Apple Vision 두 패스 판독 기록 (make_fixture.py, vision_ocr.swift)
├── tools/synthetic/        합성 페이지 생성기 (make_pages.py 단어장 쪽, make_general_pages.py 배치가 다른 쪽)
├── tools/dict/             JMdict → SQLite (build_jmdict_db.py), 앱 asset (build_app_asset.py), 효과 측정
└── docs/                   이 문서, verification.md, dictionary.md, screenshots/
```

**의존 규칙**

1. `app → core` 한 방향입니다. `packages/core`는 Flutter도, 어떤 어댑터도 import하지 않습니다
   (pubspec 의존성은 NFKC 정규화용 `unorm_dart` 하나).
   사전은 `app → jmdict_block → (core, dict_jmdict)`입니다. core와 `dict_jmdict`는 서로를 모르고,
   어댑터 패키지가 Flutter 없이 둘을 잇습니다(사전을 켠 점수 측정을 `dart run`으로 돌리기 위해).
2. 화면(`features/`)은 포트와 `core`의 유스케이스(`GeneralExtractor`·`pageDraft`, `LibraryService`, `StudyService`)만 부릅니다.
   구체 블록 클래스는 `blocks.dart`만 압니다.
3. 포트 수준의 실패는 `core`의 예외로 올라옵니다(`TextRecognitionException`, `ImageSourceException`, `LibraryException`).
   화면은 이것들을 잡아 한국어 문구를 보여 주고, 그 밖의 예외는 로그·보고 뒤 "다시 시도" 상태로 바꿉니다(화면이 멈추지 않게).
   OCR 블록이 돌려준 JSON이 형식에 맞지 않으면 `FormatException`으로 바로 실패합니다(좌표를 0으로 채우지 않음).
4. 모델은 불변입니다. 검토 수정, 세션 진행은 모두 새 객체를 돌려줍니다(`CapturedEntry.edit`, `StudySession.afterKnown`).
5. 콘텐츠(`Word`)와 학습 상태(`ReviewCard`)는 다른 저장소입니다. 단어를 다시 저장해도 학습 기록은 그대로 남습니다.

## 2. 블록 지도

| 포트 (core) | 지금 끼운 블록 | provider (`blocks.dart`) | 다음 블록 |
|---|---|---|---|
| `TextRecognizer` | iOS `OcrChannel.swift` (Apple Vision, ja·ko 두 번, 글 방향으로 회전 판별), Android `OcrChannel.kt` (ML Kit japanese → korean, 조각 단위, 줄 각도로 회전 판별) → `PlatformTextRecognizer` | `textRecognizerProvider` | Cloud Vision, Claude |
| `TextRecognizer` (샘플) | `FixtureTextRecognizer` + `assets/dev_samples/` (합성 페이지). dev flavor에서만 켜짐(5.1절) | `sampleRecognizerProvider` (켜짐: `devSamplesEnabledProvider`) | (개발용 전용) |
| `Lexicon` (`lookup(forms)`: 표기 여러 개 → 읽기·품사·빈도) | `JmdictLexiconAdapter` (`packages/jmdict_block`, JMdict full-lean SQLite, CC BY-SA 4.0), 테스트·합성 세트는 `InMemoryLexicon`. 사전 asset이 없거나 열지 못하면 `EmptyLexicon`. 모든 쪽을 단어 추출기(+한국어 뜻 사전)로 읽음(`docs/extraction.md`; 가로줄 틀 경로는 2026-11-06에 걷어냄, 같은 문서 9절) | `lexiconProvider` (열기: `bundledDictionaryProvider`) → `generalExtractorProvider` | 데이터 정기 갱신 자동화 |
| `KoreanGlossary` (`lookup(headword, readings:)` → 뜻 묶음 `KoreanSense`, `sources` 출처·판; 거꾸로 찾기 `KoreanReverseGlossary`) | `KrdictGlossary` (`packages/krdict_block`, 한국어기초사전 일본어 대역어 역색인 SQLite, CC BY-SA 2.0 KR, `app/assets/dict/ko-glossary.*`, docs/dictionary.md 11절). 추출기가 짝짓기 근거, 사진에 뜻이 없는 사전 낱말의 1순위 뜻("추정"), 못 읽은 표제어 되살리기에 씀. asset이 없으면 `EmptyKoreanGlossary` | `koreanGlossaryProvider` (열기: `bundledGlossaryProvider`). 기초사전에 없는 낱말의 뜻만 위키낱말사전 보조 사전(같은 블록, 다른 asset `wikt-glossary.*`, CC BY-SA 4.0, docs/dictionary.md 13절)을 `wiktionaryGlossaryProvider` → 추출기 `meaningFallback`으로 | 기기 번역 |
| `ImageSource` | `ImagePickerSource` (카메라·앨범, 판독 뒤 임시 파일 `discard`) | `imageSourceProvider` | 문서 스캐너(cunning_document_scanner), 굽은 페이지 펴기 |
| `LibraryRepository` (단어는 라이브러리에 한 번 `Word.key`, 재생목록이 가리킴) | `DriftLibraryRepository` (SQLite, `packages/storage_drift`). 테스트: `InMemoryLibraryRepository`. 홈 재생목록은 `playlistStats()`(목록별 단어 수·숨김 수·마지막 추가를 한 번에) | `libraryRepositoryProvider` (DB: `appDatabaseProvider`) | 백업·동기화 |
| `HiddenWordRepository` (「이미 알아요」 숨기기·되살리기, `hiddenWords()`) | 서재 블록이 함께 구현(`words.hidden_at`). 숨김은 단어 단위라 모든 재생목록에서 숨겨짐. `words()`는 숨긴 단어도 돌려주고 `Word.isHidden`으로 구분, 학습 세션·오늘 학습 수에서 빠짐 (verification.md 16·21절) | (없음: `StudyService`·`LibraryService`가 서재 블록에서 꺼냄) | 백업·동기화 |
| `ReviewRepository` (카드·기록은 `CardScope`와 `StudyMode`별: scope는 지금 공유 `''`만, 재생목록마다 따로 `p:<id>`는 칸만; 방식은 뜻 맞히기·일본어 떠올리기·듣고 맞히기·객관식) | `DriftReviewRepository` (같은 DB 파일). 테스트: `InMemoryReviewRepository` | `reviewRepositoryProvider` | 백업·동기화 |
| `StudyPreferencesRepository` (설정: 학습 기록 모드·학습 범위 모드·마지막 고른 학습 방식) | `DriftStudyPreferencesRepository` (`settings` 키-값 표). 테스트: `InMemoryStudyPreferencesRepository` | `studyPreferencesRepositoryProvider` → `studyPreferencesProvider` | 백업·동기화 |
| `ReviewScheduler` | `LeitnerFourStepScheduler` (30분·3일·7일·21일) | `reviewSchedulerProvider` | FSRS |
| `Clock` | `SystemClock` (테스트: `FixedClock`) | `clockProvider` | |
| `Speech` (선택, 요청 `WordSpeech`·`SentenceSpeech`) | `VoicevoxSpeech` (iOS·Android: 기기 안 VOICEVOX, `packages/voicevox_block` + `app/lib/adapters/voicevox_*.dart`, docs/pronunciation.md). 그 밖의 플랫폼·테스트는 버튼 없음(`isAvailable` 거짓), `SilentSpeech`는 발음을 끈 블록 | `speechProvider` | 다른 음성, 기기 내장 TTS |
| 악센트 데이터 (앱) | Kanjium 표(`AccentTable`, `app/assets/accent/`), 없으면 빈 표 | `accentTableProvider` (열기: `accentDataProvider`) | |
| 설정값 | `StudySettings` (간격, 하루 시작 04시, 세션 10장, 상수) | `studySettingsProvider` | 설정 화면 |
| `CrashReporter` / `CrashLog` (앱, `lib/app/crash_reporting.dart`) | `FileCrashLog` (앱 지원 폴더의 텍스트 파일, 64KiB, 전송 없음). `main.dart`의 `installCrashHandlers`가 전역 오류 처리기에 연결 | `crashLogProvider` | 충돌 보고 서비스(5.3절) |

조립만 하는 provider(교체 대상 아님): `generalExtractorProvider`, `libraryServiceProvider`, `studyServiceProvider`.

## 3. 블록 교체 예시 (한 줄)

```dart
// app/lib/main.dart
runApp(ProviderScope(
  overrides: [
    textRecognizerProvider.overrideWithValue(CloudVisionRecognizer()),   // OCR 바꾸기
    // reviewSchedulerProvider.overrideWithValue(FsrsScheduler()),       // 복습 방식 바꾸기
    // lexiconProvider.overrideWithValue(EmptyLexicon()),                // 사전 끄기 (기본: 번들 JMdict)
  ],
  child: const ShioriApp(),
));
```

새 블록이 지켜야 할 것은 포트 인터페이스 하나입니다. 예를 들어 OCR 블록은
`Future<OcrScan> recognize(PageImage)`만 구현하고, 일본어 우선·한국어 우선 두 판독을
`OcrScan(japanese:, korean:)`에 담으면 단어 추출기·검토 화면은 그대로 동작합니다.
테스트에서도 같은 방식입니다(`app/test/app/blocks_test.dart`의 "swapping a block is one override").

## 4. 흐름

```
사진(ImageSource) ─┐
샘플(dev_samples) ─┴→ TextRecognizer ──OcrScan(ja, ko)──→ GeneralExtractor.extract (docs/extraction.md)
                      (세운 좌표)                              조각 수집·분류 → 사전 일괄 조회 → 표제어 고치기
                                                             → 읽기·뜻 짝짓기(내용 + 위치) → 문장 단어 → 되살리기 → 신뢰도
                                                             ▼
                                         pageDraft → CaptureDraft (사진 속 순서, 칸별 출처·신뢰도·근거 조각, 짝 없는 조각, 건너뛴 단어)
                                                             ▼
                                         검토 화면(후보 고르기·조각 붙이기·고치기·제외) → 「단어 N개 추가」 → 재생목록 고르기 → LibraryService.addDraft
                                                             ▼                    (같은 단어 = 표제어 wordKey 하나: 새 단어만 넣고, 있는 단어는 연결만)
                                         StudyService(전체 / 재생목록 하나): 복습할 카드 먼저 + 새 단어로 채운 세션
                                                             ▼
                                         알고있음 / 다시 학습 → ReviewScheduler → ReviewRepository
```

- 숨긴 단어(이미 알아요)의 표제어만 추출에서 건너뛰고 그 수를 검토 요약에 보입니다. 라이브러리에 이미 있는 다른 단어는 검토에 그대로 나오고 「이미 라이브러리에 있음 · 저장된 뜻 유지」로 표시됩니다. 추가할 때 그 목록에 이미 있으면 「이미 있음」, 다른 목록에만 있으면 저장된 단어를 연결합니다(내용·학습 기록 그대로).
- 교재·DAY는 없습니다(2026-11-06, verification.md 21절). 묶음은 학습자가 재생목록으로 만듭니다. 학습 기록은 단어 하나에 하나이고 재생목록끼리 공유합니다. 어느 목록에도 없게 된 단어는 라이브러리에 남지만 보이지 않고 학습에도 나오지 않으며, 다시 추가하면 기록이 이어집니다.

### 재생목록과 설정 확장 지점

- 저장 스키마 v5: `words`(`key` 유일), `playlists`, `playlist_words`(PK = 목록+단어, 목록 안 순서·추가한 때), `review_cards`(PK = scope+방식+단어)·`review_logs`(`scope`·`mode` 칸), `settings`(키-값). v4 파일은 카드·기록을 모두 뜻 맞히기로 옮기고(verification.md 33절), v3 이하 파일은 옮기지 않고 비운 뒤 시작합니다(둘 다 트랜잭션 하나, 실패하면 옛 파일 그대로, 「다시 불러오기」가 새 연결로 다시 시도).
- 설정 화면은 `학습 기록`(재생목록끼리 공유 / 재생목록마다 따로 — 준비 중)과 `학습 범위`(전체 복습 + 재생목록 골라 학습 / 항상 재생목록 하나씩 — 준비 중)를 보입니다. 값은 둘 다 저장되지만 지금은 기본만 동작합니다.
- 「재생목록마다 따로」를 만들 때 고칠 곳: `StudyService.cardScopeFor`(목록 범위면 `CardScope.playlist(id)`), `AllWords`의 단어 구성(목록·단어 쌍), 목록 삭제 때 그 scope 카드 지우기, 모드 전환 때 카드 복사·합치기. 「이미 알아요」 숨김은 단어 단위 그대로 둡니다.
- 「항상 재생목록 하나씩」을 만들 때 고칠 곳: 홈의 학습 시작 버튼(`StudyPreferences.scopeMode`를 보고 전체 버튼 대신 범위 시트).

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

학습 방식은 넷입니다(`StudyMode`, verification.md 33절): 뜻 맞히기, 일본어 떠올리기, 듣고 맞히기(소리를 듣고 뜻 4지선다), 객관식(일본어를 보고 뜻 4지선다). 기억 기록은 방식마다 따로이고 위 규칙을 방식마다 똑같이 씁니다.

| 상황 | 결과 |
|---|---|
| 한 세션 | 한 방식. 홈·재생목록 칩에서 고르고 마지막 방식을 기억 |
| 새 단어 | 방식마다 모든 단어가 새 단어(다른 방식의 기록과 무관). 일본어 떠올리기는 뜻이 빈 단어, 4지선다 방식은 보기 4개를 만들 수 없는 단어를 고르지 않음 |
| 4지선다에서 고름 | 고른 순간 저장: 맞으면 알고있음, 틀리면 다시 학습과 같은 처리. 결과는 「다음」까지 화면에 |
| 오늘 n개 외움, 홈·재생목록 숫자 | 고른 방식 것 |
| 처음부터 다시 학습, 모든 단어 처음부터 | 모든 방식의 카드를 함께 지움 |

학습한 단어를 다시 학습하는 길은 셋입니다(verification.md 29절). 위 간격 규칙은 바꾸지 않습니다.

| 기능 | 고르는 것·결과 |
|---|---|
| 더 학습하기 (`StudyService.startMoreSession`) | 복습할 때가 **안 된** 카드만, 기억 단계 낮은 것 → 복습 날짜 이른 것 → 단어 순서로 최대 `dailyGoal`장. 때가 된 카드·새 단어·숨긴 단어는 고르지 않음(평소 학습 버튼이 맡음) |
| 더 학습하기에서 처음 알고있음 | 카드(단계·다음 복습·횟수) 그대로, 누른 기록만 남음(오늘 외운 수에 셈) |
| 더 학습하기에서 다시 학습 | 평소와 같음: 1단계·지금 복습·잊은 횟수 +1. 그 뒤의 알고있음은 평소 규칙(min(현재, 2) 또는 1단계) |
| 처음부터 다시 학습 (`resetWords`, 단어 하나) | 그 단어의 카드를 지워 새 단어로. 누른 기록·숨김은 그대로. 되돌리기(`restoreCards`)는 그 사이 다시 학습하지 않은 단어만 원래 카드로 |
| 모든 단어 처음부터 (`resetAll`, 설정) | 모든 scope의 카드를 지움. 누른 기록·숨김·재생목록·단어는 그대로 |

저장소 포트 `ReviewRepository.deleteCards(wordIds, {scope, mode})`(지운 카드를 돌려줌)와 `deleteAllCards({scope, mode})`(null이면 모든 scope·방식)가 카드 행만 지웁니다.

## 5. 배포 준비 (flavor, 차단 검사, 충돌 기록, 서명)

교재 본문(판독 기록, 정답, 사진)은 저장소에 넣지 않습니다. 로컬 전용 폴더 `$SHIORI_PRIVATE_DIR/textbook/`
(기본 `<저장소>/.private`)에 두고, 실제 교재 회귀 테스트는 그 자료가 있을 때만 돕니다(없으면 건너뜀).
저장소의 테스트와 앱의 "샘플 페이지로 해 보기"는 **합성 페이지**를 씁니다. 지어낸 단어를 단어장 쪽에 놓고 OCR 실수를 일부러 넣은 4쪽 35단어
(`tools/synthetic/make_pages.py`)와, 배치가 다른 쪽(`tools/synthetic/make_general_pages.py`)입니다.
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
| 사전 asset 없음 (`app/assets/dict/`) | `checkReleaseDictionary`에서 실패 (`preProdReleaseBuild`가 의존) | 같은 단계: `Release*`에서 실패 |
| 사전 asset이 판 정보와 어긋남, JMdict가 35일보다 오래됨 | 같은 `checkReleaseDictionary`: `python3 tools/dict/asset_check.py --release` | 같은 단계: 같은 명령 |
| 발음 asset(`app/assets/voice/`·`app/assets/accent/`)이 없거나 판 정보와 어긋남, 엔진 파일 없음 (docs/pronunciation.md 2절) | 같은 명령 `--engine android` | 같은 단계: `--engine ios` |
| 위 검사를 돌릴 python3이 PATH에 없음 | `checkReleaseDictionary`에서 실패 | 같은 단계: `Release*`에서 실패 |
| 서명 키 없음·빈 값·keystore 없음 | `preProdReleaseBuild`에서 실패 (5.4절) | (Xcode 서명 단계가 막음) |
| 결과물에 `dev_samples` | `copyFlutterAssets*Release` 뒤 출력 폴더를 보고 실패 | 마지막 단계 "Release bundle check (no dev samples)": 앱의 `App.framework/flutter_assets`를 보고 실패 |

- 사전 검사(`asset_check.py --release`)는 release에만 겁니다. debug·profile(폰 설치 `flutter run --profile` 포함)은 오래되거나 어긋난 asset이어도 빌드됩니다.
  실패 메시지는 어긋난 것과 고치는 명령(`python3 tools/dict/refresh.py` 또는 그 사전의 빌드 명령)을 알려 줍니다. 기한과 그 이유는 `docs/dictionary.md` 12.2·12.4절입니다.
  iOS에서는 flutter가 실패한 단계의 `error:` 줄만 보여 주므로 셸 단계가 검사 출력의 줄마다 `error:`를 붙입니다.
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
| 3 | 문서 스캐너 | `ImageSource` | 옆으로 누운 사진은 OCR 채널이 세웁니다(verification.md 6절). 추출기는 배치에 기대지 않으므로 스캐너가 자른 페이지도 읽음. 남은 일: 펼친 책에서 페이지 찾기(모서리 고치기 화면) |
| 4 | ~~JMdict~~ (완료) | `Lexicon` | 표기·읽기·품사·빈도, 정보 화면의 출처 표기. 남은 일: 데이터 정기 갱신 자동화(라이선스 의무, `docs/dictionary.md` 8·9절) |
| 5 | ~~발음~~ (완료) | `Speech` | 기기 안 VOICEVOX + Kanjium 음 높이 선(docs/pronunciation.md, verification.md 28절). 남은 일: 귀로 확인, iOS에서 asset을 풀지 않고 열기 |
| 6 | FSRS | `ReviewScheduler` | 복습 기록이 쌓인 뒤 |
| 7 | Claude (선택) | `TextRecognizer` | 비용 문제로 나중. 서버 함수 필요 |
| - | 홈 화면 위젯, 백업 | 새 포트 | 3단계 |
