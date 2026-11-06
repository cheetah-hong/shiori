# 시오리 (가칭)

교재 사진을 찍으면 단어장이 되는 일본어 단어 학습 앱. 쪽의 배치에 기대지 않고 사진 속 일본어 단어·읽기·한국어 뜻을 내용으로 짝지어 모읍니다([docs/extraction.md](docs/extraction.md)).

- `packages/core/` 순수 Dart: 모델, 포트, 단어 추출기, 학습 로직
- `packages/dict_jmdict/` JMdict(SQLite) 조회
- `packages/jmdict_block/` 사전 블록: `dict_jmdict`를 core `Lexicon` 포트에 맞춘 어댑터(순수 Dart)
- `packages/krdict_block/` 한국어 뜻 사전 블록(한국어기초사전 일본어 대역어 역색인)
- `packages/storage_drift/` 저장 블록(SQLite, drift): 교재·DAY·단어와 복습 카드·기록을 기기에 저장
- `app/` Flutter (iOS·Android): 화면, 기기 어댑터, 블록 지도(`app/lib/app/blocks.dart`)
- `research/` OCR·스캔 실험 기록, `tools/` 합성 페이지·판독 기록·사전 빌드 도구
- 구조: [docs/architecture.md](docs/architecture.md) · 검증: [docs/verification.md](docs/verification.md) · 사전: [docs/dictionary.md](docs/dictionary.md)

```bash
cd packages/core && dart test && dart run tool/eval_extract.dart   # 합성 세트 점수표
python3 tools/dict/build_app_asset.py                               # 사전 asset(app/assets/dict/, git 제외). 없으면 앱은 사전 없이 동작
cd app && flutter test && flutter run                               # 합성 샘플 페이지로 흐름 확인 (dev flavor)
```

## 개발 빌드와 flavor

앱에는 flavor가 둘 있습니다([docs/architecture.md](docs/architecture.md) 5절).

- **dev** (기본값): 합성 샘플 페이지("샘플 페이지로 해 보기")가 들어 있고 앱 ID는 `com.nihongoapp.shiori.dev`입니다. release로는 빌드되지 않습니다.
- **prod**: 배포판. 샘플이 없고 앱 ID는 `com.nihongoapp.shiori`입니다.

`--flavor`를 붙이지 않으면 dev입니다. 그래서 개발 명령은 그대로 씁니다.

```bash
cd app
flutter run                     # dev, 샘플 있음 (= flutter run --flavor dev)
flutter test                    # dev
flutter run --flavor prod       # 배포판과 같은 화면(샘플 없음), debug
cd android && ./gradlew :app:testDevDebugUnitTest                  # Android 채널 단위 테스트 (JDK 21)
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme dev \
  -destination 'id=<시뮬레이터>' -only-testing:RunnerTests        # iOS 채널 단위 테스트
```

실제 iPhone에 설치하려면 `app/ios/Flutter/Local.xcconfig.example`을 `Local.xcconfig`(git 제외)로 복사하고 `DEVELOPMENT_TEAM`을 채웁니다.
dev와 prod는 앱 ID가 달라 한 기기에 같이 깔리고 데이터도 따로입니다. 무료(개인) Apple 팀은 설치가 7일 뒤 만료되고 App ID 수와 한 기기의 앱 수에 제한이 있으니,
실제 학습에는 prod(`flutter run --flavor prod --release`)만 깔아도 됩니다.

## 배포 빌드

배포 빌드는 언제나 `--flavor prod`입니다. 아래가 없으면 빌드가 멈추고 무엇이 없는지 알려 줍니다.

1. 사전 asset: `python3 tools/dict/build_app_asset.py`
2. Android upload 키 (한 번만). keystore와 비밀번호는 저장소 밖에 두고 잃어버리지 않게 보관합니다.
   ```bash
   keytool -genkeypair -v -keystore <저장소 밖 폴더>/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp app/android/key.properties.example app/android/key.properties   # git 제외. storeFile(절대 경로)·비밀번호를 채움
   ```
3. iOS 서명: `app/ios/Flutter/Local.xcconfig`의 `DEVELOPMENT_TEAM`(자동 서명). App Store·TestFlight 배포에는 유료 Apple Developer Program 팀이 필요합니다.

```bash
cd app
flutter build appbundle --flavor prod --release    # Play 스토어용 (.aab)
flutter build apk --flavor prod --release          # 직접 설치용 (.apk)
flutter build ipa --flavor prod --release          # App Store용 (서명 팀 필요)
flutter build ios --flavor prod --release --no-codesign   # 서명 없이 빌드만 확인
```

release 빌드는 dev 샘플이 결과물에 들어 있거나, 사전 asset이 없거나 판 정보와 어긋나거나, JMdict가 35일보다 오래됐거나(`python3 tools/dict/refresh.py`로 갱신),
Android `key.properties`가 없거나 비어 있으면 실패합니다(debug 키로 서명하지 않음). 사전 검사에는 python3이 필요합니다.
앱의 오류는 기기 안에만 기록되고(정보 → 오류 기록), 밖으로 보내지 않습니다.

## 테스트 데이터

저장소의 테스트와 앱의 샘플 페이지는 **합성 페이지**를 씁니다. 단어·뜻·예문·번역은 모두 지어낸 것이고,
교재와 같은 배치에 OCR이 흔히 내는 실수를 일부러 넣었습니다(`tools/synthetic/make_pages.py`).
같은 단어 일부를 Android ML Kit 채널이 돌려주는 모양과 실수로 만든 세트도 있습니다(`packages/core/test/fixtures/synthetic_mlkit/`).

실제 교재 페이지의 판독 기록과 정답은 교재 본문이라 저장소에 넣지 않습니다. 로컬에 `$SHIORI_PRIVATE_DIR/textbook/`
(기본 `<저장소>/.private/textbook/`)이 있으면 실제 교재 회귀 테스트와 기준 구현 대조 테스트도 돌고, 없으면 건너뜁니다.
