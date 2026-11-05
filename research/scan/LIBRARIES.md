# 문서 스캔(ImageSource) 블록 후보 비교

- 조사일: 2026-11-05. pub.dev API, GitHub(코드는 직접 받아서 확인), Google·Apple 공식 문서 기준입니다.
- 확인하지 못한 값은 "확인 못 함"으로 적었습니다. 측정 근거는 `README.md`에 있습니다.
- 이 문서는 웹 조사입니다. 기기에서 직접 돌려 본 것은 아닙니다(7절 남은 문제 참고).

## 1. 비교표

| 후보 | 라이선스 | 최신 버전 / 날짜 | 플랫폼 | Play 서비스 필요 | 출력 | 여러 장 | 필터 끄기 | 갤러리 | 사각형(모서리) 반환 | 원본 반환 |
|---|---|---|---|---|---|---|---|---|---|---|
| iOS `VNDocumentCameraViewController` | Apple SDK | iOS 13+ | iOS·iPadOS | 해당 없음 | `UIImage`(인코딩은 앱이 정함) | 됨, 제한 API 없음 | **불가**(사용자가 UI에서 "Photo"를 고를 때만) | 없음 | 없음 | 없음 |
| `cunning_document_scanner` | MIT | 3.0.4 / 2026-10-21 | Android(minSdk 24), iOS 13+ | 기본 경로는 필요. 없으면 내장 수동 크롭으로 넘어감 | Android JPEG·PDF, iOS PNG(기본)·JPEG(품질 지정) | 됨(`noOfPages`, 기본 100) | Android `base`로 가능. iOS 카메라는 불가. iOS 갤러리는 `original` + 필터바 숨김 | 됨 | 없음 | 없음 |
| `flutter_doc_scanner` | MIT | 0.0.21 / 2026-07-09 | Android(minSdk 21), iOS 13+ | 필요, 대체 경로 없음 | Android JPEG·PDF, iOS PNG 고정 | 됨(iOS는 `page` 무시) | 대부분 불가(Android FULL 고정) | Android만 | 없음 | 없음 |
| ML Kit Document Scanner (Android 네이티브) | Google APIs 약관(오픈소스 아님) | 16.0.0 GA / 2025-09-29 | Android API 21+, RAM 1.7GB 이상 | **필요** | JPEG(기본)·PDF | 됨(`setPageLimit`) | **`SCANNER_MODE_BASE`로 가능**(기본 FULL) | 됨(기본 켜짐) | 없음(`Page.getImageUri()`만) | 없음 |
| `google_mlkit_document_scanner` | MIT | 0.6.1 / 2026-08-17 | Android만 | 필요 | JPEG·PDF | 됨(기본 1장) | `ScannerMode.base` | 됨 | 없음 | 없음 |
| 직접 구현 (iOS Vision + Core Image / Android OpenCV) | OpenCV·`opencv_dart` Apache-2.0 | `opencv_dart` 2.2.2 / 2026-08-16 | 전체 | 불필요 | 자유 | 직접 구현 | 기본이 필터 없음 | 자유 | **됨** | **됨** |

## 2. 후보별 메모

### 2.1 iOS VisionKit `VNDocumentCameraViewController`
- 결과 `VNDocumentCameraScan`은 `pageCount`, `imageOfPage(at:)`, `title`만 줍니다. 모서리, 원본, 필터 정보는 받을 수 없습니다.
  https://developer.apple.com/documentation/visionkit/vndocumentcamerascan
- 필터는 Color / Grayscale / Black & White / Photo 네 가지입니다. 기본값 지정, 필터 읽기, 필터 없는 이미지 받기 모두 공개 API가 없습니다(Apple DTS 답변, 2022-08).
  https://developer.apple.com/forums/thread/712315
- Notes 앱 기준 기본 필터는 Color입니다. VisionKit API의 기본값이 같은지는 확인 못 함입니다.
- 사용자 보고(cunning #174, 2026-09): "자동 필터가 색을 바래게 함", "필터 버튼을 없앨 수 없음", "여러 장 강제".
  https://github.com/vicajilau/cunning_document_scanner/issues/174
- iOS 26 보고(공식 해결 표시 없음): 편집 화면 상단바 깨짐(thread/802992), Liquid Glass에서 촬영 직후 크래시(thread/811188, 2025-12), iPadOS 26 Cancel 버튼 누락.
- 관련 Vision API
  - `VNDetectDocumentSegmentationRequest`(iOS 15+): 문서 네 모서리 + 마스크. **직접 구현의 핵심 부품입니다**(이 실험의 `scan.swift`가 씀).
  - `RecognizeDocumentsRequest`(iOS 26+): 문단·표·목록 구조 추출. 스캔이 아니라 OCR 단계 후보이고, CJK는 단어 단위 결과를 지원하지 않습니다(WWDC25). 시험하지 않았습니다.
  - `DetectLensSmudgeRequest`(iOS 26): 렌즈 얼룩 검출. 촬영 품질 경고에 쓸 수 있습니다.
  - `DataScannerViewController`(iOS 16+): 라이브 텍스트용이라 크롭·원근 보정이 없습니다. 관련성이 낮습니다.

### 2.2 `cunning_document_scanner` (MIT, 3.0.4)
- 저장소 https://github.com/vicajilau/cunning_document_scanner . 1~2주 간격으로 릴리스되고, 열린 이슈는 2개입니다.
- Android: ML Kit 16.0.0, minSdk 24. `androidScannerMode` 기본은 `full`이고, `base`는 "필터 없는 기본 처리"입니다.
  - Play 서비스가 없으면 내장 `DocumentScannerActivity`로 넘어갑니다(자동 모서리 검출 없이 고정 사각형을 손으로 맞춤).
  - Huawei(HMS) 지원은 2.6.0에서 빠졌습니다(#146).
- iOS 카메라: `VNDocumentCameraViewController` 그대로라 필터를 끌 수 없습니다(README에 명시). 페이지 제한이 없어 초과 페이지는 조용히 버려집니다.
- 갤러리
  - iOS: `VNDetectDocumentSegmentationRequest`로 모서리를 찾고, 사용자가 조정한 뒤 `CIPerspectiveCorrection`을 적용합니다.
    `IosScannerOptions(defaultFilter: IosDocumentFilter.original, showFilterBar: false)`로 원본 색을 유지할 수 있습니다.
  - Android: 수동 크롭만 됩니다.
  - **양쪽 모두 긴 변을 2048px로 줄입니다.**
- 모서리와 원본은 돌려주지 않고 파일 경로만 줍니다. 이미 가진 사진을 넘기는 입력 API는 없습니다.
- 열린 이슈: #183(iOS 사진 선택 창을 밀어 닫으면 다음 호출이 `ALREADY_ACTIVE`로 막힘), #174(iOS 원본 색 유지 촬영, 수용 의사만 있고 미구현).

### 2.3 `flutter_doc_scanner` (MIT, 0.0.21) — 비추천
- Android 일반 모드가 `SCANNER_MODE_FULL`로 고정돼 있습니다(정리 필터가 켜짐). 단일 촬영 모드에서만 BASE입니다. Play 서비스가 없으면 오류만 냅니다(#63).
- iOS 네이티브 코드(HEAD `b6b22fe`)는 Dart 쪽 `imageFormat`, `quality`, `page`를 읽지 않습니다. PNG 고정이고, 빠른 단일 촬영은 긴 변 1280px로 줄입니다.
- iOS 갤러리 가져오기는 지원하지 않습니다(#89).

### 2.4 ML Kit Document Scanner (Android 네이티브)
- `com.google.android.gms:play-services-mlkit-document-scanner:16.0.0`(2025-09-29 GA). API 21+, RAM 1.7GB 이상(미달이면 `UNSUPPORTED`).
- UI와 모델은 Play 서비스로 배포되고, 앱에 카메라 권한이 필요 없습니다. `ModuleInstallClient`로 모듈을 미리 받을 수 있습니다.
  https://developers.google.com/ml-kit/vision/doc-scanner/android
- 모드
  - BASE: 촬영, 자동 회전, 크롭·회전, 페이지 정리, JPEG·PDF
  - BASE_WITH_FILTER: + 필터(회색조, 자동 보정)
  - FULL(기본): + ML 정리(얼룩·손가락·그림자 제거)
- **BASE면 컬러가 유지됩니다.** 자동 크롭과 자동 회전은 끌 수 없습니다(#846 Google 답변).
- 결과는 앱 캐시의 JPEG URI뿐입니다. 모서리, 원본, 해상도·품질 설정은 없습니다.
- Play 서비스가 없는 기기(Huawei, 중국 ROM)에서는 실행되지 않습니다. 번들판 요청(#863)은 "우선순위 아님"입니다.
- 알려진 이슈(googlesamples/mlkit): #922 일부 Samsung에서 976×1346 저해상도, #843 결과가 180° 돌아감, #980·#984 `pageLimit` 무시, #1065 Galaxy S25 / Android 16 확인 버튼 없음, #873·#861 기존 이미지 입력 불가.

### 2.5 직접 구현
- **iOS는 OpenCV가 필요 없습니다.** 촬영(AVCapture 또는 Flutter `camera`) → `VNDetectDocumentSegmentationRequest` → 모서리 조정 → `CIPerspectiveCorrection`.
  cunning의 iOS 갤러리 경로가 정확히 이 구성이고, 이 실험의 `scan.swift`도 같습니다. 원본·모서리·해상도를 모두 앱이 갖습니다.
- **Android에는 문서 모서리만 찾는 시스템 API가 없습니다.** ML Kit은 UI 일체형이라 검출만 따로 쓸 수 없습니다.
  - `opencv_dart` 2.2.2(Apache-2.0): Dart 3.10 / Flutter 3.38.1 이상, 빌드 때 OpenCV를 CMake로 빌드합니다. 모듈을 골라 크기를 줄일 수 있습니다.
  - 크기 증가량 공식 수치는 없습니다(직접 재 봐야 함). 참고로 opencv-mobile 4.14.0 zip은 Android 20MB(전 ABI 정적), iOS 4MB입니다.
  - 공수(추정): 카메라 UI, 검출, 모서리 편집, warp, 여러 장 관리까지 수 주.
- 장점: Play 서비스 의존 없음, 원본과 사각형을 저장해 나중에 다시 처리할 수 있음, 펴기 단계를 끼울 수 있음.

### 2.6 그 밖
- `edge_detection` 1.1.3: pub.dev 마지막 배포 2023-10-17(Apache-2.0). 사실상 정체.
- `document_scanner_flutter` 0.4.0(2026-03-01, MIT): 2026-03에 한 번 갱신, 이후 활동 확인 못 함.

## 3. 휜 페이지 펴기 후보

| 이름 | 방식 | 라이선스 | 속도 | 모델 | 모바일 이식 |
|---|---|---|---|---|---|
| mzucker/page_dewarp | 기하: 글줄 → 3차 곡면 + Powell 최적화 | MIT | 장당 5~25초(2012 MacBook Pro) | 없음 | 가능. OpenCV calib3d(`solvePnP`, `projectPoints`)와 최적화기 필요 |
| lmmx/page-dewarp (PyPI) | 위의 Python 3 정비판, JAX 선택 | MIT | JAX CPU 장당 약 0.9초, JAX 없으면 약 11배 느림. 이 실험(0.1.9, JAX 없음): 1.1~4.0초 | 없음 | 위와 같음. 최신 0.3.4(2026-05-12)는 Python 3.10+ |
| UVDoc | CNN이 45×31 격자 회귀(입력 488×712), 원본 해상도에 remap | MIT(가중치 포함) | T4 GPU 19ms, Xeon CPU 870ms(PaddleX) | 약 30MB | 높음. PaddleOCR이 ONNX로 지원 → CoreML/TFLite 변환 경로. 컬러·해상도 보존 |
| DocTr / DocTr++ | Transformer | **비상업 전용** | — | — | 라이선스 때문에 제외 |
| DewarpNet | 3D 형상 + 역방향 맵 | MIT | 확인 못 함 | 확인 못 함 | 오래됨, 우선순위 낮음 |
| ML Kit FULL | "주름 제거" 언급만 있음 | — | — | — | 곡면 펴기라고 명시돼 있지 않고, 정리 필터가 함께 켜짐 |

## 4. 측정과 합친 권고 (README 7절 요약)

1. OCR에는 정리하지 않은 컬러 이미지를 넣어야 합니다(README 4절).
   - iOS VisionKit 카메라는 필터를 끌 수 없습니다.
   - `flutter_doc_scanner`는 Android가 FULL로 고정입니다.
   - 쓸 수 있는 조합은 ML Kit BASE(Android)와 직접 구현(iOS)뿐입니다.
2. **첫 어댑터는 일반 촬영·앨범 사진**(정리하지 않은 컬러 원본)입니다. 지금 해석기는 사진 좌표 기준이고, 측정한 52/59가 이 구성입니다.
3. 두 번째 어댑터(해석기를 내용 기준 단위로 바꾼 뒤)
   - Android: `cunning_document_scanner` + `AndroidScannerMode.base`
   - iOS: 직접 구현(촬영 + `VNDetectDocumentSegmentationRequest` + 모서리 조정 + `CIPerspectiveCorrection`)
   - 둘 다 같은 `ImageSource` 포트 뒤에 둡니다. iOS 카메라 경로에 VisionKit은 쓰지 않습니다(필터 강제, iOS 26 크래시 보고).
4. ML Kit은 자동 회전을 끌 수 없고 180° 오판 보고(#843)가 있습니다. 그래서 회전 판별(README 3절)은 어떤 어댑터를 쓰든 OCR 블록에 둡니다.
5. 휜 페이지 펴기는 보류합니다. 넣는다면 page-dewarp(기하, OpenCV + 최적화기)보다 UVDoc(ONNX → CoreML/TFLite, 약 30MB, 컬러 보존)이 이식하기 쉽습니다.

## 5. 확인 못 한 것
- `VNDocumentCameraViewController` 출력 해상도, API 기본 필터, 마지막 필터를 기억하는지 여부
- iOS 27(WWDC26)의 새 VisionKit 문서 API 유무
- ML Kit 결과 JPEG의 해상도·품질, 정확한 APK 증가량
- `opencv_dart`(core + imgproc)의 실제 APK/IPA 증가량
- UVDoc의 모바일 추론 시간
