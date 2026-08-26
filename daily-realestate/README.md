# 부동산 뉴스 카드뉴스 자동화 운영 매뉴얼

이 문서는 `daily-realestate` 자동화 작업을 이어받기 위한 운영 기준이다.

새 Codex 세션, GitHub Actions, 또는 사람이 직접 작업할 때 이 문서를 먼저 읽고 진행한다.

## 1. 시스템 목적

- 부동산 공급 관련 뉴스를 매일 수집한다.
- 수집된 기사에 번호를 붙이고 링크와 함께 검토할 수 있게 한다.
- 사용자가 선택한 기사만 Instagram 카드뉴스로 제작한다.
- 기사 1건은 카드뉴스 1세트로 제작한다.
- 검수 후 Instagram `@landbrief.daily`에 게시한다.

수집 주제:

- 재개발
- 재건축
- 청약
- 교통·SOC
- 신도시
- 공공주택지구
- 정비사업
- 주택공급 정책

## 2. 핵심 운영 원칙

### 번호 기반 뉴스

매일 자동 수집된 뉴스는 후보 목록이다.

사용자가 기사 번호를 선택해야 카드뉴스 제작 대상으로 확정된다.

예:

```text
3, 8, 9번 제작
3, 8, 9번 게시
```

### 링크 기반 뉴스

사용자가 직접 기사 링크를 주는 경우, 그 링크는 후보가 아니라 확정 콘텐츠다.

다만 기존 카드뉴스 빌더가 번호 기반으로 작동하므로, 내부적으로만 `1`, `2`, `3` 같은 제작 번호를 부여한다.

이 번호는 수집 후보 번호가 아니라 확정 링크 콘텐츠를 제작 파이프라인에 태우기 위한 번호다.

## 3. 절대 지켜야 할 콘텐츠 규칙

- 기사에 없는 내용은 쓰지 않는다.
- 애매한 내용은 제외하거나 사용자에게 확인한다.
- `없음으로 보도`, `확인 전까지 보류`처럼 내부 작업 문구를 외부 콘텐츠에 쓰지 않는다.
- 원인과 결과를 임의로 연결하지 않는다.
- 예타 통과, 검토, 확정, 착공, 개통, 고시, 승인, 계획은 정확히 구분한다.
- 사업 형태나 공식 명칭은 임의로 축약하지 않는다.

예:

- `신통기획 확정`을 `재개발 확정`으로 바꾸지 않는다.
- `모아타운`, `신속통합기획`, `공공주택지구`, `A-2블록` 같은 명칭을 살린다.
- `신공항`처럼 축약된 표현이 오해를 만들 수 있으면 `대구경북통합신공항`처럼 정확한 명칭을 쓴다.

## 4. 이미지 사용 원칙

카드뉴스 배경이나 보조 이미지로 사용할 수 있는 자료:

- 기사 내 공식 조감도
- 위치도
- 구역도
- 배치도
- 노선도
- 공공기관·지자체·시행기관 제공 이미지

주의:

- 일반 현장 사진, 기자 촬영 사진, 출처가 불명확한 이미지는 자동 사용하지 않는다.
- 사용 조건이 불분명하면 사용자에게 확인한다.
- 내부 검토 결과를 카드뉴스나 캡션에 노출하지 않는다.
- 이미지 사용 시 다크 오버레이를 적용해 텍스트 가독성을 우선한다.

## 5. 디자인 규칙

기본 규격:

- 크기: 1080×1350px
- 비율: 4:5
- 기사 1건당 5장 이상 8장 이하
- 모바일에서 읽히는 폰트 크기 유지

스타일:

- 배경: 네이비·딥블루 계열
- 강조색: 오렌지·옐로우 계열
- 텍스트: 흰색 중심
- 우측 상단 뱃지 없음
- 우측 하단: `@landbrief.daily`
- 좌측 하단: `출처: 언론사명 (YYYY.MM.DD)`

줄바꿈·정렬:

- 긴 명칭은 수동 줄바꿈을 적용한다.
- 단어 중간이 어색하게 끊기지 않게 한다.
- 표 형식 카드의 값은 세로 가운데 정렬을 유지한다.
- `블록`처럼 의미가 불충분한 라벨은 `블록명`처럼 명확하게 쓴다.
- 영문·숫자 코드가 깨지지 않게 한다.
  - 예: `A-2`를 `A-`와 `2`로 나누지 않는다.

## 6. 캡션 규칙

- 기사 원문 링크는 캡션에 넣지 않는다.
- 출처는 언론사명만 쓴다.
- `[핵심]` 표현은 생략한다.
- 기사 내용에 맞는 이모지를 적절히 사용한다.
- 해시태그는 기사 주제에 맞게 직접 보정한다.
- 자동 생성된 짧고 어색한 태그는 제거한다.

예:

- 좋은 태그: `#대구경북광역철도`, `#예타통과`, `#신속통합기획`
- 피할 태그: `#광역`, `#접근시`처럼 맥락이 약한 단어

## 7. 매일 뉴스 수집

GitHub Actions:

- `Daily real-estate supply news`

주요 결과물:

- `daily-realestate/output/YYYY-MM-DD/candidates.json`
- `daily-realestate/output/YYYY-MM-DD/ARTICLES.md`
- `daily-realestate/output/YYYY-MM-DD/articles.txt`

수집 제외:

- `고령자주택신문`

이 매체는 과거 기사를 현재 기사처럼 게시하는 사례가 확인되어 수집 대상에서 제외한다.

## 8. 번호 기반 카드뉴스 제작

GitHub Actions:

- `Build selected real-estate carousels`

입력:

- `Collection date in yyyy-MM-dd`
- `Article numbers to build`

예:

```text
Date: 2026-08-26
Numbers: 3,8,9
```

로컬 실행 예:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\daily-realestate\build-selected.ps1 -Date "2026-08-26" -Numbers "3,8,9"
```

## 9. 번호 기반 Instagram 게시

GitHub Actions:

- `Publish selected carousels to Instagram`
- 또는 `daily-realestate/publish-request.json` 기반 자동 게시

게시 전 확인:

- `REVIEW.md`
- `article-detail.json`
- `caption.txt`
- 이미지 사용 조건
- 슬라이드 줄바꿈
- 사업 단계 표현
- 출처·날짜 표기

## 10. 링크 기반 제작·게시

파일:

- `daily-realestate/link-request.json`

링크 기반 요청은 사용자가 확정한 콘텐츠다.

제작만 할 때:

```json
{
  "enabled": true,
  "publish_to_instagram": false,
  "review_confirmed": false,
  "image_usage_confirmed": false
}
```

게시까지 할 때:

```json
{
  "enabled": true,
  "publish_to_instagram": true,
  "review_confirmed": true,
  "image_usage_confirmed": true
}
```

게시 후에는 반드시 다음처럼 되돌린다.

```json
{
  "enabled": false,
  "publish_to_instagram": false,
  "review_confirmed": false,
  "image_usage_confirmed": false
}
```

이 작업은 중복 게시 방지를 위한 필수 안전장치다.

로컬 제작 흐름:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\daily-realestate\prepare-link-request.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\daily-realestate\build-selected.ps1 -Date "<link-request date>" -Numbers "1"
powershell -NoProfile -ExecutionPolicy Bypass -File .\daily-realestate\validate-carousel-output.ps1 -Date "<link-request date>" -Numbers "1"
```

## 11. GitHub Actions 게시 흐름

링크 기반 게시 워크플로:

- `.github/workflows/publish-link-request-instagram.yml`

순서:

1. `link-request.json` 읽기
2. 확정 링크 기사에 제작 번호 부여
3. 카드뉴스 제작
4. GitHub Pages에 JPEG 공개
5. 공개 이미지 URL 검증
6. 카드뉴스 산출물 검수
7. 검수 플래그 확인
8. Meta API로 Instagram 게시
9. 게시 결과 artifact 업로드

게시 결과 확인:

- GitHub Actions artifact
- `publish-result.json`
- Instagram 실제 게시물

## 12. 주요 파일 구조

```text
daily-realestate/
  README.md
  config.json
  link-request.json
  publish-request.json
  prepare-link-request.ps1
  build-selected.ps1
  publish-instagram-carousel.ps1
  validate-carousel-output.ps1
  verify-public-image-urls.ps1
  assets/
    article-backgrounds/
  output/
    YYYY-MM-DD/
```

## 13. 새 Codex 세션에서 이어가기

새 Codex 세션에서 다음처럼 요청한다.

```text
C:\Users\nahah\Documents\Anti_outsocing 폴더의 부동산 뉴스 카드뉴스 자동화 작업을 이어서 진행해줘.
AGENTS.md와 daily-realestate/README.md를 먼저 읽고, 현재 GitHub Actions/Instagram 게시 자동화 구조를 파악해줘.
링크로 주는 기사는 후보가 아니라 확정 콘텐츠로 처리하고, 게시 전에는 기존 검수 규칙을 지켜줘.
```

## 14. 게시 전 최종 체크리스트

- [ ] 기사 1건당 카드뉴스 1세트인지 확인
- [ ] 5장 이상 8장 이하인지 확인
- [ ] 기사에 없는 내용을 쓰지 않았는지 확인
- [ ] 공식 사업명과 단계 표현이 정확한지 확인
- [ ] 이미지가 공식 조감도·위치도·구역도·노선도 계열인지 확인
- [ ] 하단 출처와 날짜가 맞는지 확인
- [ ] 우측 하단 `@landbrief.daily`가 들어갔는지 확인
- [ ] 캡션에 기사 링크가 없는지 확인
- [ ] 해시태그가 기사 내용에 맞는지 확인
- [ ] 게시 후 `link-request.json` 또는 `publish-request.json`이 비활성화됐는지 확인
