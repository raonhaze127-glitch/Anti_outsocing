# 런칭 직전 체크리스트

이 파일은 자동화를 GitHub에 올린 뒤 실제로 매일 수집이 돌기 전 확인할 항목만 모아둔 빠른 체크리스트입니다.

## 1. 로컬에서 마지막 확인

- [ ] 아래 명령이 성공한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-smoke-test.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3" `
  -SkipCollect
```

- [ ] `daily-realestate/output/2026-08-23/smoke-test-report.json`의 `state`가 `passed`다.
- [ ] `daily-realestate/output/2026-08-23/validation-report.json`의 `state`가 `valid`다.
- [ ] `.gitignore`가 PNG/JPEG/HTML 산출물을 제외한다.
- [ ] 로컬에서 Chrome 또는 Edge를 찾을 수 있다. 필요하면 `CHROME_PATH` 환경변수를 지정한다.

## 2. GitHub에 push

- [ ] 아래 파일들이 GitHub에 올라간다.

```text
.github/workflows/daily-realestate-news.yml
.github/workflows/build-selected-carousels.yml
.github/workflows/publish-selected-instagram.yml
.gitignore
daily-realestate/
```

- [ ] 기존 작업 중인 파일이 많다면 자동화 파일만 별도 commit으로 분리한다.
- [ ] 아래 dry-run 명령으로 자동화 파일만 stage 대상인지 확인한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\prepare-github-commit.ps1
```

- [ ] staged 파일 목록이 맞으면 `-Commit`으로 로컬 commit을 만든다.
- [ ] GitHub 설정을 진행할 준비가 끝났을 때만 `-Push`한다.

## 3. GitHub Actions 설정

Repository Settings에서 확인합니다.

- [ ] `Settings > Actions > General`
- [ ] `Actions permissions`: Allow all actions and reusable workflows
- [ ] `Workflow permissions`: Read and write permissions

`Daily real-estate supply news`는 수집 결과를 저장소에 커밋하므로 write 권한이 필요합니다.

## 4. GitHub Pages 설정

Instagram API 게시까지 사용할 경우 필요합니다.

- [ ] `Settings > Pages`
- [ ] `Build and deployment > Source`: GitHub Actions

먼저 실제 게시 없이 `Publish selected carousels to Instagram` 워크플로를 `publish_to_instagram=false`로 실행해 공개 이미지 URL이 생기는지 확인합니다.

## 5. 첫 수집 테스트

GitHub Actions 탭에서 실행합니다.

- [ ] Workflow: `Daily real-estate supply news`
- [ ] `Run workflow`
- [ ] `date`: 비워두거나 오늘 날짜 입력

성공 후 확인:

- [ ] `daily-realestate/output/YYYY-MM-DD/ARTICLES.md`
- [ ] `daily-realestate/output/YYYY-MM-DD/candidates.json`
- [ ] `daily-realestate/output/YYYY-MM-DD/collection-validation-report.json`
- [ ] artifact `realestate-news-YYYY-MM-DD`

## 6. 기사 선택

- [ ] `ARTICLES.md`에서 카드뉴스로 만들 기사 번호를 고른다.
- [ ] Google News 중간 링크만 있으면 `original-urls.json`에 원문 URL을 번호별로 넣는다.
- [ ] 원문 URL을 수정했다면 GitHub에 commit/push한다.

## 7. 카드뉴스 생성 테스트

GitHub Actions 탭에서 실행합니다.

- [ ] Workflow: `Build selected real-estate carousels`
- [ ] `date`: 수집 날짜
- [ ] `numbers`: 예: `1,3`

성공 후 artifact에서 확인:

- [ ] 기사별 `article-NN-carousel` 폴더가 따로 있다.
- [ ] 각 폴더에 `01.png`~`07.png`가 있다.
- [ ] 모든 PNG가 1080×1350이다.
- [ ] `REVIEW.md`, `article-detail.json`, `caption.txt`가 있다.

## 8. 게시 전 검수

각 기사별로 확인합니다.

- [ ] 기사 문맥, 수치, 일정, 사업 단계가 원문과 맞다.
- [ ] 원인과 결과를 임의로 연결하지 않았다.
- [ ] 애매한 사례·거래가격·전망은 제외했거나 문맥과 함께 설명했다.
- [ ] 사용 이미지가 기사 내 공식 조감도·위치도·구역도·노선도 계열이다.
- [ ] 사용 조건이 불분명한 이미지는 게시 전 사용자 확인을 받았다.
- [ ] `핵심 요약`에 `저장용` 문구가 없다.

## 9. Meta API 게시 설정

실제 게시를 자동화할 경우만 진행합니다.

- [ ] Instagram 계정이 프로페셔널 계정이다.
- [ ] Meta 앱/토큰에 게시 권한이 있다.
- [ ] GitHub `Settings > Secrets and variables > Actions`에 아래 secrets를 등록했다.

```text
META_IG_USER_ID
META_IG_ACCESS_TOKEN
```

선택:

```text
META_GRAPH_VERSION
```

## 10. 실제 게시 전 드라이런

GitHub Actions 탭에서 실행합니다.

- [ ] Workflow: `Publish selected carousels to Instagram`
- [ ] `publish_to_instagram=false`
- [ ] Pages 배포 URL이 생긴다.
- [ ] artifact `publish-selected-YYYY-MM-DD`가 생성된다.
- [ ] `publish-manifest.json`의 이미지 URL이 공개 URL이다.
- [ ] `public-image-url-report.json`의 `state`가 `valid`다.

## 11. 실제 게시

아래 세 값을 모두 의도적으로 켭니다.

- [ ] `publish_to_instagram=true`
- [ ] `review_confirmed=true`
- [ ] `image_usage_confirmed=true`

성공 후 확인:

- [ ] Instagram 계정에 캐러셀이 게시됐다.
- [ ] artifact에 `publish-result.json`이 남았다.

## 12. 매일 운영 루틴

1. 오전 7:30 KST 자동 수집 결과 확인
2. `ARTICLES.md`에서 기사 번호 선택
3. 필요 시 `original-urls.json`에 원문 URL 보강
4. 카드뉴스 생성
5. `REVIEW.md` 검수
6. 이미지 사용 조건 확인
7. 드라이런 또는 실제 게시
