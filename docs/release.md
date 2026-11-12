# 출시 준비 (App Store 먼저, Google Play 다음)

시오리는 **무료·광고 없음·iPhone 전용** 앱이고, 데이터를 모으지 않습니다. 이 문서는 심사에 필요한 설정과 답, 그리고 개발자 계정에 가입한 뒤 할 일을 모읍니다.
빌드 구성과 release 차단 검사는 `docs/architecture.md` 5절, 검증 기록은 `docs/verification.md` 38절입니다.

## 1. 지금 상태 (계정 없이 끝낸 것)

| 항목 | 설정 | 위치 |
|---|---|---|
| 기기 | iPhone 전용 (`TARGETED_DEVICE_FAMILY = "1"`, 모든 빌드 구성) | `app/ios/Runner.xcodeproj/project.pbxproj` |
| 수출 규정 | `ITSAppUsesNonExemptEncryption = false` (5절) | `app/ios/Runner/Info.plist` |
| 개인정보 매니페스트 | 추적 안 함·수집 없음·필수 이유 API 2범주 (6.2절) | `app/ios/Runner/PrivacyInfo.xcprivacy` (Runner 타깃 리소스) |
| 홈 화면 이름 | prod 「시오리」, dev 「시오리 dev」 | iOS `app/ios/Flutter/*-{dev,prod}.xcconfig`의 `APP_DISPLAY_NAME`, Android flavor의 `manifestPlaceholders["appLabel"]` |
| 기기 백업 | 학습 DB는 백업에 남김. 오류 기록 폴더는 뺌, 사전·발음 파일은 Caches(백업 안 됨) | `app/lib/adapters/file_crash_log.dart`, `backup_exclusion.dart`, `app/ios/Runner/BackupChannel.swift` |
| 개인정보처리방침 | 앱 안 전문(정보 → 개인정보), 웹 페이지 초안 `site/` | `app/lib/features/about/privacy_policy.dart`, `site/*.html` |
| 번들 ID | `com.nihongoapp.shiori`(prod)·`com.nihongoapp.shiori.dev`(dev) — 늘리지 않음 | |

빌드 결과물 검사(설정이 실제 앱에 들어갔는지):

```bash
cd app
flutter build ios --flavor prod --release --no-codesign
python3 ../tools/release/check_build.py ios build/ios/iphoneos/Runner.app --flavor prod
flutter build ios --flavor dev --debug --simulator
python3 ../tools/release/check_build.py ios build/ios/iphonesimulator/Runner.app --flavor dev
flutter build apk --flavor dev --debug
python3 ../tools/release/check_build.py apk build/app/outputs/flutter-apk/app-dev-debug.apk --flavor dev
python3 ../tools/release/check_build.py site            # 게시 직전에는 --publish
```

`ios`는 표시 이름·`UIDeviceFamily == [1]`·암호화 답·앱 매니페스트(있음, 올바른 plist, 소스와 같음)를 보고,
매니페스트 없는 framework가 알려진 목록(6.2절) 밖에서 새로 생기면 실패합니다(새 Pod·플러그인을 넣었을 때 신고를 잊지 않게).

## 2. iOS 출시 체크리스트

### 2.1 계정 가입 전 (끝남)
- [x] 1절 설정, 앱 안 개인정보처리방침
- [x] 심사 답 초안(4~6절), 웹 페이지 초안(7절)
- [ ] 문의 이메일 정하기 → `site/*.html`의 `{{CONTACT_EMAIL}}`과 앱 `privacyContact` 채우기
- [ ] 웹 페이지 게시(7.3절) → 앱 `privacyPolicyUrl` 채우기

### 2.2 계정 가입 뒤
1. Apple Developer Program(유료) 가입. 지금의 무료 개인 팀으로는 App Store·TestFlight에 올릴 수 없습니다.
2. `app/ios/Flutter/Local.xcconfig`(git 제외)의 `DEVELOPMENT_TEAM`을 유료 팀 ID로 바꿉니다.
3. Certificates, Identifiers & Profiles → Identifiers에 App ID `com.nihongoapp.shiori` 등록(Capabilities 추가 없음). dev ID는 기기 설치용으로만 필요하면 그때 등록.
4. 서명: 자동 서명(기본)이면 Xcode가 배포 인증서·프로필을 만듭니다. 고정 프로필을 쓰려면 `Local.xcconfig.example`의 수동 서명 줄을 씁니다.
5. App Store Connect → 앱 → 새 앱: 플랫폼 iOS, 이름 「시오리」, 기본 언어 한국어, 번들 ID `com.nihongoapp.shiori`, SKU(아무 고유 문자열, 예: `shiori-ios`).
6. 앱 정보: 카테고리 「교육」(보조 「참고」), 가격 무료, 판매 지역.
7. App Privacy(6절) · 연령 등급(4절) · 수출 규정(5절) · 개인정보처리방침 URL·지원 URL(7절) 입력.
8. 빌드·업로드:
   ```bash
   cd app
   flutter build ipa --flavor prod --release      # release 차단 검사(사전·발음 asset, flavor)가 함께 돔
   # build/ios/ipa/*.ipa 를 Transporter 앱으로 올리거나, Xcode Organizer(Product → Archive)로 올림
   ```
   업로드 때 수출 규정 질문은 Info.plist 값으로 건너뜁니다.
9. 업로드 뒤 Apple에서 **ITMS-91053**(필수 이유 API 신고 누락) 메일이 오면 6.2절의 B안으로 갑니다.
10. TestFlight 내부 테스트(본인 기기) → 실제 교재 사진 등록·학습·발음·백업 복원 한 바퀴.
11. 버전 정보: 스크린샷(3절), 설명·키워드·지원 URL, 심사 메모(2.3절) → 심사 제출.

### 2.3 심사 메모 초안
> 로그인이 없고 인터넷을 쓰지 않습니다. 첫 화면 「페이지 등록」에서 일본어 단어장 교재 쪽(일본어 단어와 한국어 뜻이 함께 인쇄된 쪽)을 찍거나 사진을 고르면,
> 기기 안에서 글자를 읽어 단어를 뽑고, 검토 화면에서 확인한 뒤 저장합니다. 교재가 없으면 일본어와 한국어가 함께 인쇄된 아무 학습 자료나 화면 사진으로도 시험할 수 있습니다.
> 저장한 단어는 「오늘 학습」에서 정해진 간격으로 복습합니다. 카메라·사진 권한은 쪽을 찍거나 고를 때만 씁니다.

(영문이 필요하면 같은 내용을 영어로 붙입니다.)

## 3. 스크린샷

- 필수 규격: **6.9″ iPhone** 세로 1320×2868 또는 1290×2796(둘 중 하나), 1~10장. 6.9″를 올리면 작은 iPhone 크기는 자동으로 줄여 씁니다. iPad는 없음(iPhone 전용).
- 찍는 기기: iPhone 17 Pro Max 시뮬레이터(6.9″, 1320×2868), prod 빌드, 합성 데이터.
- 찍을 화면(안): ① 홈(오늘 학습) ② 페이지 등록 → 검토 화면 ③ 단어장 ④ 학습 카드(뜻 맞히기) ⑤ 발음·음 높이 선 ⑥ 재생목록 ⑦ 설정(하루 목표).
- 실제 교재 사진·교재 이름이 보이면 안 됩니다. 합성 쪽이나 직접 만든 자료를 씁니다.

## 4. 연령 등급 질문 답 초안

App Store Connect 연령 등급 질문지(2025년 개정판 기준)에 모두 「없음/아니요」로 답해 **4+**가 나오는 것이 목표입니다.

| 질문 범주 | 답 | 근거 |
|---|---|---|
| 폭력·성적 내용·욕설·공포·약물·도박 등 콘텐츠 | 없음 | 단어장 앱, 사용자가 찍은 교재와 사전 데이터만 표시 |
| 의료·건강 정보 | 없음 | |
| 사용자 생성 콘텐츠 공유·메시지·채팅 | 아니요 | 등록한 단어는 기기 안에만, 다른 사용자에게 보이지 않음 |
| 웹 접근(제한 없는 웹 콘텐츠) | 아니요 | 브라우저·웹 보기 없음, 인터넷 연결 없음 |
| 광고 | 아니요 | |
| 위치 공유·연령 확인 | 아니요 | |
| 경품·시뮬레이션 도박 | 아니요 | |

## 5. 수출 규정 답

`ITSAppUsesNonExemptEncryption = false`. Apple 문서(2026-11-12 확인): 앱과 링크한 서드파티 라이브러리가 암호화를 쓰지 않거나 **면제 대상 암호화만** 쓰면 `NO`.

| 쓰는 것 | 판정 |
|---|---|
| 네트워크·HTTPS | 없음 (`app/test/app/no_network_test.dart`가 의존성·코드를 검사, iOS 실행 파일에 URLSession 호출 없음) |
| `crypto` 패키지 | sha256 해시(asset 무결성 확인·발음 캐시 키)뿐 — 암호화 아님 |
| SQLite | 암호화 확장 없음 |
| VOICEVOX 음성 모델 | 모델 파일 안의 신경망이 암호화돼 있고 VOICEVOX ONNX Runtime이 풀어 씁니다. **모델 저작권 보호(복제 방지)에 한정된 복호화**로, 미국 EAR Category 5 Part 2의 「지식재산·저작권 보호에 한정된 암호」 제외에 해당한다고 봅니다 |

- 법률 판단은 아닙니다. 업로드 때 질문지가 다시 나오면(키를 지웠을 때 등) 「저작권 보호에 한정」 항목으로 답하고, 판단이 달라지면 `true`로 바꾸고 문서를 제출합니다.

## 6. App Privacy 답과 개인정보 매니페스트

### 6.1 App Store Connect 「앱이 수집하는 데이터」: **데이터를 수집하지 않음**

Apple 정의(2026-11-12 확인): 「수집」은 기기 밖으로 보내 개발자나 제3자가 실시간 처리보다 오래 볼 수 있게 하는 것이고, **기기 안에서만 처리하는 데이터는 수집이 아닙니다.**

| 데이터 | 실제 | 판정 |
|---|---|---|
| 사진 | image_picker가 앱 임시 폴더에 복사 → Apple Vision으로 기기 안 판독 → 판독 뒤 삭제(`CaptureController.pick`의 `finally`). 저장·전송 없음 | 수집 아님 |
| 단어·학습 기록·설정 | 기기 안 SQLite | 수집 아님 |
| 오류 기록 | 기기 안 파일. 사용자가 정보 화면에서 직접 복사할 때만 나감(앱이 보내지 않음) | 수집 아님 |
| 판독 기록 내보내기(공유 시트) | release 빌드에는 없음 | 해당 없음 |
| 분석·광고·추적 SDK | 없음 | — |

- 앱에 개발자에게 보내는 기능(의견 보내기, 충돌 보고 서비스 등)을 넣으면 이 답을 다시 정합니다(`docs/architecture.md` 5.3절).

### 6.2 개인정보 매니페스트 (`PrivacyInfo.xcprivacy`)

2024-05-01부터 필수 이유 API를 매니페스트에 적지 않은 앱은 App Store Connect가 받지 않습니다. release 빌드 결과물의 실행 파일마다 쓰는 API를 확인했습니다(`nm -u`, 2026-11-12):

| 실행 파일 | 필수 이유 API | 자체 매니페스트 | Apple의 「매니페스트·서명 필요 SDK」 목록 |
|---|---|---|---|
| Runner (Swift 채널) · App (Dart) | 없음 | (앱) | — |
| Flutter | 파일 시각, 부팅 시각 | 있음 | 있음 — 서명 있음(FLUTTER.IO LLC) |
| image_picker_ios · share_plus | 없음 | 있음 | 있음(소스 배포라 서명 해당 없음) |
| path_provider_foundation | 네이티브 pod 없음(FFI로 objective_c 사용) | — | path_provider 있음 |
| objective_c · integration_test | 없음 | 없음 | 없음 |
| **sqlite3** (sqlite3 패키지가 빌드한 SQLite) | 파일 시각(`stat`·`fstat`·`lstat`), **디스크 공간**(`statfs`·`fstatfs`) | 없음 | 없음 |
| **voicevox_core** · **voicevox_onnxruntime** | 파일 시각(`stat`·`fstat`·`lstat`) | 없음 | 없음 |

앱 매니페스트(A안, 지금): 매니페스트 없는 세 라이브러리의 사용을 앱 매니페스트에 모아 적습니다.

| 범주 | 이유 코드 | 뜻 |
|---|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | 앱 컨테이너 안 파일의 시각·크기 등 메타데이터 |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `E174.1` | 파일을 쓸 공간 확인. SQLite의 `statfs`는 파일 시스템 종류를 보는 것이라 딱 맞는 코드가 없어 가장 가까운 것을 씀(같은 방식의 공개 선례: realm-core 매니페스트) |

- `NSPrivacyTracking = false`, 추적 도메인 없음, 수집 데이터 없음.
- **B안(ITMS-91053 메일이 오면):** 세 framework 번들 안에도 각자 매니페스트를 넣습니다. Apple 문서는 「필수 이유 API를 쓰는 실행 파일·동적 라이브러리를 담은 번들」에 매니페스트가 있어야 한다고 적습니다.
  VOICEVOX 두 개는 `tools/voice`가 xcframework를 놓을 때 각 슬라이스의 framework에 매니페스트를 넣고, sqlite3는 Runner의 셸 단계에서 서명 전에 넣습니다.
  다른 길: sqlite3를 iOS 시스템 SQLite로 바꾸기(pubspec `hooks: user_defines: sqlite3: source: system`) — 저장 계층 동작이 바뀌므로 따로 검토합니다.
- 새 Pod·플러그인을 넣으면 `check_build.py ios`가 매니페스트 없는 framework를 알려 줍니다. `nm -u <바이너리> | grep -E '_(stat|fstat|lstat|statfs|statvfs|getattrlist|mach_absolute_time)'`
  등으로 확인한 뒤 앱 매니페스트와 `tools/release/check_build.py`의 `WITHOUT_MANIFEST`를 함께 고칩니다.
- `integration_test.framework`는 테스트용 플러그인인데 CocoaPods가 모든 구성에 넣어 release 앱에도 들어갑니다. 필수 이유 API·네트워크를 쓰지 않아 그대로 둡니다(빼려면 Podfile에서 release 구성 제외 — 다음 단계 후보).

## 7. 개인정보처리방침·지원 페이지

### 7.1 내용
- 앱 안: 정보 → 개인정보 → 「개인정보처리방침」(전문). 앱은 브라우저를 열지 않으므로 전문을 앱에 싣습니다.
  웹 주소(`privacyPolicyUrl`)와 문의처(`privacyContact`)는 `app/lib/features/about/privacy_policy.dart`의 상수이고, **비어 있으면 화면에 보이지 않습니다.**
- 웹: `site/privacy.html`(한국어, 원문)·`site/privacy-en.html`(영어)·`site/support.html`(지원)·`site/index.html`.
  한국어 웹 방침은 앱의 방침과 같은 문장이어야 합니다 — `app/test/features/about_privacy_test.dart`가 앱 문장이 웹 페이지에 모두 있는지 확인합니다.
  방침을 고칠 때는 앱 상수, `site/privacy.html`, `site/privacy-en.html`, 시행일을 함께 고칩니다.
- 문의 이메일은 아직 정하지 않았습니다. 웹 페이지에는 `{{CONTACT_EMAIL}}` 자리가 있고, `check_build.py site --publish`는 이 자리가 남아 있으면 실패합니다.

### 7.2 예상 주소 (게시 전)
- 개인정보처리방침: `https://<저장소 소유자 계정>.github.io/shiori/privacy.html` (영어 `…/privacy-en.html`)
- 지원: `https://<저장소 소유자 계정>.github.io/shiori/support.html`. 지금은 문의 메일만 안내합니다. 저장소 Issues로 받으려면 게시 때 Issues가 켜져 있는지 보고 `site/support.html`에 링크를 더합니다.
- 저장소 소유자 계정 이름은 저장소 파일에 적지 않습니다(공개 저장소 위생 검사). 게시할 때 실제 주소를 App Store Connect와 앱 상수에 넣습니다.

### 7.3 게시 방법 (출시 직전, 확인 뒤)
저장소가 공개라 GitHub Pages를 바로 쓸 수 있습니다. `docs/` 폴더(개발 문서)가 함께 공개되지 않게 **`site/` 폴더만** 올립니다.
권하는 방법은 Actions로 `site/`만 배포하는 것입니다:

1. 저장소 Settings → Pages → Source: **GitHub Actions**.
2. `.github/workflows/pages.yml`:
   ```yaml
   name: pages
   on:
     push:
       branches: [main]
       paths: ['site/**']
     workflow_dispatch:
   permissions:
     contents: read
     pages: write
     id-token: write
   concurrency: { group: pages, cancel-in-progress: true }
   jobs:
     deploy:
       runs-on: ubuntu-latest
       environment: { name: github-pages, url: '${{ steps.deployment.outputs.page_url }}' }
       steps:
         - uses: actions/checkout@v4
         - run: python3 tools/release/check_build.py site --publish
         - uses: actions/upload-pages-artifact@v3
           with: { path: site }
         - id: deployment
           uses: actions/deploy-pages@v4
   ```
3. 게시 확인 뒤 앱의 `privacyPolicyUrl`을 채우고, App Store Connect에 7.2절 주소를 넣습니다.

다른 방법: Settings → Pages → 「Deploy from a branch」는 루트나 `/docs`만 고를 수 있어 `site/`를 쓰려면 별도 브랜치(`gh-pages`)에 `site/` 내용만 올려야 합니다. 워크플로가 더 단순하고 실수가 적습니다.

## 8. Google Play (iOS 다음)

| 항목 | 상태 |
|---|---|
| 대상 API | `targetSdk = flutter.targetSdkVersion` = **36**(Flutter 3.41.5), `compileSdk` 36, `minSdk` 24. Play는 2026-08-31부터 새 앱·업데이트에 API 36 이상(11-01까지 연장 신청 가능) |
| 64비트 | Flutter arm64·armv7·x86_64, 발음 엔진은 arm64-v8a만(armv7 기기는 발음 없이 동작) |
| 서명 막음 | `android/key.properties`가 없으면 `flutter build appbundle --flavor prod --release`가 `preProdReleaseBuild`에서 「Release signing: android/key.properties is missing. A release is never signed with the debug key. …」로 멈춤 |
| 크기(추정) | arm64 기기 내려받기 약 150~170MB: 목소리 약 99MB(압축 안 됨) + 사전 19MB + 악센트 1MB + ML Kit 모델 3MB + 네이티브 라이브러리. Play 기본 모듈 압축 한도 200MB 안 |
| 홈 화면 이름 | prod 「시오리」, dev 「시오리 dev」 |

### 8.1 업로드 키 (키는 Play 등록 때 만듭니다)
```bash
keytool -genkeypair -v -keystore <저장소 밖 경로>/shiori-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp app/android/key.properties.example app/android/key.properties   # git 제외, 네 값 채움
cd app && flutter build appbundle --flavor prod --release
```
- Play Console에서 **Play 앱 서명**을 씁니다(배포 키는 Google이 보관, 우리가 가진 것은 업로드 키). 업로드 키를 잃으면 Play Console에서 재설정을 요청할 수 있습니다.
- keystore와 비밀번호는 저장소 밖(비밀번호 관리자 등)에 둡니다.

### 8.2 ML Kit의 네트워크 권한 — Play 제출 전에 정할 것
- Android 글자 판독(ML Kit 번들 모델)이 `com.google.android.datatransport`를 끌고 와, 병합된 매니페스트에 **INTERNET·ACCESS_NETWORK_STATE** 권한이 들어갑니다.
  ML Kit 문서(2025-05-14 갱신)상 기기 정보·앱 정보·기기 식별자·성능 지표·이벤트를 진단·사용 통계 목적으로 Google에 보냅니다. iOS(Apple Vision)에는 해당 없습니다.
- 권고 (a): 메인 매니페스트에서 두 권한을 빼 전송을 막습니다(앱 설명 「인터넷을 쓰지 않음」과 일치, Data safety 「수집 없음」).
  ```xml
  <manifest xmlns:tools="http://schemas.android.com/tools" …>
      <uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>
      <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove"/>
  ```
  (debug·profile 매니페스트의 INTERNET은 Flutter 도구 연결용이라 그대로 둡니다. 빼면 판독이 그대로 되는지 기기에서 확인.)
- (b): 권한을 두고 Data safety에 「앱 정보 및 성능(진단)」 수집·Google 처리로 신고합니다.
- 결정: 출시 직전. 앱 안 방침과 `site/privacy*.html`은 지금 (a)를 전제로 「인터넷에 연결하지 않음」이라고 적습니다. (b)를 고르면 방침(앱·웹)과 Data safety를 함께 바꿉니다.
- 검사: release APK(`flutter build apk --flavor prod --release`)에 `python3 tools/release/check_build.py apk <apk> --flavor prod --release`를 돌리면 두 권한이 남아 있을 때 실패합니다.

### 8.3 Data safety 답 초안 ((a)를 고른 경우)
- 데이터 수집: 없음 / 데이터 공유: 없음 / 전송 중 암호화: 해당 없음(전송 없음) / 데이터 삭제 요청: 해당 없음(앱 삭제로 기기 데이터 삭제).
- 기기 백업: `android:allowBackup="false"` — Android 기기 백업에는 들어가지 않습니다(앱 안 백업·복원 기능 사용).

## 9. 출시 직전 검사

```bash
python3 tools/dict/asset_check.py --release --engine ios           # 사전·발음 asset 판, JMdict 35일
cd app && flutter analyze && flutter test
flutter build ios --flavor prod --release --no-codesign && python3 ../tools/release/check_build.py ios build/ios/iphoneos/Runner.app --flavor prod
python3 ../tools/release/check_build.py site --publish
```
