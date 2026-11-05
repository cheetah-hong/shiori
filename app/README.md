# shiori

시오리: 교재 사진으로 만드는 일본어 단어장 (Flutter, iOS·Android)

```bash
flutter test                 # 위젯·흐름 테스트 (합성 샘플 페이지 사용)
flutter run                  # 디버그 실행: 등록 화면의 "샘플 페이지로 해 보기"로 카메라 없이 흐름 확인
flutter build apk --debug    # Android 디버그 빌드
```

- 블록 지도: `lib/app/blocks.dart`. 구조는 [../docs/architecture.md](../docs/architecture.md).
- `assets/dev_samples/`는 합성 페이지의 판독 기록입니다(`tools/synthetic/make_pages.py`가 생성). 개발용이라
  배포 빌드(`--release`)는 일부러 실패합니다(architecture.md 5절).
- 시뮬레이터 흐름 스크린샷: `flutter drive -d <시뮬레이터> --driver=test_driver/integration_test.dart --target=integration_test/flow_screenshots_test.dart`
  → `../docs/screenshots/`
