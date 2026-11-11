# 일본어 목소리 후보 조사 — 아나운서처럼 차분한 목소리

- 날짜: 2026-11-07 (KST), MacBook arm64 · Python 3.11(엔진), 3.9(순수 도구)
- 질문: 지금 앱 목소리(VOICEVOX 四国めたん ノーマル)는 캐릭터 성우처럼 들린다. 기기 안에서 돌릴 수 있고, 표준적이고 차분한(아나운서 같은) 목소리가 있는가.
- 범위: 조사와 견본까지. 앱 코드와 asset 판은 바꾸지 않았다. 소리 고르기는 사람이 귀로 한다. 이 문서의 수치는 그 판단을 돕는 기계 측정이다.
- 소리 파일·모델·결과 JSON은 저장소에 없다. `.cache/`(git 제외)와 비공개 폴더 `$SHIORI_PRIVATE_DIR/tts/voices/`(기본 `<repo>/.private/tts/voices/`)에 있다. 듣기 페이지는 그 폴더의 `index.html`이다.

> **결정(2026-11-11):** Nemo 女声4 ノーマル(10003)을 1.0배로 앱에 넣었다. 적용 결과와 재측정은 `docs/verification.md` 32절.
> 아래 견본은 조사 당시 앱 빠르기(0.85배)로 만들었다.

## 0. 요약

1. **VOICEVOX 0.17.1에 캐릭터 없는 낭독용 음성 「VOICEVOX Nemo」(`n0.vvm`, 女声 6·男声 3)가 있다.** 공식 소개는 캐릭터 없는 읽기 소프트웨어이고, 발표부터 영상 내레이션까지 여러 자리에 쓰는 것을 내세운다.
   지금 엔진·FFI·악센트 지정 방식을 그대로 쓰고 vvm 파일과 스타일 id만 바뀐다. 크기는 +15.9MB(75.2MB ↔ 59.3MB).
2. **Nemo 9명 중 악센트 대비가 분명한 것은 女声4·女声5·男声1~3이다.** 女声2·女声3은 첫 박이 낮아지지 않아 평판형과 두고형이 거의 같은 모양으로 시작한다(최소쌍 대비 3/8, 2/8). 학습 앱에는 부적합.
3. **이름이 「アナウンス」인 스타일은 No.7 하나**(6.vvm). 소리 대비 8/8이지만 약관상 상용(유료·광고)은 유료 라이선스·사전 확인이 필요하다.
4. **VOICEVOX 밖의 기기 안 엔진은 악센트 지정·라이선스·크기를 함께 만족하는 것이 없었다.**
   - Open JTalk HTS(tohoku-f01·mei): 지정 가능, CC BY, 아주 작다(음성 2MB). 옛 HMM 방식 소리.
   - Supertonic 3: 공식 설명에 announcer-style 음성(F3)이 있지만 악센트 지정이 안 되고 모델이 OpenRAIL-M(사용 제한 승계).
   - Kokoro: 지정 불가. 箸·橋·端을 바이트까지 같은 소리로 냈다.
   - piper-plus: 지정 가능·MIT지만 공개 일본어 음성이 오디오북 1개(단어 단독 불안정)와 캐릭터 1개뿐.
5. **추천(귀로 고르기 전 기준):** Nemo 女声4, Nemo 男声3(또는 女声5), 冥鳴ひまり ノーマル. 근거는 4절.

## 1. 견본 만드는 법

- 같은 글: `samples.tsv` — 단어 8개(箸·橋·端·雨·飴 최소쌍, 今日·先生·図書館)와 문장 3개(앞 실험 `../sentences.tsv`에서).
- 빠르기: 앱과 같은 0.85배. VOICEVOX는 `speedScale`, HTS는 `set_speed`, piper-plus는 `length_scale = 1/0.85`, Kokoro·Supertonic은 `speed`.
- 단어: 앱과 같이 단독으로, 읽기와 악센트를 지정한다(VOICEVOX 가나 쿼리 `ハ'シ`, HTS·piper-plus는 Open JTalk 라벨의 `acc`를 바꿔서). 지정 못 하는 엔진은 표기 그대로.
- 문장: 글 그대로 넣는다. 이 3문장은 앞 실험에서 VOICEVOX 기본 추정이 기대와 모두 같았다.
- VOICEVOX 토크 스타일 137개 전부에 문장 하나(先生は図書館にいます。)를 만들어 듣기 페이지 3절에 넣었다. 후보 25개는 11개 항목 전부.

## 2. 악센트 측정

- **VOICEVOX 쿼리 기준**(`make_vv_samples.py`의 `accent_check`): 앞 실험(`../README.md` 2.3절)과 같은 28단어+が를 가나로 지정했다.
  엔진 악센트 값의 일치, 모라 pitch의 최소쌍 대비 검사 8개, 모라 판독(교과서식 H/L)을 센다.
  가나 지정이라 엔진 악센트 값은 어느 스타일이든 28/28이다. 스타일 사이 차이는 대비 검사에서 드러난다.
- **소리 기준**(`../tools/measure_wavs.py`, 모든 엔진 공통): 28단어+が WAV를 유성 구간으로 똑같이 나눠 F0를 읽는 대략 규칙. 끝 박 하강 때문에 「끝 박 제외」도 함께 적는다.
  엔진마다 모라 길이가 달라 정밀하지 않다. 순위를 보는 용도로만 쓴다.
- 대비 검사: (a) 두고형 단어는 같은 읽기의 다른 형보다 첫 박과 최고점의 차이가 작다, (b) 평판 端が는 미고 橋が보다 조사 박이 더 올라간다.

## 3. 후보 표

전체 36행은 `candidates.tsv`. ①소리는 듣기 페이지에서 고른다. ④는 지금 앱(vvm 59.3MB + Open JTalk 사전 102MB + 런타임) 대비 MB.

### 3.1 VOICEVOX 0.17.1 (지금 엔진 그대로, 스타일 id·vvm만 바꿈)

| 후보 | vvm | 평균 Hz · 퍼짐(반음) · 모라/초 | ② 쿼리 대비 / 소리 판독(끝 박 제외)·대비 | ③ 약관 | ④ |
|---|---|---|---|---|---|
| 四国めたん ノーマル (2, 지금) | 0 | 315 · 3.28 · 7.8 | 8/8 / 11(14)·8/8 | 크레딧만 | 0 |
| Nemo 女声4 (10003) | n0 | 202 · 4.19 · 6.7 | 8/8 / 18(21)·8/8 | 크레딧 「VOICEVOX Nemo」만, 기계학습 이용 금지 | +15.9 |
| Nemo 女声5 (10008) | n0 | 234 · 3.74 · 7.5 | 8/8 / 15(20)·8/8 | 같음 | +15.9 |
| Nemo 男声3 (10002) | n0 | 132 · 3.84 · 8.6 | 8/8 / 14(19)·8/8 | 같음 | +15.9 |
| Nemo 男声2 (10000) | n0 | 125 · 4.31 · 8.0 | 8/8 / 13(18)·7/8 | 같음 | +15.9 |
| Nemo 男声1 (10001) | n0 | 154 · 3.69 · 10.2 | 8/8 / – | 같음 | +15.9 |
| Nemo 女声1·6 (10005·10006) | n0 | 240·248 · 2.98·2.36 | 7/8 / – | 같음 | +15.9 |
| Nemo 女声2·3 (10007·10004) | n0 | 255·261 · 2.20·3.06 | **3/8 · 2/8** / – | 같음 | +15.9 |
| No.7 アナウンス (30) | 6 | 233 · 4.66 · 8.4 | 8/8 / 17(21)·8/8 | **상용은 유료 라이선스·사전 확인**(비상용은 크레딧만) | 0 |
| No.7 読み聞かせ (31) | 6 | 242 · 3.48 · 5.9 | 8/8 / – | 같음 | 0 |
| 冥鳴ひまり ノーマル (14) | 1 | 255 · 2.32 · 8.0 | 8/8 / 15(18)·8/8 | 크레딧만, 개인·법인 신청 불필요 | +1.3 |
| 東北イタコ ノーマル (109) | 21 | 245 · 3.55 · 6.7 | 8/8 / 14(18)·5/8 | 크레딧만(zunko.jp 규약) | +3.9 |
| 九州そら ノーマル (16) | 2 | 259 · 3.25 · 5.7 | 8/8 / – | 크레딧만(zunko.jp 규약) | 0 |
| 猫使アル おちつき (56) | 13 | 240 · 3.16 · 8.1 | 8/8 / – | 개인은 크레딧만, 법인 상용은 사전 문의 | +2.4 |
| 青山龍星 しっとり (84) | 15 | 85 · 1.41 · 7.4 | 6/8 / – | 개인은 크레딧만, 기업·개인사업자는 사전 신청 | +8.0 |
| 離途 シリアス (101) | 19 | 95 · 2.11 · 7.0 | 4/8 / – | 음성은 크레딧만 | +0.7 |

- 그 밖에 東北ずん子·春日部つむぎ·玄野武宏·栗田まろん·小夜/SAYO·離途 ノーマル·青山龍星 ノーマル은 `candidates.tsv`에 있다.
- 「평균 Hz · 퍼짐 · 모라/초」는 문장 하나(先生は図書館にいます。)에 대한 엔진 쿼리 값(빠르기 1.0)이다. 퍼짐이 작을수록 높낮이가 평평하다. 아나운서다움을 재는 값은 아니다.
- 雨晴はう(0.vvm, 10)는 vvm 동봉 약관에 항목이 없다. 캐릭터 사이트(amehau.com)는 VOICEVOX 표기 필수, 캐릭터명 표기 권장, R-18 이용 자제를 요청한다.

### 3.2 VOICEVOX 밖의 기기 안 엔진

| 후보 | ③ 라이선스 (코드 / 모델·데이터) | ② 악센트 지정 · 소리 판독(끝 박 제외)·대비 | ④ 크기 | ⑤ iOS·Android | ⑥ 바꾸는 일 | 판정 |
|---|---|---|---|---|---|---|
| Open JTalk HTS tohoku-f01 neutral | HTS·Open JTalk 수정 BSD / CC BY 4.0 | 가능(라벨 `acc`) · 7(13)·8/8 | 음성 2.2MB | C 라이브러리, 실기기 사례 많음 | 작음~중간: HTS 엔진 추가, 사전은 그대로 | 가능 |
| Open JTalk HTS mei normal | 같음 / CC BY 3.0 | 가능 · 11(18)·7/8 | 음성 0.86MB | 같음 | 같음 | 가능 |
| Supertonic 3 F3·F1·M2 (sherpa-onnx int8) | MIT / OpenRAIL-M(사용 제한 조항 승계, 기계 생성 고지) | **불가**(한자 그대로) · F3 16(18)·3/8 | 모델 144MB + sherpa-onnx 런타임 | sherpa-onnx에 Flutter 바인딩 | 중간: 런타임 하나 더, 앱의 음 높이 선과 소리가 어긋날 수 있음 | 조건부 |
| piper-plus CSS10 일본어 | MIT / CSS10 CC0, 베이스 학습 데이터 MOE-Speech(일본 저작권법 30조의4 범위) | 가능(A1/A2/A3) · 6(7)·1/8 | 39.7MB | iOS·Android·Dart FFI 예제 | 중간: 라벨에서 A1~A3 뽑기 | 조건부(단어 단독 불안정) |
| piper-plus つくよみちゃん | MIT / 코퍼스 규약: 상용 가능, 크레딧·금지사항을 앱 안에 게시 | 가능 · 11(14)·7/8 | 40MB | 같음 | 같음 | 조건부(캐릭터 음성) |
| Kokoro-82M v1.0 (jf_alpha 등) | Apache-2.0 / Apache-2.0 | **불가** · 9(14)·0/8(최소쌍 8쌍 모두 같은 소리) | int8 92MB + G2P | ONNX, 일본어 G2P는 파이썬 의존 | 중간~큼 | 조건부(악센트 불가) |
| Piper `ja_JP-hi_fi_captain` | GPL-3.0 / **CC BY-NC-SA 4.0** | 가능 | 77MB | ONNX | 중간 | **앱 불가**(비상업) |
| Style-Bert-VITS2 / AivisSpeech | AGPL-3.0·LGPL-3.0 / 모델마다(ACML 등), BERT CC BY-SA 4.0 | 가능 | BERT 0.65~1.3GB + 모델 약 250MB | 모바일 사례 확인 못 함 | 큼 | 사실상 불가 |
| MeloTTS 일본어 | MIT / 확인 못 함 | 불가(톤을 모두 0으로 둠) | 208MB + BERT 447MB | 공식 ONNX 없음 | 큼 | 불가에 가까움 |
| ESPnet JSUT/JVS VITS | 모델 카드 CC BY 4.0 / JSUT·JVS 상업 이용은 별도 허락 | 가능 | 수백 MB | 변환은 되나 사례 확인 못 함 | 중간~큼 | 조건부(상업은 허락) |
| macOS·iOS Kyoko | 시스템 음성 | 불가(앞 실험 12/28) | – | – | – | 참고만 |

- Supertonic F3의 공식 설명: "Clear, professional announcer-style female voice; articulate and broadcast-ready."
- sherpa-onnx가 공식 지원하는 일본어 TTS는 Supertonic 3 하나였다(조사일 기준).
- COEIROINK는 공개 엔진 저장소를 찾지 못했고, SHAREVOX는 2023년 이후 멈췄다.
- 클라우드 TTS는 앱 원칙(네트워크 없음) 때문에 후보에서 뺐다(지정 문법은 `../README.md` 6.4절).

## 4. 추천 (귀로 듣기 전, 확신 중간)

| 순위 | 후보 | 이유 |
|---|---|---|
| 1 | **Nemo 女声4** (10003) | 캐릭터 없는 낭독용. 악센트 대비 쿼리 8/8, 소리 판독 18/28(측정한 것 중 가장 높음). 크레딧만. 평균 202Hz로 지금보다 낮고 차분한 쪽. +15.9MB |
| 2 | **Nemo 男声3** (10002), 대안 女声5 (10008) | 같은 Nemo라 바꾸는 일이 같다. 둘 다 대비 8/8. 남성·여성 중 고르기 |
| 3 | **冥鳴ひまり ノーマル** (14) | 캐릭터 음성이지만 높낮이 퍼짐이 작다(2.32반음). 대비 8/8, 크레딧만, +1.3MB |

- No.7 アナウンス는 소리 수치가 좋지만 상용 조건 때문에 앱이 무료·광고 없이 남는 경우에만 고려한다.
- VOICEVOX 밖으로 나갈 이유는 지금 찾지 못했다. HTS는 작고 자유롭지만 옛 방식 소리이고, Supertonic은 악센트를 지정할 수 없어 학습 앱의 핵심(악센트 정확성)을 잃는다.

### 4.1 바꿀 때 구현 범위 (VOICEVOX 안에서 고르는 경우)
- `tools/voice/build_voice_asset.py`: `MODEL_FILE`, `SOURCES["vvm"]`(URL·크기·sha256), `STYLE_ID`, `CREDIT`, `VARIANT`. 약관 파일은 같은 릴리스의 `TERMS.txt`(이미 고정됨).
- 앱 정보 화면의 크레딧 문구(Nemo는 「VOICEVOX Nemo」).
- 앱은 스타일 id를 asset 판 파일에서 읽고, 소리 캐시 키에 판과 스타일이 들어 있어 옛 소리가 섞이지 않는다.
- 엔진·FFI·악센트 지정·빠르기 코드는 그대로. 확인할 것: 바꾼 스타일로 앞 실험 28단어·7문장 재측정, 실기기 합성 속도.
- Nemo의 `n0.vvm`은 이 Mac의 core 0.17.1·ONNX Runtime으로 그대로 열렸다(137 스타일 모두 합성됨).

## 5. 도구

| 파일 | 내용 |
|---|---|
| `samples.tsv` | 견본 글 11개(단어 8·문장 3) |
| `candidates.tsv` | 후보 36행: 엔진, 음성, 스타일 id, 모델, 앱 판정, 라이선스, 크기 증감, 악센트 측정, 메모, 추림 표시 |
| `voices.py` | 두 표 읽기·검사, 견본 파일 이름 규칙, 음높이 수치, HTML 조각 (순수 함수) |
| `test_voices.py` | 위 단위 테스트 |
| `make_vv_samples.py` | VOICEVOX 견본: 전 토크 스타일 한 문장 + 수치, `--full` 스타일은 전 항목과 28단어 악센트 검사 |
| `make_page.py` | 듣기 페이지 `index.html` |
| `remeasure.py` | 바꾼 목소리로 앞 실험의 28단어(가나 지정)·7문장(기본·사용자 사전) 다시 재기 |

- VOICEVOX 밖 엔진의 견본과 28단어+が 소리는 각 엔진의 파이썬 패키지로 만든 일회용 스크립트로 만들었다. 저장소에는 넣지 않았다(설치 경로에 묶여 있다).

실행(`research/tts/voices`에서):
```bash
python3 -m unittest test_voices -v
# vvm: gh release download 0.17.1 -R VOICEVOX/voicevox_vvm -D .cache/vvm (README.txt의 약관 확인, sha256은 릴리스 자산 digest와 대조)
<venv>/bin/python make_vv_samples.py --core <voicevox_core 폴더> --vvm-dir .cache/vvm \
    --out "${SHIORI_PRIVATE_DIR:-../../../.private}/tts/voices" --stats .cache/results/screen.json \
    --full 2 10003 10008 10002 10000 10001 10005 10004 10006 10007 30 31 14 16 109 107 8 11 67 46 56 13 84 99 101
python3 make_page.py --stats .cache/results/screen.json --out "${SHIORI_PRIVATE_DIR:-../../../.private}/tts/voices"
```
- `<venv>`·`<voicevox_core 폴더>`는 앞 실험(`../README.md` 8절)의 준비물이다.

## 6. 출처

- VOICEVOX vvm 0.17.1 릴리스와 README(스타일 표·약관): https://github.com/VOICEVOX/voicevox_vvm/releases/tag/0.17.1
- VOICEVOX Nemo: https://voicevox.hiroshiba.jp/nemo/ · 약관 https://voicevox.hiroshiba.jp/nemo/term/
- 캐릭터 약관: zunko.jp/con_ongen_kiyaku.html(四国めたん·九州そら·東北 3인), www.meimeihimari.com/terms-of-use(冥鳴ひまり), voiceseven.com/#j0200(No.7),
  www.virvoxproject.com/voicevoxの利用規約(青山龍星·玄野武宏 등), nekotukarb.wixsite.com/nekonohako/利用規約(猫使), litmus9.com/#/voicebank#rules(離途), amehau.com(雨晴はう)
- Open JTalk HTS: https://github.com/icn-lab/htsvoice-tohoku-f01 (COPYRIGHT.txt: CC BY 4.0), mei: MMDAgent 배포본(CC BY 3.0)
- Supertonic 3: https://huggingface.co/Supertone/supertonic-3 · sherpa-onnx 일본어: https://k2-fsa.github.io/sherpa/onnx/tts/all/Japanese/supertonic-3-ja.html
- piper-plus: https://github.com/ayutaz/piper-plus · https://huggingface.co/ayousanz/piper-plus-css10-ja-6lang · https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan
- Kokoro: https://huggingface.co/hexgrad/Kokoro-82M (VOICES.md) · Piper hi_fi_captain: https://huggingface.co/rhasspy/piper-voices
- Style-Bert-VITS2: https://github.com/litagin02/Style-Bert-VITS2 · AivisSpeech Engine: https://github.com/Aivis-Project/AivisSpeech-Engine · MeloTTS: https://github.com/myshell-ai/MeloTTS
- JSUT: https://sites.google.com/site/shinnosuketakamichi/publication/jsut
