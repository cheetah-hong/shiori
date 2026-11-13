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
│   ├── lib/src/study/      라이트너 4단계 스케줄러, 세션 빌더, 세션, 학습 일 경계, StudyService, 홈 이번 주 줄(study_week.dart, 순수 함수)
│   ├── lib/src/library/    LibraryService (재생목록 만들기·이름·순서·삭제, 검토 초안을 재생목록에 추가, 기본 단어장 추가, 빼기·되돌리기,
│   │                       단어 고치기·직접 추가·저장된 단어로 바꾸기), 고칠 값 word_edit.dart, 사전 채움 word_fill.dart, 단어 찾기 색인 word_search.dart
│   ├── lib/src/decks/      기본 단어장: 단어장 파일 읽기·검사(parseBuiltinDecks), 추가할 초안 만들기(deckDraft: 사전으로 뜻·품사 채우기)
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
├── packages/example_block/ 순수 Dart, 예문 블록 (Tatoeba 문장, JMdict 항목별 SQLite)
├── app/                    Flutter (iOS·Android)
│   ├── lib/app/blocks.dart 블록 지도: 끼우는 자리를 모두 이 파일 하나에
│   ├── lib/app/theme.dart  디자인 토큰: 역할 이름 색(라이트·다크 값은 여기에만), 간격·모서리·동작·일본어 글꼴 (4절 「화면 구성과 디자인 토큰」)
│   ├── lib/app/data.dart   화면이 같이 쓰는 읽기 모델 (저장·답변 뒤 새로고침)
│   ├── lib/adapters/       기기 블록: OCR 채널, image_picker, 개발용 샘플, 사전 asset 풀기(bundled_dictionary.dart), 첫 실행 안내 표시 파일(file_onboarding_store.dart)
│   ├── lib/features/       home · capture(등록·검토) · playlists(재생목록 고르기·화면·편집) · words(단어 시트·고치기·직접 추가·단어 찾기) · study(학습·범위 고르기) · settings(설정) · about(정보: 사전 출처·라이선스)
│   ├── lib/features/onboarding/  첫 실행 안내 세 장, 보일지 정하는 OnboardingGate, 본 표시 포트 OnboardingStore
│   ├── lib/features/opening/     콜드 스타트 오프닝 1.2초 (시간표 opening_timeline.dart, 그림 opening_painter.dart)
│   ├── lib/shared/         화면 공용 부품: sheet.dart(일력 장·절취선·메모 줄), bottom_action_bar.dart(아래 고정 바), ruled.dart(괘선 행),
│   │                       states.dart(빈 상태·불러오기 실패·불러오는 중), large_text.dart(큰 글자 문턱), widgets.dart(JpText 등), shi_stroke.dart(「し」 획)
│   ├── ios/Runner/OcrChannel.swift                         Apple Vision 채널 (회전 판별)
│   ├── android/app/src/main/kotlin/.../OcrChannel.kt       ML Kit 채널 (조각 단위, 회전),
│   │                                                       OcrGeometry.kt (순수 로직)
│   ├── assets/dev_samples/ 합성 샘플 페이지의 판독 기록 (개발용, 배포 빌드에서 막음, 5절)
│   ├── assets/dict/        JMdict full-lean gzip + 판 표시 파일 (빌드해서 만듦, git 제외, 5절)
│   └── integration_test/   시뮬레이터 흐름 스크린샷, 실제 OCR 채널 탐침
├── tools/ocr/              사진 → Apple Vision 두 패스 판독 기록 (make_fixture.py, vision_ocr.swift)
├── tools/synthetic/        합성 페이지 생성기 (make_pages.py 단어장 쪽, make_general_pages.py 배치가 다른 쪽)
├── tools/dict/             JMdict → SQLite (build_jmdict_db.py), 앱 asset (build_app_asset.py), 효과 측정
├── tools/decks/            기본 단어장 파일 (build_decks.py: 단어 목록 + JMdict → app/assets/decks/jlpt.json, 사전 asset처럼 git 제외, 원자료는 저장소 밖, --check)
├── tools/design/           앱 아이콘·시작 화면 생성기 (make_icons.py: iOS·Android 파일과 SVG를 모두 씀, --check는 비교만)
├── design/icon/            아이콘 그림 SVG (shiori.svg·shiori-dev.svg, 생성기 출력)
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
| 기본 단어장 (앱, `lib/features/decks/deck_data.dart`) | `app/assets/decks/jlpt.json`(사전 asset처럼 만들어 넣고 git 제외, `tools/decks/build_decks.py`, docs/dictionary.md 15절)을 `parseBuiltinDecks`로 읽음. 파일이 없는 빌드는 null(단어장 화면이 「이 빌드에는 없음」, 빈 홈의 버튼 숨김). 뜻은 추가할 때 `Lexicon`·`KoreanGlossary`(+위키낱말)로 채움 | `builtinDecksProvider`, `deckDictionariesProvider`(사전이 하나라도 안 열리면 null → 추가 안 함) | 다른 단어 목록 |
| `ExampleSentences` (`lookup(entryIds)` → 항목·읽기별 문장 `StoredExample`) | `TatoebaExamples` (`packages/example_block`, Tatoeba 문장 SQLite, CC BY 2.0 FR, `app/assets/dict/examples.*`, docs/dictionary.md 14절). core `cardExampleOf`가 사진 예문이 없는 카드에 `Lexicon` 항목 번호로 찾음. asset이 없으면 `EmptyExampleSentences` | `exampleSentencesProvider` (열기: `bundledExamplesProvider`, 카드: `cardExampleProvider`) | — |
| `ImageSource` | `ImagePickerSource` (카메라·앨범, 판독 뒤 임시 파일 `discard`) | `imageSourceProvider` | 문서 스캐너(cunning_document_scanner), 굽은 페이지 펴기 |
| `LibraryRepository` (단어는 라이브러리에 한 번 `Word.key`, 재생목록이 가리킴) | `DriftLibraryRepository` (SQLite, `packages/storage_drift`). 테스트: `InMemoryLibraryRepository`. 홈 재생목록은 `playlistStats()`(목록별 단어 수·숨김 수·마지막 추가를 한 번에). 단어 고치기는 `updateWord`(id로 내용·키를 바꿈, 만든 때·숨김은 그대로, 다른 단어의 키면 `DuplicateWordException`) | `libraryRepositoryProvider` (DB: `appDatabaseProvider`) | 백업·동기화 |
| `HiddenWordRepository` (「이미 알아요」 숨기기·되살리기, `hiddenWords()`) | 서재 블록이 함께 구현(`words.hidden_at`). 숨김은 단어 단위라 모든 재생목록에서 숨겨짐. `words()`는 숨긴 단어도 돌려주고 `Word.isHidden`으로 구분, 학습 세션·오늘 학습 수에서 빠짐 (verification.md 16·21절) | (없음: `StudyService`·`LibraryService`가 서재 블록에서 꺼냄) | 백업·동기화 |
| `ReviewRepository` (카드·기록은 `CardScope`와 `StudyMode`별: scope는 지금 공유 `''`만, 재생목록마다 따로 `p:<id>`는 칸만; 방식은 뜻 맞히기·일본어 떠올리기·듣고 맞히기·객관식) | `DriftReviewRepository` (같은 DB 파일). 테스트: `InMemoryReviewRepository` | `reviewRepositoryProvider` | 백업·동기화 |
| `StudyPreferencesRepository` (설정: 학습 기록 모드·학습 범위 모드·마지막 고른 학습 방식) | `DriftStudyPreferencesRepository` (`settings` 키-값 표). 테스트: `InMemoryStudyPreferencesRepository` | `studyPreferencesRepositoryProvider` → `studyPreferencesProvider` | 백업·동기화 |
| `BackupStore` (`read()`·`replaceAll(data)`: 백업에 드는 여섯 표를 한 번에) | `DriftBackupStore` (같은 DB 파일, 읽기·바꾸기 각각 트랜잭션 하나) | `backupStoreProvider` → `backupServiceProvider` | 동기화 |
| `BackupKeeper` (복원 직전 데이터 사본 하나) | `FileBackupKeeper` (앱 지원 폴더 `backup/before-restore.json`, 임시 파일에 쓰고 이름 바꾸기) | `backupKeeperProvider` | |
| 백업 파일 공유·고르기 (앱) | 공유 시트 `share_plus`(`shareBackupFile`), 파일 고르기 `file_selector`(`pickBackupFile`, iOS 파일 앱), 앱 버전 `package_info_plus` | `backupShareProvider`·`backupPickerProvider`·`backupAppProvider` | |
| `ReviewScheduler` | `LeitnerFourStepScheduler` (30분·3일·7일·21일) | `reviewSchedulerProvider` | FSRS |
| `Clock` | `SystemClock` (테스트: `FixedClock`) | `clockProvider` | |
| `Speech` (선택, 요청 `WordSpeech`·`SentenceSpeech`) | `VoicevoxSpeech` (iOS·Android: 기기 안 VOICEVOX, `packages/voicevox_block` + `app/lib/adapters/voicevox_*.dart`, docs/pronunciation.md). 그 밖의 플랫폼·테스트는 버튼 없음(`isAvailable` 거짓), `SilentSpeech`는 발음을 끈 블록 | `speechProvider` | 다른 음성, 기기 내장 TTS |
| 악센트 데이터 (앱) | Kanjium 표(`AccentTable`, `app/assets/accent/`), 없으면 빈 표 | `accentTableProvider` (열기: `accentDataProvider`) | |
| 설정값 | `StudySettings` (간격, 하루 시작 04시, 세션 10장, 상수) | `studySettingsProvider` | 설정 화면 |
| `OnboardingStore` (앱, `lib/features/onboarding/onboarding_store.dart`: 첫 실행 안내를 봤는지) | `FileOnboardingStore` (앱 지원 폴더 파일 `onboarding_seen`, 내용 = 안내 판 번호). 테스트: `InMemoryOnboardingStore` | `onboardingStoreProvider` (같은 파일) | |
| `CrashReporter` / `CrashLog` (앱, `lib/app/crash_reporting.dart`) | `FileCrashLog` (앱 지원 폴더의 텍스트 파일, 64KiB, 전송 없음). `main.dart`의 `installCrashHandlers`가 전역 오류 처리기에 연결 | `crashLogProvider` | 충돌 보고 서비스(5.3절) |

조립만 하는 provider(교체 대상 아님): `generalExtractorProvider`, `libraryServiceProvider`, `studyServiceProvider`, `backupServiceProvider`.

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
                                         기본 단어장(앱 안 파일) → deckDraft(사전으로 뜻·품사, 뜻 없는 단어 뺌) → LibraryService.addDeck
                                                             ▼                    (단어장 이름의 재생목록에, 규칙은 addDraft 그대로)
                                         StudyService(전체 / 재생목록 하나): 복습할 카드 먼저 + 새 단어로 채운 세션
                                                             ▼
                                         알고있음 / 다시 학습 → ReviewScheduler → ReviewRepository
```

- 숨긴 단어(이미 알아요)의 표제어만 추출에서 건너뛰고 그 수를 검토 요약에 보입니다. 라이브러리에 이미 있는 다른 단어는 검토에 그대로 나오고 「이미 라이브러리에 있음 · 저장된 뜻 유지」로 표시됩니다. 추가할 때 그 목록에 이미 있으면 「이미 있음」, 다른 목록에만 있으면 저장된 단어를 연결합니다(내용·학습 기록 그대로).
- 기본 단어장(docs/dictionary.md 15절, verification.md 41절)은 보통 재생목록으로 들어갑니다. 저장 스키마·백업 형식은 그대로이고 단어장과 재생목록의 연결은 저장하지 않습니다(이름이 같은 재생목록이 그 단어장). 다시 추가하면 그 목록에 없는 단어만 더해지고, 이미 있는 단어의 뜻·학습 기록·숨김은 그대로입니다. 큰 단어장도 홈 「오늘 학습」은 하루 목표만큼만 꺼내고, 재생목록 화면의 「이 목록 학습」은 지금처럼 그 목록의 카드 전부입니다.
- **단어 고치기·직접 추가·단어 찾기**(verification.md 42절): 고치기는 같은 단어 id의 내용만 바꿔 모든 재생목록·학습 카드에 같이 보이고, 학습 기록과 숨김은 그대로입니다(표제어 키가 바뀌고 기록이 있으면 「학습 기록 처음부터」를 고를 수 있음 — 단어를 먼저 고친 뒤 카드를 지움, 두 저장소라 한 트랜잭션이 아님). 다른 단어의 키가 되면 저장하지 않고 「저장된 단어로 바꾸기」를 묻습니다: 이 단어가 든 모든 목록의 같은 자리에 저장된 단어를 놓고, 고치던 단어와 그 기록은 어느 목록에도 없는 단어로 남깁니다(학습 기록은 합치지 않음). 직접 추가는 항목 하나짜리 초안으로 `addDraft` 규칙 그대로(있는 단어는 연결만). 사전 채움(`wordFill`·`mergeFill`)은 빈 칸만 채우고 값이 있는 칸은 제안만 합니다. 악센트·발음·사전 예문은 저장하지 않으므로 고친 표제어·읽기로 카드가 다시 찾습니다. 단어 찾기는 `words()`를 한 번 읽어 메모리 색인(`WordSearchIndex`)으로 거릅니다. 저장 스키마(v5)·백업 형식(판 1)은 그대로입니다.
- 교재·DAY는 없습니다(2026-11-06, verification.md 21절). 묶음은 학습자가 재생목록으로 만듭니다. 학습 기록은 단어 하나에 하나이고 재생목록끼리 공유합니다. 어느 목록에도 없게 된 단어는 라이브러리에 남지만 보이지 않고 학습에도 나오지 않으며, 다시 추가하면 기록이 이어집니다.

### 재생목록과 설정 확장 지점

- 저장 스키마 v5: `words`(`key` 유일), `playlists`, `playlist_words`(PK = 목록+단어, 목록 안 순서·추가한 때), `review_cards`(PK = scope+방식+단어)·`review_logs`(`scope`·`mode` 칸), `settings`(키-값). v4 파일은 카드·기록을 모두 뜻 맞히기로 옮기고(verification.md 33절), v3 이하 파일은 옮기지 않고 비운 뒤 시작합니다(둘 다 트랜잭션 하나, 실패하면 옛 파일 그대로, 「다시 불러오기」가 새 연결로 다시 시도).
- 설정 화면은 `학습 세션`(하루 목표 10·20·30·50·전부, 카드 순서 섞기), `학습 기록`(재생목록끼리 공유 / 재생목록마다 따로 — 준비 중), `학습 범위`(전체 복습 + 재생목록 골라 학습 / 항상 재생목록 하나씩 — 준비 중)를 보입니다. 학습 기록·학습 범위 값은 둘 다 저장되지만 지금은 기본만 동작합니다.
- 설정은 `settings` 표에 키 하나에 값 하나로 둡니다(`study.record_mode`·`study.scope_mode`, 기본값이 아닐 때만 `study.mode`·`study.daily_goal`·`study.shuffle`). 키와 받는 값은 core `StudySettingKeys` 한 곳에 있습니다. 새 설정은 스키마 버전 없이 키만 더하지만, **백업 형식 판은 올립니다**(아래 「백업 파일」: 백업은 아는 키만 받음).
- 「재생목록마다 따로」를 만들 때 고칠 곳: `StudyService.cardScopeFor`(목록 범위면 `CardScope.playlist(id)`), `AllWords`의 단어 구성(목록·단어 쌍), 목록 삭제 때 그 scope 카드 지우기, 모드 전환 때 카드 복사·합치기. 「이미 알아요」 숨김은 단어 단위 그대로 둡니다.
- 「항상 재생목록 하나씩」을 만들 때 고칠 곳: 홈의 학습 시작 버튼(`StudyPreferences.scopeMode`를 보고 전체 버튼 대신 범위 시트).

### 백업 파일 (설정 › 백업, verification.md 37절)

앱에는 서버가 없어 모든 데이터가 기기 안 SQLite에만 있습니다. 학습자가 직접 파일 하나로 내보내고 그 파일로 되돌립니다. 앱은 네트워크를 쓰지 않습니다(파일이 어디로 가는지는 공유 시트에서 학습자가 고름).

- **담는 것:** 단어(숨긴 때 포함), 재생목록, 재생목록 소속, 학습 카드(네 방식), 누름 기록, 설정. **담지 않는 것:** 사진·판독 기록·사전·목소리·악센트 데이터(앱에 같이 있거나 다시 만들 수 있음).
- 첫 실행 안내를 봤다는 표시는 DB·백업 밖(앱 지원 폴더 파일 `onboarding_seen`)입니다. 복원으로 안내가 다시 뜨지 않고, `settings` 키가 늘지 않아 백업 형식 판도 그대로입니다. 단어가 있는 서재로 복원하면 안내는 보이지 않습니다(아래 「화면 구성과 디자인 토큰」).
- **파일:** UTF-8 JSON 평문, 이름 `shiori-backup-YYYYMMDD-HHMM.json`(기기 현지 시각). 머리 `format: "shiori-backup"`, `version`(형식 판), `createdAt`(ISO 8601, 시간대 포함), `app`(`version`·`build`·`schema`). 표 다섯(`words`·`playlists`·`playlistWords`·`reviewCards`·`reviewLogs`)은 `{"columns": [...], "rows": [[...]]}`로 열 이름을 한 번만 적고, `settings`는 키→값 객체입니다. 시각은 DB와 같은 UTC 마이크로초 정수라 왕복해도 행 단위로 같습니다. 단어 `key`도 넣습니다.
- **형식 판(`version`)은 DB 스키마와 별개입니다.** 판 1 = 스키마 v5의 표 모양. 백업에 드는 표·열이 바뀌거나, 칸이 받는 값이 늘 때(**새 설정 키나 설정 값**, 학습 방식·답·품사 이름 — 판 1이 받는 이름은 `backup_rows.dart`의 `v1…` 상수로 고정) 판을 올리고, `backupUpgrades[옛 판]`에 옛 판 → 다음 판 변환(맵 → 맵)을 둡니다. 읽을 때는 변환을 먼저 하고 검사합니다. 앱보다 새 판은 거절합니다(「앱을 업데이트한 뒤」). `app.schema`는 진단용 기록일 뿐입니다.
- **크기 상한 64 MiB.** 복원은 고른 파일의 길이부터 보고 넘으면 읽지 않습니다. 내보내기도 같은 상한을 넘으면 만들지 않고, 만든 파일을 복원과 같은 검사로 한 번 읽어 본 뒤 내줍니다(복원할 수 없는 백업을 만들지 않음). 실측(Mac): 단어 3,000·카드 12,000·기록 50,000이 약 10 MiB(객체 행 기준, 배열 행은 그보다 작음), 읽기 0.1초·넣기 0.5초. 인코딩·검사는 다른 isolate(`Isolate.run`)에서 돕니다.
- **검사(신뢰하지 않는 입력):** 빈 파일, JSON 아님, 시오리 백업 아님, 판 없음·새 판, 모르는 최상위 키·열·설정 키, 열 순서, 타입(정수 자리의 실수 포함), 범위(시각 2000~2200년 전, 단계 0~4, 횟수 0 이상, 위치·누름 기록 id 2^40 이하, 글자 1만 자, id 256자, 빈 재생목록 이름, 예문 한쪽만, 모르는 방식·답·품사·scope), 중복 키, 없는 단어·재생목록을 가리키는 소속·카드. 누름 기록은 원래 외래 키가 없어(지운 단어의 기록도 남음) 가리키는 단어를 검사하지 않습니다. 첫 문제에서 멈추고 DB는 건드리지 않습니다.
- **복원은 「전부 바꾸기」 하나입니다(합치기 없음).** 한 트랜잭션에서 여섯 표를 비우고 넣습니다(자식 → 부모 순으로 비우고 부모 → 자식 순으로 넣음, 누름 기록은 id 그대로, 다음 누름 id는 복원한 기록의 가장 큰 id 다음부터 — `sqlite_sequence`의 그 줄을 지움). 실패하면 원래 그대로입니다. 스키마는 바뀌지 않습니다(v5).
- **복원 직전 사본 하나:** 지금 데이터(단어·재생목록·카드·기록 중 하나라도 있으면)를 같은 형식으로 앱 지원 폴더에 하나 써 둔 뒤에 바꿉니다. 사본을 쓰지 못하면 복원하지 않습니다. 사본이 있는 동안 설정에 「복원 전으로 되돌리기」가 보이고, 되돌리면 사본을 지웁니다(되돌리기는 새 사본을 만들지 않음). 다음 복원이 사본을 덮어씁니다.
- **내보내기 파일:** 임시 폴더 `shiori-backup/`에 써서 공유 시트에 넘기고, 시트가 닫히면 지웁니다(다음 내보내기 전에도 폴더를 비움). iOS 파일 고르기가 앱 임시 폴더에 복사한 파일도 읽은 뒤 지웁니다. 공유 시트는 누른 줄 위치(`sharePositionOrigin`)를 받습니다(iPad 팝오버).
- 다른 앱에서 「시오리로 열기」(문서 형식 등록)는 하지 않았습니다. 하려면 고유 확장자·UTI 등록·URL 처리가 필요합니다.

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

간격(`StudySettings.intervals`), 하루 시작 시각(`dayStartHour`, 기본 04시), 기본 하루 목표(`dailyGoal`, 10)는 설정값입니다.

한 세션의 장 수와 순서(verification.md 36절):

| 상황 | 결과 |
|---|---|
| 홈 오늘 학습·더 학습하기, 범위 시트의 「전체」 | 하루 목표(`StudyPreferences.dailyGoal`: 10·20·30·50·전부, 기본 10)만큼 |
| 재생목록 화면의 이 목록 학습·더 학습하기, 범위 시트의 목록 | 그 목록에서 지금 할 수 있는 카드 전부 |
| 고르는 순서 | 오늘 학습은 복습(때 이른 것 먼저) → 새 단어(목록 순), 더 학습하기는 단계 낮은 것 → 복습 날짜 이른 것. 장 수만큼 고른 뒤 섞음 |
| 카드 순서 섞기(기본 켬) | 고른 카드 전체(복습·새 단어 함께)를 세션을 만들 때 한 번 섞음. 끄면 위 순서 그대로 |
| 다시 학습을 누른 카드 | 섞기와 무관하게 큐 맨 뒤로 |

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
| 더 학습하기 (`StudyService.startMoreSession`) | 복습할 때가 **안 된** 카드만, 기억 단계 낮은 것 → 복습 날짜 이른 것 → 단어 순서로, 홈은 하루 목표만큼·재생목록은 전부. 때가 된 카드·새 단어·숨긴 단어는 고르지 않음(평소 학습 버튼이 맡음) |
| 더 학습하기에서 처음 알고있음 | 카드(단계·다음 복습·횟수) 그대로, 누른 기록만 남음(오늘 외운 수에 셈) |
| 더 학습하기에서 다시 학습 | 평소와 같음: 1단계·지금 복습·잊은 횟수 +1. 그 뒤의 알고있음은 평소 규칙(min(현재, 2) 또는 1단계) |
| 처음부터 다시 학습 (`resetWords`, 단어 하나) | 그 단어의 카드를 지워 새 단어로. 누른 기록·숨김은 그대로. 되돌리기(`restoreCards`)는 그 사이 다시 학습하지 않은 단어만 원래 카드로 |
| 모든 단어 처음부터 (`resetAll`, 설정) | 모든 scope의 카드를 지움. 누른 기록·숨김·재생목록·단어는 그대로 |

저장소 포트 `ReviewRepository.deleteCards(wordIds, {scope, mode})`(지운 카드를 돌려줌)와 `deleteAllCards({scope, mode})`(null이면 모든 scope·방식)가 카드 행만 지웁니다.

### 화면 구성과 디자인 토큰 (verification.md 39·40절)

화면은 「일력 한 장」 은유 하나로 그립니다: 바탕 위 괘선 행, 한 화면에 일력 장 하나, 주 행동은 아래 고정 바, 그림자 없음. 규칙 10개와 값·대비 수치는 verification.md 39.1절에 있습니다.

- **토큰은 `app/lib/app/theme.dart` 한 곳입니다.** `ShioriTokens`(ThemeExtension)의 역할 이름: 바탕 `bg`·`surface`·`surfaceStrong`·`line`, 글자 `text`·`text2`·`text3`·`outline`, 포인트 `accent`·`accentTint`·`accentText`·`onAccent`, 기능 `ok`/`okBg`·`warn`/`warnBg`·`risk`/`riskBg`/`onRisk`, `shadow`.
  값은 `ShioriTokens.light`·`ShioriTokens.dark` 두 묶음에만 있습니다. 같은 파일에 `Space`·`Radii`(버튼 모서리 14 하나)·`Motion`, 글자 크기 7단 `TypeScale`(12·13·15·17·20·28·96)과 굵기 3단 `Weights`(400 본문·600 강조·700 날짜 숫자와 표제어), 일본어 글 `JpType`(`headword`·`body`, `ja-JP`)과, Material 테마를 토큰으로 칠하는 `buildTheme`(누를 때 물결 없음)가 있습니다.
- **글꼴은 하나입니다.** Pretendard JP 1.3.9(SIL OFL 1.1) 정적 400·600·700을 `app/assets/fonts/`에 두고, `AppFonts`(`app/lib/app/fonts.dart`)가 이름과 대체 글꼴(Hiragino Sans)을 정합니다. 한국어·일본어 모두 이 글꼴이고 일본어 글에는 `JpType`·`JpText`가 `ja-JP` locale을 붙입니다. 라이선스는 `registerFontLicense()`가 라이선스 화면에 올립니다. 명조체는 쓰지 않습니다.
- **글자 크기·굵기는 토큰으로만** 씁니다. 화면 코드에 숫자 글자 크기나 400·600·700 밖의 굵기를 쓰면 `app/test/design/slop_test.dart`가 실패합니다.
- **위젯은 토큰만 읽습니다**(`context.tokens`). `app/lib/features`·`app/lib/shared`에 `Color(0x…)`나 `Colors.*`(`Colors.transparent` 빼고)가 들어가면 `app/test/design/touch_targets_test.dart`가 실패하고, 글자 4.5:1·경계 3:1·톤 3개 이하는 `token_contrast_test.dart`가 봅니다.
  팔레트를 바꾸는 일은 두 값 묶음을 바꾸는 것이고, 아이콘·시작 화면 색은 생성기 `tools/design/make_icons.py`의 `LIGHT`·`DARK`를 같이 고친 뒤 다시 돌립니다.
- **공용 부품** (`app/lib/shared/`):

| 부품 | 파일 | 하는 일 |
|---|---|---|
| `SheetFrame` | `sheet.dart` | 일력 장: 위 4px 먹 띠·옆 hairline·모서리 0·그림자 없음·아래 절취선. 한 화면에 한 장(홈 일력 장, 학습 카드, 「오늘 학습 끝」) |
| `TearLine` | `sheet.dart` | 점선 절취선: 장의 아래 끝(먹색), 목록의 끝(`line` 색) |
| `SheetMemoList` · `SheetMemoRow` | `sheet.dart` | 메모 줄: 왼쪽 라벨, 오른쪽 tabular 숫자 + 작은 단위(「12개」, 앞말이 있으면 「13개 중 8개」), 한 줄로 읽힘 |
| `BottomActionBar` (`BarAction`·`BarPrimaryButton`) | `bottom_action_bar.dart` | 아래 고정 바: 위 hairline, 54pt, 오른쪽 채운 주 버튼, 왼쪽 옅은 보조, 글자만(아이콘 없음). 큰 글자에서는 글자가 2.0배에서 멈추고 두 버튼이 폭을 2:3으로 나눔 |
| `RuledRow` | `ruled.dart` | 괘선 행(최소 56pt, 아래 hairline, 상자 없음) |
| `EmptyNote` · `LoadFailure` · `Loading` | `states.dart` | 빈 상태(문장 + 설명 줄), 불러오기 실패(「다시 불러오기」, 예외 글은 기록으로), 「불러오는 중」으로 읽히는 스피너 |
| `isLargeText` · `TextCaps` · `CappedText` | `large_text.dart` | 큰 글자 문턱 하나(약 AX1). 넘으면 나란한 것을 세로로. 고정된 자리의 글자 상한: 바·시트·대화상자 머리와 날짜 옆 월·요일 2.0배, 날짜 숫자·카드 표제어 1.4배(본문은 상한 없음) |
| `KeepWordsText` · `keepWords` | `keep_words.dart` | 제목이 낱말 가운데서 끊기지 않게(음절 사이 U+2060). 찾기·VoiceOver는 원래 글 그대로 |
| `showChoices` · `MoreButton` | `action_sheet.dart` | iOS 액션 시트(아래에서 올라오는 목록 + 취소): 학습 방식 고르기와 「···」 메뉴 |
| `JpText` | `widgets.dart` | 일본어 글에 `ja-JP` locale을 붙여 VoiceOver가 일본어로 읽게 함 |
| `adaptiveDialogAction` | `adaptive_dialog.dart` | `AlertDialog.adaptive`의 버튼(iOS 경고창 동작, 파괴는 `risk` 색) |

- **첫 화면 분기:** `ShioriApp(firstLaunch:)`(`app/lib/app/app.dart`). `main.dart`만 `firstLaunch: true`로 `Opening` → `OnboardingGate` → `HomeScreen`을 쌓습니다.
  `Opening`은 홈을 첫 프레임부터 아래에 만들고 그 위에 1.2초 층을 그립니다(탭하면 끝, 동작 줄이기면 없음, 한 실행에 한 번). `OnboardingGate`는 본 표시(`OnboardingStore`, 2절)와 서재를 보고 안내 또는 홈을 보입니다(서재가 비었을 때만 안내).
  테스트·미리보기는 `firstLaunch` 없이 바로 홈이라 다른 테스트에 오프닝·안내가 끼지 않습니다.
- **동작 줄이기:** iOS 「동작 줄이기」는 플랫폼의 `reduceMotion`만 켜므로 `MaterialApp.builder: Motion.follow`가 이를 앱 MediaQuery의 `disableAnimations`로 옮깁니다. 화면의 애니메이션은 `Motion.of(context, 길이)`(줄이면 0)나 `Motion.reduced(context)`를 거칩니다(오프닝, 세션 끝 찢김, 안내 페이지 넘김). 새 애니메이션도 이 둘을 씁니다.
- **주간 줄:** core `studyWeekOf(answeredAt, now:, calendar:)`(`packages/core/lib/src/study/study_week.dart`)는 순수 함수입니다. 앱 `studyWeekProvider`(`app/lib/features/home/home_week.dart`)가 최근 400일의 누름 기록 시각을 `ReviewRepository.logs(since:)`로 읽어 넘기고, 학습 일 경계는 `StudyCalendar`(하루 시작 04시)를 따릅니다. 저장하는 것은 없고 스키마도 그대로입니다.
- 홈 일력 장의 오늘 몫(`TodayPlan`, `app/lib/features/home/today_plan.dart`)은 표시만 합니다. 세션은 같은 `SessionSize`로 `StudyService`가 만듭니다.

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
| 홈 화면 이름 | 「시오리 dev」 | 「시오리」 |
| `assets/dev_samples/` | 들어감 (pubspec `flavors: [dev]`) | 들어가지 않음 |
| "샘플 페이지로 해 보기"·샘플 판독기 | 켜짐 | 꺼짐 |
| release 빌드 | **항상 실패** | 사전 asset·서명 키가 있으면 성공 |

- 앱 아이콘: iOS dev 세 구성은 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-dev`(아래 갈색 띠에 「DEV」), prod 세 구성은 `AppIcon`. Android는 dev flavor 소스셋 `app/android/app/src/dev/res/`가 아이콘을 덮습니다(적응형 아이콘은 바탕색만 갈색). 모두 `tools/design/make_icons.py`가 만듭니다(verification.md 39절).
- pubspec `default-flavor: dev`라서 `--flavor` 없는 명령(`flutter run`, `flutter test`, `flutter build apk --debug`, `flutter drive`)은 dev로 돕니다.
  `--flavor` 없는 release 빌드도 dev라서 실패합니다. 배포 빌드는 언제나 `--flavor prod`를 붙입니다.
- 샘플 켜짐은 build mode가 아니라 flavor로 정합니다: `devSamplesEnabledFor(appFlavor)`(`lib/adapters/dev_samples.dart`)는 `dev`일 때만 참이고,
  flavor가 없거나 다른 이름이면 거짓입니다. 화면과 판독기는 `devSamplesEnabledProvider`를 봅니다(테스트는 이 provider를 덮어씀).
- Android: `productFlavors` `dev`(`applicationIdSuffix = ".dev"`)·`prod`, 차원 `channel`(`app/android/app/build.gradle.kts`).
- iOS: 빌드 구성 `Debug-dev`·`Profile-dev`·`Release-dev`·`Debug-prod`·`Profile-prod`·`Release-prod`, 스킴 `dev`·`prod`.
  구성마다 `Flutter/<구성>.xcconfig`가 CocoaPods 설정과 `Flutter/Shared.xcconfig`(Generated + `Local.xcconfig`)를 읽습니다. Podfile도 여섯 구성을 압니다.
  홈 화면 이름은 같은 xcconfig의 `APP_DISPLAY_NAME`(Info.plist `CFBundleDisplayName = $(APP_DISPLAY_NAME)`), Android는 flavor의 `manifestPlaceholders["appLabel"]`(매니페스트 `android:label="${appLabel}"`)입니다.
  모든 구성이 iPhone 전용(`TARGETED_DEVICE_FAMILY = "1"`)입니다.
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
- **기본 단어장 파일**(`app/assets/decks/`)도 git에 없고 `python3 tools/decks/build_decks.py --built-on <날>`로 만듭니다(원자료는 저장소 밖 비공개 폴더). 없으면 debug 빌드는 단어장 없이 동작하고, release 검사(`asset_check.py --release`)는 실패합니다.
  첫 실행 때 앱 캐시 폴더로 풀고(백그라운드 isolate, 기기 백업에서 빠지게. 지워지면 다시 풂), 판 표시 파일이 바뀌면 다시 풉니다(`lib/adapters/bundled_dictionary.dart`).

### 5.3 충돌 기록

- 포트 `CrashReporter`(`record`는 절대 예외를 내지 않음)와 읽고 지울 수 있는 `CrashLog`가 `lib/app/crash_reporting.dart`에 있습니다(Flutter 오류 정보를 다루므로 core가 아니라 앱).
- `main.dart`가 `installCrashHandlers(crashLog)`로 `FlutterError.onError`(화면 오류)와 `PlatformDispatcher.instance.onError`(아무도 기다리지 않은 비동기 오류 등)를 연결합니다.
  원래 처리는 그대로입니다: 화면 오류는 콘솔에 찍히고, 비동기 오류는 `false`를 돌려 엔진 기본 처리도 돕니다. 기록은 백그라운드로 하고 실패해도 처리기를 깨지 않습니다.
  zone 처리기(`runZonedGuarded`)는 쓰지 않습니다. 루트 zone의 잡히지 않은 오류는 `PlatformDispatcher.onError`로 옵니다.
- 기본 블록 `FileCrashLog`(`lib/adapters/file_crash_log.dart`): 앱 지원 폴더 안 `diagnostics/crash_log.jsonl`, 한 줄에 기록 하나(시각, 출처, 오류 글, 스택, 위치).
  파일은 **64KiB 상한**이고 넘으면 오래된 기록부터 지웁니다. 기록 하나는 오류 글 4000자·스택 60줄까지 남기고, 그래도 상한보다 크면 스택을 빼고 글을 줄입니다.
  쓰기는 한 번에 하나씩, 임시 파일에 쓴 뒤 바꿔치기합니다. 같은 오류(출처·글·위치)가 1분 안에 되풀이되면 다시 쓰지 않습니다(매 프레임 나는 오류가
  디스크를 두드리거나 처음 기록을 밀어내지 않게). 형식이 맞지 않는 줄은 읽을 때 건너뜁니다. 네트워크로 보내지 않습니다.
- **기기 백업에서 뺌.** 앱 지원 폴더는 iOS 기기 백업(iCloud·컴퓨터)에 들어가고, 학습 DB(`shiori.sqlite`)는 그래서 백업으로 지켜집니다. 오류 기록은 그럴 필요가 없어
  `diagnostics/` 폴더째 `isExcludedFromBackup`을 겁니다(폴더에 걸면 안의 파일이 모두 빠짐. 파일에 걸면 쓰기마다 바꿔치기하는 새 파일에서 표시가 사라짐).
  표시는 포트 `BackupExclusion`(`lib/adapters/backup_exclusion.dart`)의 iOS 블록 `ChannelBackupExclusion` → 채널 `shiori/backup`(`ios/Runner/BackupChannel.swift`,
  앱 컨테이너 밖 경로는 거절)이 겁니다. 처음 쓸 때 한 번 걸고, 실패하면 다음에 다시 시도하며 기록은 그대로 합니다. 예전 판이 지원 폴더에 바로 둔 `crash_log.jsonl`은 처음 쓸 때 새 폴더로 옮깁니다.
  Android는 `allowBackup="false"`라 걸 것이 없습니다(`NoBackupExclusion`). 풀어 놓은 사전·발음 파일은 Caches 폴더라 처음부터 백업되지 않습니다.
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

### 5.5 스토어 심사 설정

수출 규정 답(`ITSAppUsesNonExemptEncryption = false`), 개인정보 매니페스트(`ios/Runner/PrivacyInfo.xcprivacy`), App Privacy 「수집 안 함」 근거,
개인정보처리방침(앱 안 `lib/features/about/privacy_policy.dart`, 웹 초안 `site/`), 계정 가입 뒤 할 일, Google Play 점검은 `docs/release.md`에 있습니다.
빌드 결과물은 `tools/release/check_build.py`(ios·apk·site)로 확인합니다.

## 6. 다음 블록 (이번에 하지 않은 것, 포트와 TODO만 있음)

| 순서 | 블록 | 끼울 자리 | 메모 |
|---|---|---|---|
| 1 | ~~drift 저장소~~ (완료) | `LibraryRepository`, `ReviewRepository` | 앱을 꺼도 단어와 학습 상태가 남습니다. 포트에 트랜잭션 추가. 스키마 v2(★ 열 걷어냄)와 v1 → v2 마이그레이션(verification.md 7.2절). 백업 파일(내보내기·복원)은 완료(4절 「백업 파일」) |
| 2 | 기기 판독 고정 데이터 | 로컬 전용 회귀 세트 | 실제 iPhone·Android에서 같은 쪽을 판독해 `$SHIORI_PRIVATE_DIR/textbook/`의 회귀 세트에 추가 (verification.md 4절) |
| 3 | 문서 스캐너 | `ImageSource` | 옆으로 누운 사진은 OCR 채널이 세웁니다(verification.md 6절). 추출기는 배치에 기대지 않으므로 스캐너가 자른 페이지도 읽음. 남은 일: 펼친 책에서 페이지 찾기(모서리 고치기 화면) |
| 4 | ~~JMdict~~ (완료) | `Lexicon` | 표기·읽기·품사·빈도, 정보 화면의 출처 표기. 남은 일: 데이터 정기 갱신 자동화(라이선스 의무, `docs/dictionary.md` 8·9절) |
| 5 | ~~발음~~ (완료) | `Speech` | 기기 안 VOICEVOX + Kanjium 음 높이 선(docs/pronunciation.md, verification.md 28절). 남은 일: 귀로 확인, iOS에서 asset을 풀지 않고 열기 |
| 6 | FSRS | `ReviewScheduler` | 복습 기록이 쌓인 뒤 |
| 7 | Claude (선택) | `TextRecognizer` | 비용 문제로 나중. 서버 함수 필요 |
| - | 홈 화면 위젯, 동기화 | 새 포트 | 3단계 |
