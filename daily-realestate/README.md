# 부동산 공급 뉴스 데일리 자동화

재개발, 재건축, 청약, 분양, 교통/SOC, 신도시, 정비사업 관련 뉴스를 매일 수집하고, 사용자가 고른 기사만 인스타그램 카드뉴스로 제작하는 작업 폴더입니다.

GitHub Actions로 PC 없이 운영하려면 먼저 [`GITHUB_SETUP.md`](./GITHUB_SETUP.md)를 따라 설정합니다.
현재 구현 상태는 [`PROJECT_STATUS.md`](./PROJECT_STATUS.md), 실제 런칭 직전 확인 항목은 [`LAUNCH_CHECKLIST.md`](./LAUNCH_CHECKLIST.md)에서 볼 수 있습니다.
카드뉴스 디자인 기준은 [`CAROUSEL_STYLE_REFERENCE.md`](./CAROUSEL_STYLE_REFERENCE.md)에 정리했습니다.

## 1. 기사 수집

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-daily.ps1
```

결과는 `daily-realestate/output/YYYY-MM-DD/`에 저장됩니다.

- `ARTICLES.md`: 번호, 제목, 분류, 출처, 링크가 있는 검토용 목록
- `articles.txt`: 메신저에 붙여넣기 쉬운 목록
- `selection.txt`: 카드뉴스로 만들 기사 번호 입력 파일
- `original-urls.json`: Google News 중간 링크 대신 사용할 원문 URL 입력 파일
- `candidates.json`: 수집 후보 원본 데이터
- `status.json`: 실행 상태
- `collection-validation-report.json`: 수집 후보 검증 보고서

## 2. 기사 선택

`selection.txt`에 원하는 번호를 쉼표로 입력합니다.

```text
1,3,7
```

또는 명령에서 바로 지정할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\build-selected.ps1 -Numbers "1,3,7"
```

Google News 링크만으로 원문 본문이 열리지 않는 경우가 있습니다. 원문 URL을 알고 있으면 `original-urls.json`의 `urls`에 번호별로 입력합니다.

```json
{
  "note": "선택 기사 원문 URL을 알고 있으면 아래처럼 번호별로 입력하세요.",
  "urls": {
    "1": "https://media.example.com/news/article.html",
    "3": "https://another.example.com/news/article.html"
  }
}
```

이 값을 넣으면 `article-detail.json`과 `REVIEW.md`는 Google News 링크보다 수동 원문 URL을 우선 사용합니다.

## 3. 카드뉴스 제작

선택된 기사는 서로 합치지 않습니다. 기사 1건당 별도 카드뉴스 1세트를 만듭니다.

- 출력 폴더: `daily-realestate/output/YYYY-MM-DD/article-NN-carousel/`
- 장수: 기본 7장, 규칙상 5~8장
- 크기: 1080 x 1350 px, 4:5
- 파일: `01.png` ~ `07.png`, `caption.txt`, `REVIEW.md`, `article-detail.json`

게시 전에는 각 세트의 `REVIEW.md`와 `article-detail.json`을 확인합니다. 기사 문맥이 애매한 내용은 쓰지 않고, 원인과 결과를 임의로 연결하지 않습니다.

`article-detail.json`에는 가능한 경우 원문 메타 설명, 본문 일부, 이미지 후보, 문맥 경고가 저장됩니다. Google News 중간 페이지만 확인되거나 원문 본문을 읽지 못하면 그 사실이 경고로 남고, 이미지는 자동 사용하지 않습니다.

## 4. 이미지 사용 원칙

카드뉴스에는 뉴스 기사 안에 포함된 조감도, 위치도, 구역도, 노선도처럼 공식 원문에서 발췌된 자료만 사용할 수 있습니다.

- 인물 사진, 현장 취재 사진, 장식성 사진은 사용하지 않습니다.
- 기사 밖의 원본 자료를 새로 찾아 쓰지 않습니다.
- 사용 조건이 불분명하면 게시 전에 사용자 확인을 받습니다.
- 이미지가 없거나 사용 조건이 애매하면 숫자 카드, 표, 타임라인으로 대체합니다.

## 5. 수집 결과 검증

수집 직후 아래 명령으로 후보 목록을 검증할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\validate-news-output.ps1 `
  -Date "2026-08-23" `
  -MinCandidates 5
```

검증 항목:

- `ARTICLES.md`, `articles.txt`, `candidates.json`, `selection.txt`, `original-urls.json`, `status.json` 존재 여부
- 후보 기사가 최소 개수 이상인지
- 차단 매체가 후보에 섞였는지
- 제외 키워드와 출처 사이트 누락 여부

결과는 `daily-realestate/output/YYYY-MM-DD/collection-validation-report.json`에 저장됩니다.

## 6. 카드뉴스 산출물 검증

카드뉴스 생성 후 아래 명령으로 산출물을 검증할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\validate-carousel-output.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3" `
  -RequireJpeg
```

검증 항목:

- 기사별 폴더 존재 여부
- PNG 5~8장 구성
- 모든 PNG가 1080 x 1350인지
- `REVIEW.md`, `caption.txt`, `article-detail.json` 존재 여부
- `-RequireJpeg` 사용 시 `_publish/*.jpg` 2~10장 존재 여부

결과는 `daily-realestate/output/YYYY-MM-DD/validation-report.json`에 저장됩니다.

## 7. Meta 공식 API 게시

Meta 게시 스크립트는 `publish-instagram-carousel.ps1`입니다.

Meta API는 로컬 파일을 직접 가져가지 못합니다. JPEG 이미지가 공개 URL로 접근 가능해야 합니다. 먼저 PNG를 JPEG로 변환하고 게시 manifest를 만듭니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\publish-instagram-carousel.ps1 `
  -CarouselDir .\daily-realestate\output\2026-08-23\article-01-carousel `
  -ImageBaseUrl "https://public.example.com/article-01-carousel" `
  -PrepareJpeg `
  -DryRun
```

실제 게시에는 환경 변수가 필요합니다.

```powershell
$env:META_IG_USER_ID = "인스타그램_프로페셔널_계정_ID"
$env:META_IG_ACCESS_TOKEN = "Meta_Instagram_User_Access_Token"
```

드라이런 없이 실행하면 캐러셀 컨테이너를 만들고 `media_publish`까지 호출합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\publish-instagram-carousel.ps1 `
  -CarouselDir .\daily-realestate\output\2026-08-23\article-01-carousel `
  -ImageBaseUrl "https://public.example.com/article-01-carousel" `
  -PrepareJpeg
```

## 8. 자동 실행

PC를 켜지 않아도 수집하려면 GitHub Actions 같은 클라우드 스케줄러로 `run-daily.ps1`을 실행해야 합니다. 이 저장소에는 `.github/workflows/daily-realestate-news.yml`이 포함되어 있습니다.

- 실행 시각: 매일 07:30 KST
- 수동 실행: GitHub Actions 탭에서 `Daily real-estate supply news` 선택 후 `Run workflow`
- 결과 확인: 저장소의 `daily-realestate/output/YYYY-MM-DD/ARTICLES.md` 또는 실행 결과 artifact `realestate-news-YYYY-MM-DD`
- 보관 기간: 14일

로컬 Windows 작업 스케줄러는 PC가 켜져 있을 때만 안정적으로 동작합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\install-schedule.ps1 -Time 07:30
```

## 9. 운영 준비 상태 점검

아래 명령으로 로컬 파일, GitHub Actions 워크플로, Chrome 렌더링 준비, Meta 환경변수, 검증 보고서 존재 여부를 한 번에 확인할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\check-automation-readiness.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3"
```

실제 Meta 게시 환경변수까지 필수로 검사하려면 `-RequireMetaEnv`를 추가합니다.

결과는 `daily-realestate/readiness-report.json`에 저장됩니다.

카드뉴스 렌더링은 Chrome 또는 Edge headless 브라우저를 사용합니다. 기본 경로에서 브라우저를 찾지 못하면 `CHROME_PATH` 환경변수로 실행 파일 경로를 지정할 수 있습니다.

```powershell
$env:CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

엔드투엔드 스모크 테스트는 아래 명령으로 실행합니다. 기존 수집 결과를 사용하려면 `-SkipCollect`를 붙입니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-smoke-test.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3" `
  -SkipCollect
```

스모크 테스트는 수집 검증, 카드뉴스 생성, JPEG 준비, 카드뉴스 산출물 검증, 운영 준비 상태 점검을 순서대로 실행합니다. 결과는 `daily-realestate/output/YYYY-MM-DD/smoke-test-report.json`에 저장됩니다.

## 10. GitHub에서 카드뉴스 생성

매일 수집 결과를 보고 카드뉴스로 만들 번호를 고른 뒤, GitHub Actions에서 `Build selected real-estate carousels`를 수동 실행합니다.

- `date`: 수집 날짜. 예: `2026-08-23`
- `numbers`: 선택 번호. 예: `1,3,7`
- 결과: artifact `selected-carousels-YYYY-MM-DD`

이 artifact에는 기사별 폴더가 따로 들어갑니다. 각 폴더 안에는 1080 x 1350 PNG, 게시용 JPEG 초안, 캡션, 검수 문서가 포함됩니다.

실제 Meta API 게시 전에는 `_publish/*.jpg` 파일을 공개 URL에 올린 뒤 `publish-manifest.json`의 `imageUrls`를 실제 공개 주소로 맞춰야 합니다.

## 11. GitHub에서 Meta API 게시

`Publish selected carousels to Instagram` 워크플로는 선택한 기사 카드뉴스를 다시 생성하고, 게시용 JPEG를 GitHub Pages에 올린 뒤, 옵션에 따라 Meta 공식 API로 인스타그램 캐러셀을 게시합니다.

수동 실행 입력값:

- `date`: 수집 날짜. 예: `2026-08-23`
- `numbers`: 게시할 기사 번호. 예: `1,3`
- `publish_to_instagram`: `false`면 공개 URL 준비와 드라이런만 실행, `true`면 실제 게시
- `review_confirmed`: `REVIEW.md`와 `article-detail.json`에서 문맥, 수치, 날짜, 사업 단계를 확인했으면 `true`
- `image_usage_confirmed`: 사용 이미지가 공식 조감도·위치도·구역도·노선도 계열이거나 이미지 미사용이면 `true`

GitHub repository settings의 `Secrets and variables > Actions`에 아래 secrets를 넣어야 실제 게시가 가능합니다.

- `META_IG_USER_ID`: 인스타그램 프로페셔널 계정 ID
- `META_IG_ACCESS_TOKEN`: `instagram_business_basic`, `instagram_business_content_publish` 권한이 있는 토큰

선택 변수:

- `META_GRAPH_VERSION`: 기본값은 스크립트의 `v23.0`

주의:

- GitHub Pages가 활성화되어 있어야 공개 이미지 URL이 생깁니다.
- 먼저 `publish_to_instagram=false`로 실행해 공개 URL과 artifact를 확인합니다.
- 실제 게시 전 각 기사 폴더의 `REVIEW.md`, `article-detail.json`, `publish-manifest.json`을 확인합니다.
- `publish_to_instagram=true`로 실행하려면 `review_confirmed=true`, `image_usage_confirmed=true`도 함께 선택해야 합니다.
- `publish_to_instagram=true`로 실행하면 실제 계정에 게시됩니다.
- Meta API는 공개 URL의 이미지를 가져가므로, 게시 전에 Pages 배포가 완료되어야 합니다.
- Pages 배포 후 `verify-public-image-urls.ps1`가 `publish-manifest.json`의 JPEG URL이 실제로 열리는지 확인합니다. 실패하면 Meta 게시 전에 중단됩니다.










