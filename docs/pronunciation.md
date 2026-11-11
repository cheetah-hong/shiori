# 발음: 기기 안 VOICEVOX와 음 높이 선

학습 카드에서 단어와 예문을 일본어 소리로 들려주고, 읽기 아래에 음 높이 선(도쿄 악센트)을 그립니다.
소리는 기기 안에서 만듭니다. 앱은 네트워크를 쓰지 않습니다(`app/test/app/no_network_test.dart`).
방식을 고른 측정은 `research/tts/README.md`(엔진·데이터 정확도)와 `docs/verification.md` 28절(앱에 넣은 결과)에 있습니다.
목소리를 고른 조사는 `research/tts/voices/README.md`, 바꾼 결과는 `docs/verification.md` 32절입니다.

## 1. 무엇이 들어 있나

| 구성 | 판 | 어디 | 라이선스·표기 |
|---|---|---|---|
| VOICEVOX core (C API) | 0.17.1 | iOS `app/ios/voicevox/voicevox_core.xcframework`, Android `jniLibs/arm64-v8a/libvoicevox_core.so` | MIT |
| VOICEVOX ONNX Runtime | iOS 1.17.3(core가 링크하는 판), Android 1.23.2(16KB 페이지 정렬) | 같은 폴더 | VOICEVOX ONNX Runtime 이용규약: 앱에 넣어 재배포 가능, 역컴파일 금지, VOICEVOX 크레딧 |
| 음성 모델 `n0.vvm` (VOICEVOX Nemo) | voicevox_vvm 0.17.1 | `app/assets/voice/n0.vvm.gz` | VOICEVOX 음성 모델 이용규약 + VOICEVOX Nemo 이용규약(https://voicevox.hiroshiba.jp/nemo/term/). 쓰는 음성은 캐릭터 없는 읽기용 女声4 ノーマル(스타일 10003) 하나, 크레딧 「VOICEVOX Nemo」. Nemo 규약은 기계학습 이용을 금지합니다 |
| Open JTalk 사전 | 1.11 | `app/assets/voice/open_jtalk_dic.*.gz`(파일 9개) | 수정 BSD |
| 악센트 데이터 Kanjium `accents.txt` | 원본 저장소의 고정 커밋 | `app/assets/accent/kanjium-accents.tsv.gz` | CC BY-SA 4.0, Kanjium이 요구하는 문구를 정보 화면에 표시. 변환한 표도 같은 라이선스 |

- 큰 파일은 git에 넣지 않습니다(각 폴더의 `.gitignore`). 판·크기·sha256이 고정된 공식 릴리스에서 도구가 받아 만듭니다.
- 정보 화면의 「발음」 카드와 오픈소스 라이선스 페이지(`registerVoiceLicenses`)에 위 표기를 모두 싣습니다.
- 앱이 싣는 목소리(판 이름·모델 파일·스타일)는 `tools/dict/speech_check.py`의 `VOICE_*` 한 곳에 고정돼 있습니다. 다른 목소리의 asset이나 판에 없는 gzip(예: 예전 `0.vvm.gz`)이 `app/assets/voice/`에 있으면 asset 검사가 실패합니다. 앱은 이 폴더를 통째로 싣기 때문입니다.
- 예전 목소리는 `0.vvm`의 四国めたん ノーマル(스타일 2)였습니다. 캐릭터 성우처럼 들린다는 평이 있어 2026-11-11에 바꿨습니다.

## 2. 만들기와 검사

```bash
python3 tools/voice/build_voice_asset.py --native   # 음성 모델·사전 asset + 판 정보, --native: iOS xcframework·Android .so
python3 tools/voice/build_accent_asset.py           # Kanjium 악센트 표 asset + 판 정보
python3 tools/dict/asset_check.py --release         # 사전·발음 asset을 판 정보와 대조
```

- 엔진이 든 iOS 빌드는 이 명령(`--native`)으로 엔진을 먼저 만든 뒤 `cd app/ios && pod install`을 해야 합니다(커밋된 `Podfile.lock`이 엔진 pod를 가리키므로, 엔진 없이 빌드하려면 `pod install`을 다시 돌려 lock에서 빼야 함).
- 처음에는 공식 파일 약 110MB를 받습니다. `--cache`(기본 `research/tts/.cache/voice-src`, git 밖)에 두고 다시 받지 않습니다. `--offline`이면 받지 않습니다.
- 받은 파일은 코드에 고정한 크기·sha256과 다르면 쓰지 않습니다. gzip은 mtime 0이라 같은 입력이면 같은 바이트입니다.
- `--native`는 ONNX Runtime xcframework의 `CFBundleIdentifier`에 든 밑줄을 `-`로 바꿉니다(Xcode 26이 밑줄 든 번들 ID를 거부). Android의 `libc++_shared.so`는 Flutter가 쓰는 NDK에서 복사합니다.
- `asset_check.py`(평소·`--release`)가 발음 asset도 검사합니다: 각 gzip 크기, 풀린 크기·sha256, 필수 필드, 경로가 폴더 밖으로 나가지 않는지, gzip 이름이 앱이 받는 모양인지.
  release 빌드는 `--engine android`(Gradle)·`--engine ios`(Xcode)로 그 플랫폼의 엔진 파일까지 있는지 보고, 맞지 않으면 멈춥니다(architecture.md 5.2절).

## 3. 앱 안의 흐름

```
카드 버튼 → Speech.speak(WordSpeech | SentenceSpeech)       core 포트 (packages/core/lib/src/ports/speech.dart)
  └ VoicevoxSpeech (app/lib/adapters/voicevox_speech.dart)
      ├ prepareVoiceAssets: 처음 한 번 asset을 캐시 폴더 voice/로 풀고 판 정보와 대조
      ├ IsolateVoicevoxEngine: 별도 isolate에서 C API(dart:ffi, voicevox_ffi.dart)
      ├ SpeechRenderer (packages/voicevox_block): 요청 → 엔진 입력, 캐시 확인
      └ ChannelAudioPlayback: 플랫폼 채널 shiori/audio로 WAV 재생
```

- **asset 풀기.** gzip을 배경 isolate에서 조각으로 풀며 크기와 sha256을 세고, `.part` 파일을 다 쓴 뒤에만 이름을 붙입니다. 판 정보(마커)는 마지막에 씁니다.
  같은 판이고 파일 크기가 같으면 다시 풀지 않습니다. 맞지 않으면 아무것도 남기지 않고 **엔진을 열지 않으며** 카드가 「발음 데이터가 손상됐어요. 앱을 다시 설치해 주세요」라고 알립니다.
  판 정보의 `path`는 상대 경로만 받습니다(`..`·절대 경로 거부).
- **캐시 폴더를 쓰는 이유.** 풀린 데이터와 만든 소리는 언제든 다시 만들 수 있으므로 iOS 백업에서 빠지는 캐시 폴더(`getApplicationCacheDirectory`)에 둡니다. 사전 asset과 같은 방식입니다.
- **엔진.** 첫 요청에 isolate를 띄워 ONNX Runtime·사전·모델을 엽니다(iOS는 링크된 런타임 `init_once`, Android는 이름으로 `load_once`). 요청은 순서대로 처리합니다.
  isolate가 죽으면 기다리던 요청은 실패하고 다음 요청이 엔진을 다시 엽니다. 엔진을 못 열면 「발음 엔진을 열지 못했어요」.
  여는 도중 실패하면 그때까지 만든 사전·합성기를 해제하고, 다음 요청은 풀린 asset부터 다시 검사합니다(그사이 시스템이 캐시 폴더를 비웠을 수 있음).
- **소리 캐시.** 같은 요청(음성 + 엔진 입력의 sha256)은 다시 합성하지 않습니다. 합계 20MB를 넘으면 가장 오래 안 쓴 파일부터 지웁니다. 망가진 WAV(RIFF·`data` 크기가 길이와 다름)는 지우고 다시 만듭니다.
- **재생.** iOS `AVAudioPlayer`(세션 `.playback`), Android `MediaPlayer`. 재생 중에 다시 누르면 멈추고 처음부터.
  요청마다 세대 번호를 매겨, 늦게 만들어진 옛 소리는 더 새 요청(또는 정지) 뒤에 재생하지 않습니다. 카드가 넘어가면 소리를 멈춥니다.
  같은 소리를 동시에 두 번 요청하면 한 번만 만듭니다. 악센트 표가 아직 읽히는 중에 누르면 표를 기다린 뒤 요청합니다. 채널은 앱 캐시 폴더 안의 실제 파일만 재생합니다(경로를 정규화해 비교).

## 4. 요청을 엔진 입력으로 (`packages/voicevox_block`)

| 요청 | 엔진 입력 | 화면 |
|---|---|---|
| 단어, Kanjium에 값 있음 | 읽기를 발음 가나로 바꾸고(おう→オオ, えい→エエ, ー→앞 모음, 동사 끝 う는 그대로) 첫 악센트 값을 표시한 VOICEVOX 가나(`ハ'シ`) | 음 높이 선 |
| 단어, 값 없음 | 엔진이 표기를 읽은 소리가 읽기와 같으면 그대로, 다르면 읽기(히라가나)를 읽힘 | 「추정」, 엔진 추정 선(아래) |
| 예문 | 예문 텍스트를 엔진이 읽되, 카드 단어가 Kanjium 값이 있고 예문에 더 긴 한자·가타카나 말의 일부가 아닌 채로 나오면 그 단어로 시작하는 악센트구의 악센트를 값대로 고치고 높낮이를 다시 만듦 | 예문 옆 버튼, 합성 중 「불러오는 중」 |

- 악센트 값: n = n번째 박 뒤에서 내려감, 0 = 평판. VOICEVOX는 평판을 「구의 박 수」로 적으므로 예문에서 평판 단어는 그 구의 박 수로 바꿉니다.
- 한 단어만 소리 낼 때 평판(0)과 끝 박 뒤 하강(박 수와 같은 값)은 소리가 같습니다(조사가 있어야 갈림). 그래서 엔진 입력도 같습니다.
- **추정 선.** Kanjium에 없는 단어는 읽기를 열 때 한 번 엔진에 「표기+が」를 읽혀(안 맞으면 「읽기+が」) 한 구로 읽힌 경우의 악센트를 선으로 그리고 「추정」을 붙입니다. 엔진을 쓸 수 없으면 「추정」만 보입니다.
- 읽기가 여러 개면 Kanjium에 값이 있는 첫 읽기를 씁니다. 값이 여러 개면 첫 값을 씁니다.
- **빠르기.** 모든 소리를 엔진 기본값(1.0, `speechSpeedScale`)으로 냅니다. 보통 말 빠르기로, 다른 학습 앱의 녹음과 초당 박 수가 거의 같습니다(단어 1.01배·예문 1.02배, 소리 크기 봉우리로 어림). 예전 목소리는 처음 듣는 단어에 빠르게 들려 0.85배였지만, 지금 목소리는 더 차분해 1.0배로 골랐습니다.
- **캐시.** 소리 캐시 이름에 판·스타일·빠르기가 들어갑니다(`speechVoiceId`). 셋 중 하나만 바뀌어도 예전 소리를 다시 쓰지 않습니다. 발음 asset을 풀어 두는 폴더는 판이 바뀌면 새 판에 없는 파일(예전 모델)을 지우고 다시 풉니다.

## 5. 플랫폼

- **iOS 최소 배포 대상 16.2.** 공식 VOICEVOX core xcframework의 `MinimumOSVersion`이 16.2라서 앱도 16.0 → 16.2로 올렸습니다. `Podfile`은 xcframework 두 개가 있을 때만 로컬 pod(`ios/voicevox/VoicevoxCore.podspec`)를 넣습니다. 없으면 엔진 없이 빌드되고 버튼은 실패를 알립니다.
  엔진 파일을 넣거나 뺀 뒤에는 `pod install`을 다시 돌려야 합니다(`Podfile.lock`이 달라짐).
- **Android는 arm64-v8a만.** 공식 라이브러리가 arm64·x86_64만 있고 지금은 arm64만 넣습니다. 다른 ABI 기기에서는 엔진을 열지 못해 버튼이 「발음 엔진을 열지 못했어요」를 알립니다.
- 오디오 포커스: iOS는 재생하는 동안 다른 앱 소리를 멈추고 끝나면 돌려줍니다. Android는 포커스를 요청하지 않습니다(다른 앱 소리와 섞임).

## 6. 크기

| 무엇 | 크기 |
|---|---|
| 음성 모델 gzip / 풀린 크기 | 75.2MB / 75.2MB (압축되지 않음, 예전 `0.vvm`보다 +15.9MB) |
| Open JTalk 사전 gzip 9개 / 풀린 크기 | 23.5MB / 약 107MB |
| Kanjium 표 gzip / 풀린 크기 | 0.94MB / 3.2MB (124,137줄) |
| 엔진 (release, 앱 크기 증가) | iOS zip +5.6MB, APK(arm64) +23MB |

기기에는 앱 안의 gzip asset과 캐시 폴더의 풀린 파일이 둘 다 있습니다(약 280MB). 측정은 verification.md 28절.

## 7. 남은 일

- 귀로 확인하지 않았습니다. 엔진이 지정한 악센트로 말하는 것은 기계 측정으로 확인했습니다(research/tts).
- 실제 기기의 합성 속도·App Store 검증은 시뮬레이터·에뮬레이터 밖이라 확인하지 않았습니다.
- iOS에서 asset을 앱 묶음에서 바로 열면 풀린 사본(약 180MB)이 필요 없습니다(다음 단계).
