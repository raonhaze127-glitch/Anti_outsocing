# 현재 자동화 상태

마지막 점검: 2026-08-23 KST

## 구현 완료

- 매일 부동산 공급 관련 뉴스 기사 후보 수집
- 기사 번호, 제목, 출처, 링크가 포함된 `ARTICLES.md` 생성
- 사용자가 고른 번호만 카드뉴스 제작
- 기사 1건당 별도 카드뉴스 1세트 생성
- 각 카드뉴스 7장 구성
- 인스타그램 4:5 규격 `1080×1350px` PNG 생성
- 게시 준비용 JPEG 변환
- 공식 자료 이미지 사용 여부를 `article-detail.json`, `REVIEW.md`에서 확인하도록 기록
- 사용 조건이 불분명한 이미지는 자동 사용하지 않고 검수 대상으로 남김
- `고령자주택신문` 등 차단 매체 제외 설정
- GitHub Actions용 수집/제작/게시 준비 워크플로 작성
- Meta 공식 API 게시 스크립트 작성
- 수집 결과, 카드뉴스 산출물, 전체 준비 상태 검증 스크립트 작성

## 현재 검증된 샘플

날짜: `2026-08-23`

선택 기사: `1,3`

검증 결과:

- `run-smoke-test.ps1`: `passed`
- `validation-report.json`: `valid`
- `article-01-carousel`: 7장, 1080×1350, JPEG 7장
- `article-03-carousel`: 7장, 1080×1350, JPEG 7장

샘플 위치:

- `daily-realestate/output/2026-08-23/article-01-carousel/`
- `daily-realestate/output/2026-08-23/article-03-carousel/`

## 아직 외부 설정이 필요한 것

아래 항목은 로컬 파일만으로 완료할 수 없고 GitHub/Meta 쪽 설정이 필요합니다.

1. 이 변경사항을 GitHub에 push
2. GitHub Actions 권한을 `Read and write permissions`로 설정
3. GitHub Pages Source를 `GitHub Actions`로 설정
4. 실제 Instagram 게시를 원하면 repository secrets 등록
   - `META_IG_USER_ID`
   - `META_IG_ACCESS_TOKEN`

## 운영 순서

### 1. 매일 수집

GitHub Actions의 `Daily real-estate supply news`가 매일 07:30 KST에 실행됩니다.

로컬 테스트:

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-daily.ps1
```

### 2. 기사 선택

`daily-realestate/output/YYYY-MM-DD/ARTICLES.md`를 보고 카드뉴스로 만들 번호를 고릅니다.

선택 번호는 `selection.txt`에 입력하거나 Actions 실행 시 `numbers`에 입력합니다.

### 3. 카드뉴스 제작

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\build-selected.ps1 `
  -Date "YYYY-MM-DD" `
  -Numbers "1,3"
```

### 4. 게시 전 검수

각 카드뉴스 폴더에서 확인합니다.

- `REVIEW.md`
- `article-detail.json`
- `caption.txt`
- `01.png` ~ `07.png`

특히 기사 문맥, 수치, 일정, 사업 단계, 이미지 사용 조건은 게시 전 확인합니다.

### 5. 게시 준비 또는 게시

GitHub Actions의 `Publish selected carousels to Instagram`을 먼저 `publish_to_instagram=false`로 실행해 공개 이미지 URL과 산출물을 확인합니다.

실제 게시 전에는 다음 입력을 모두 확인합니다.

- `publish_to_instagram=true`
- `review_confirmed=true`
- `image_usage_confirmed=true`

## 빠른 점검 명령

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\run-smoke-test.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3" `
  -SkipCollect
```

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-realestate\check-automation-readiness.ps1 `
  -Date "2026-08-23" `
  -Numbers "1,3"
```

`ready_with_warnings`는 Meta secrets 같은 외부 설정이 아직 없을 때 정상적으로 나올 수 있습니다.
