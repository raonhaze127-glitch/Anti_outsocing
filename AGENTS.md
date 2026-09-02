# 🎨 썸네일 & 인포그래픽 제작 최우선 원칙 가이드 (DESIGN_RULES.md)

> ⚠️ **AI 수행 절대 원칙**: 본 문서에 기재된 디자인 규격 및 텍스트 준수 규칙은 모든 썸네일 및 인포그래픽 생성 작업 시 **최우선 적용**한다.

---

## 🚨 최우선 필수 적용 수칙: 여백 극소화 & 최상 밀착 품질 (ZERO UNNECESSARY WHITESPACE & DYNAMIC FIT)

> 📌 **이미지 내부 상하·중간 허공 여백(Gap/Padding/Margin)을 완벽 소거하고 컴포넌트를 최상의 밀착 품질로 결합한다.**
> 
> 1. **동적 픽셀 높이 자동 측정 (Dynamic Bounding Box Measurement)**:
>    - 인포그래픽 생성 시 캔버스 수직 높이를 임의의 static 수치로 고정하지 않는다.
>    - 로딩 완료 후 렌더링된 `.container` (또는 `body`)의 실제 실효 픽셀 높이(`bounding_box()["height"]`)를 Playwright로 동적 자동 측정한 뒤, **실제 콘텐츠 높이에 100% 딱 맞는 뷰포트로 재설정하여 캡처**한다. (단 1px의 수직 허공 유격도 남지 않도록 완벽 소거)
>
>    ```python
>    # 💡 최상 밀착 품질 캡처 필수 코드 패턴
>    page.set_viewport_size({"width": 800, "height": 1000})
>    page.goto(file_url)
>    page.wait_for_timeout(1000)
>    
>    # 실제 내부 렌더링 컨테이너의 실효 픽셀 높이 측정
>    container_box = page.locator(".container").bounding_box()
>    actual_height = int(container_box["height"]) if container_box else int(page.locator("body").bounding_box()["height"])
>    
>    # 1px의 남는 여백도 없이 딱 맞는 높이로 재조정하여 스크린샷
>    page.set_viewport_size({"width": 800, "height": actual_height})
>    page.screenshot(path=dest_path, type="png")
>    ```
> 
> 2. **컴포넌트 수직 밀착 결합 구조**:
>    - `body { margin: 0; padding: 0; }` 및 `.container { display: flex; flex-direction: column; justify-content: flex-start; }`를 적용한다.
>    - `.content` 컨테이너에 `display: flex; flex-direction: column; gap: 3px~5px;`를 적용하여 요소 간 유격을 콤팩트하게 밀착한다.
>    - 상단 헤더 높이: **38px ~ 42px**
>    - 카드 내외부 패딩: **4px ~ 8px**
>    - 하단 안내 박스 및 푸터는 상단 패널 바로 아래 `gap: 3px~4px`로 밀착하여 중간 빈 허공을 100% 소거한다.
> 
> 3. **외주 의뢰서 텍스트 100% 엄격 반영**:
>    - 의뢰서 텍스트만을 100% 엄격 반영하며, 지정되지 않은 임의 문구나 주석을 추가하지 않는다.

---

## 🖼️ 1. 썸네일 표준 디자인 규격

- **사이즈**: **1600 × 900px (16:9 와이드)**
- **1:1 안전영역**: 캔버스 중앙 **900 × 900px** (좌우 각 350px은 블리드 영역)
- **안전영역 안착 제약**: 텍스트가 좌우 900px 안전범위를 벗어나지 않도록 `max-width: 860px` 및 font-size 자동 스케일링 적용
- **레이어 구조 (아래 → 위)**:
  1. **단지 이미지** — 1600×900px 풀블리드 (첨부 이미지가 2개일 경우 50% 가로 분할로 이음새 없이 합성)
  2. **다크 오버레이** — `#0D1B3E`, 불투명도 **65%** (전체 캔버스)
  3. **텍스트·배지 레이어** — 1:1 안전영역(중앙 900px) 안에 집중 배치
- **색상 & 스타일**:
  - 기관 배지: `#F5A623` 배경, 흰색 Bold (32px)
  - 상태 배지: `#555555` 회색 또는 `#E53E3E` 마감 레드 배경, 흰색 Bold (32px)
  - 단지명: 흰색 Bold (72~80px)
  - 핵심 수치: `#F5A623` Bold (68~84px 스케일링)
  - 보조 수치: 흰색 Bold (38~44px)
  - 하단 날짜/기준: 흰색 Regular (32px)
- **전체 폰트**: Pretendard Bold / Noto Sans KR Bold

---

## 📊 2. 인포그래픽 표준 디자인 규격

- **출력 사이즈**: **가로 800px / PNG**
- **수직 높이**: **동적 자동 측정 (Content Bounding Box Height)** (중간 및 상하 허공 유격 100% 완전 소거)
- **색상 팔레트**:
  - 메인 컬러: `#1F5ADB` (LH / SH 블루 계열)
  - 서브 컬러: `#F5A623` (강조용 오렌지)
  - 배경: `#F8F9FA` (연회색) 또는 흰색
  - 텍스트: `#1A1A1A` (본문), `#555555` (보조)
- **폰트**: Noto Sans KR Bold (제목) / Regular (본문), Pretendard
- **공통 푸터**: 의뢰서 지정 출처 문구 좌하단 탑재

---

## 📱 3. 인스타그램 캐러셀 1:1 그리드 피트 원칙 (INSTAGRAM_GRID_SAFE_ZONE)

### 기사 이미지 대체 원칙

- Codex 제작 단계에서 기사 내 건물 전경·조감도·지형도·위치도·구역도·배치도·노선도를 먼저 사용한다.
- 사용할 수 있는 기사 이미지가 없으면 기사 내용에 맞는 편집용 배경 이미지를 Codex 이미지 생성 도구로 자동 생성한다.
- 생성 이미지에는 사람·얼굴·글자·숫자·로고·표지판·문서·차트를 넣지 않는다.
- 생성 배경은 `daily-realestate/assets/article-backgrounds/<제작일>/article-XX-bg.png`로 저장해 카드와 함께 GitHub에 반영한다.
- GitHub Actions 예약 실행은 완성된 카드뉴스 게시만 담당하며 이미지 생성 API를 호출하지 않는다.

> 📌 **인스타그램 프로필 피드는 1:1 정사각형(1080×1080px)으로 자동 크롭되므로, 4:5(1080×1350px) 표지 제작 시 다음 안전영역 수칙을 엄격히 준수한다.**

1. **1:1 정방형 피드 안전영역 (Square Safe Zone)**:
   - **Y축 범위**: `170px` ~ `1170px` (상하 각 170px 여백 확보, 1:1 크롭 영역 상하 135px 잘림 대비)
   - **X축 범위**: `150px` ~ `930px` (좌우 각 150px 여백 확보, 최대 텍스트 사용 폭 `780px` 이하 고정)
2. **타이포그래피 및 배지 위치 규격**:
   - **표지 메인 제목 폰트 크기**: **`68px ~ 70px`** (80px 이상 사용 절대 금지, 텍스트 가로 폭 780px 초과 금지)
   - **상태/기관 배지 위치**: 좌상단 구석 금지! **제목 상단 중앙** (`top: 170px` 부근)에 안착
   - **핵심 수치/알림 박스**: 1:1 정방형 뷰의 중심부 (`y: 650px ~ 1050px`) 안쪽에 위치

---

## 📁 파일 저장 및 프리뷰 규칙
- **기본 저장 경로**: `C:\Users\nahah\Documents\Anti_outsocing\`
- **아티팩트 프리뷰**: 생성된 이미지는 아티팩트 디렉토리에 복사하여 대화창 마크다운 이미지 프리뷰로 즉시 제시

