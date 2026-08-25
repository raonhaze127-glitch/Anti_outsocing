# GitHub 운영 설정 체크리스트

이 문서는 PC를 켜지 않아도 매일 뉴스 수집이 돌아가고, 선택한 기사 카드뉴스를 GitHub에서 생성/게시 준비할 수 있게 만드는 설정 순서입니다.

## 1. 변경사항 push

먼저 이 저장소 변경사항을 GitHub에 push합니다. GitHub Actions 워크플로는 GitHub에 올라간 뒤부터 실행됩니다.

확인할 주요 파일:

- `.github/workflows/daily-realestate-news.yml`
- `.github/workflows/build-selected-carousels.yml`
- `.github/workflows/publish-selected-instagram.yml`
- `daily-realestate/*.ps1`
- `daily-realestate/README.md`
- `daily-realestate/GITHUB_SETUP.md`

현재 저장소에 다른 작업 변경사항이 섞여 있다면 자동화 파일만 분리해서 올립니다. 아래 명령은 기본적으로 dry-run으로 동작하며, 자동화에 필요한 파일만 stage 대상으로 보여줍니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\prepare-github-commit.ps1
```

목록이 맞으면 로컬 commit을 만듭니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\prepare-github-commit.ps1 -Commit
```

GitHub까지 바로 올릴 준비가 끝났을 때만 `-Push`를 붙입니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\prepare-github-commit.ps1 -Commit -Push
```

샘플 수집 결과까지 같이 commit하고 싶을 때만 `-IncludeSampleOutput`을 추가합니다. 보통은 소스/워크플로만 먼저 올리는 쪽이 깔끔합니다.

push 전 로컬 스모크 테스트:

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-smoke-test.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3" `
  -SkipCollect
```

`readiness-report.json`이 `ready` 또는 `ready_with_warnings`이고, `smoke-test-report.json`의 `state`가 `passed`이면 GitHub 설정 전 로컬 구조는 준비된 상태입니다.

## 2. Actions 권한 확인

GitHub repository에서 아래 설정을 확인합니다.

- `Settings > Actions > General`
- `Actions permissions`: Allow all actions and reusable workflows
- `Workflow permissions`: Read and write permissions
- `Allow GitHub Actions to create and approve pull requests`: 꺼져 있어도 됩니다

`daily-realestate-news.yml`은 매일 수집 결과를 저장소에 커밋하므로 `Read and write permissions`가 필요합니다.

## 3. GitHub Pages 활성화

Instagram API는 로컬 파일을 직접 가져가지 못하고 공개 URL의 JPEG를 가져갑니다. `publish-selected-instagram.yml`은 GitHub Pages를 무료 공개 이미지 호스팅으로 사용합니다.

GitHub repository에서 아래 설정을 확인합니다.

- `Settings > Pages`
- `Build and deployment > Source`: GitHub Actions

처음에는 `Publish selected carousels to Instagram` 워크플로를 `publish_to_instagram=false`로 실행해 Pages 배포와 공개 이미지 URL만 확인합니다.

## 4. Meta API secrets 등록

실제 Instagram 게시를 하려면 repository secrets가 필요합니다.

위치:

- `Settings > Secrets and variables > Actions > New repository secret`

필수 secrets:

- `META_IG_USER_ID`: 인스타그램 프로페셔널 계정 ID
- `META_IG_ACCESS_TOKEN`: `instagram_business_basic`, `instagram_business_content_publish` 권한이 있는 토큰

선택 variables:

- `META_GRAPH_VERSION`: 비워두면 스크립트 기본값 `v23.0` 사용
- `META_GRAPH_HOST`: 비워두면 스크립트 기본값 `https://graph.instagram.com` 사용

토큰 방식별 권장값:

- Instagram Login 방식: `META_GRAPH_HOST=https://graph.instagram.com`, 권한 `instagram_business_basic`, `instagram_business_content_publish`
- Facebook Login/Page 연결 방식: `META_GRAPH_HOST=https://graph.facebook.com`, 권한 `instagram_basic`, `instagram_content_publish`, `pages_read_engagement` 등

주의:

- Instagram 개인 계정은 게시 API 대상이 아닙니다. 프로페셔널 계정이어야 합니다.
- Instagram Login 방식은 Facebook Page 연결 없이도 가능하지만, Facebook Login 방식은 Instagram 프로페셔널 계정과 Facebook Page 연결이 필요합니다.
- 토큰은 만료될 수 있으므로 게시 실패 시 먼저 secret 만료 여부를 확인합니다.

## 5. 첫 수집 테스트

GitHub Actions 탭에서 수동 실행합니다.

- Workflow: `Daily real-estate supply news`
- 입력값 `date`: 비워두거나 오늘 날짜 입력

성공 후 확인:

- `daily-realestate/output/YYYY-MM-DD/ARTICLES.md`
- `daily-realestate/output/YYYY-MM-DD/candidates.json`
- `daily-realestate/output/YYYY-MM-DD/collection-validation-report.json`
- Artifact: `realestate-news-YYYY-MM-DD`

`collection-validation-report.json`의 `state`가 `valid` 또는 `valid_with_warnings`인지 확인합니다.

## 6. 기사 선택

`ARTICLES.md`에서 번호와 링크를 보고 카드뉴스로 만들 번호를 고릅니다.

Google News 중간 링크만 있고 원문 검수가 필요하면 `original-urls.json`에 번호별 원문 URL을 넣습니다.

```json
{
  "urls": {
    "1": "https://media.example.com/news/article.html"
  }
}
```

원문 URL을 넣은 경우 변경사항을 GitHub에 커밋해야 Actions에서 읽을 수 있습니다.

## 7. 카드뉴스 생성 테스트

GitHub Actions 탭에서 수동 실행합니다.

- Workflow: `Build selected real-estate carousels`
- `date`: 예: `2026-08-23`
- `numbers`: 예: `1,3`

성공 후 artifact `selected-carousels-YYYY-MM-DD`를 다운로드해 확인합니다.

확인할 파일:

- `article-NN-carousel/01.png` ~ `07.png`
- `article-NN-carousel/REVIEW.md`
- `article-NN-carousel/article-detail.json`
- `article-NN-carousel/caption.txt`
- `validation-report.json`

## 8. 게시 드라이런

먼저 실제 게시 없이 공개 URL만 확인합니다.

- Workflow: `Publish selected carousels to Instagram`
- `date`: 예: `2026-08-23`
- `numbers`: 예: `1,3`
- `publish_to_instagram`: `false`
- `review_confirmed`: `false` 가능
- `image_usage_confirmed`: `false` 가능

성공 후 artifact와 Pages URL을 확인합니다.

확인할 파일:

- `publish-manifest.json`
- `public-image-url-report.json`
- `REVIEW.md`
- `article-detail.json`
- `validation-report.json`

`public-image-url-report.json`의 `state`가 `valid`여야 Meta가 JPEG를 가져갈 수 있는 상태입니다.

## 9. 실제 게시

아래를 확인한 뒤에만 실제 게시합니다.

- `REVIEW.md`에서 수치, 날짜, 사업 단계 확인
- `article-detail.json`에서 문맥 경고 확인
- 이미지 후보가 `do_not_use`면 사용하지 않음
- 사용 이미지가 공식 조감도, 위치도, 구역도, 노선도 계열인지 확인
- `publish-manifest.json`의 `imageUrls`가 GitHub Pages 공개 URL인지 확인

실제 게시 입력값:

- `publish_to_instagram`: `true`
- `review_confirmed`: `true`
- `image_usage_confirmed`: `true`

세 값이 맞지 않으면 워크플로는 Meta API 호출 전에 멈춥니다.

## 10. 실패 시 먼저 볼 파일

- 수집 실패: `errors.log`, `collection-validation-report.json`
- 후보 품질 문제: `ARTICLES.md`, `candidates.json`, `config.json`
- 카드뉴스 생성 실패: workflow log, `validation-report.json`
- 문맥/이미지 문제: `REVIEW.md`, `article-detail.json`
- 공개 이미지 URL 실패: `public-image-url-report.json`, GitHub Pages 설정
- 게시 실패: `publish-manifest.json`, `content-publishing-limit.json`, `publish-container-status.json`, `publish-result.json`
- 전체 준비 상태: `daily-realestate/readiness-report.json`



