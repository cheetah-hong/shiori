# 시오리 (가칭)

교재 사진을 찍으면 단어장이 되는 일본어 단어 학습 앱. 첫 버전은 JLPT 단어장(N5–N3)에 흔한 두 가지 쪽 형식(단어 목록형, 예문이 있는 항목형)을 지원합니다.

- `packages/core/` 순수 Dart: 모델, 포트, 캡처 파이프라인, 학습 로직
- `packages/dict_jmdict/` 사전 블록(JMdict, SQLite)
- `app/` Flutter (iOS·Android): 화면, 기기 어댑터, 블록 지도(`app/lib/app/blocks.dart`)
- `research/` OCR·스캔 실험 기록, `tools/` 기준 구현·합성 페이지·사전 빌드 도구
- 구조: [docs/architecture.md](docs/architecture.md) · 검증: [docs/verification.md](docs/verification.md) · 사전: [docs/dictionary.md](docs/dictionary.md)

```bash
cd packages/core && dart test && dart run tool/eval_capture.dart   # 합성 세트 점수표
cd app && flutter test && flutter run                               # 합성 샘플 페이지로 흐름 확인
```

## 테스트 데이터

저장소의 테스트와 앱의 샘플 페이지는 **합성 페이지**를 씁니다. 단어·뜻·예문·번역은 모두 지어낸 것이고,
교재와 같은 배치에 OCR이 흔히 내는 실수를 일부러 넣었습니다(`tools/synthetic/make_pages.py`).

실제 교재 페이지의 판독 기록과 정답은 교재 본문이라 저장소에 넣지 않습니다. 로컬에 `$SHIORI_PRIVATE_DIR/textbook/`
(기본 `<저장소>/.private/textbook/`)이 있으면 실제 교재 회귀 테스트와 기준 구현 대조 테스트도 돌고, 없으면 건너뜁니다.
