import os
import sys
from playwright.sync_api import sync_playwright

# Windows 콘솔 인코딩 문제 해결
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

DEST_DIR = r"C:\Users\nahah\Desktop\Anti_outsocing"
os.makedirs(DEST_DIR, exist_ok=True)

# 1. 청약 일정 타임라인 HTML (완벽 픽셀 밀착)
HTML_INFO1 = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>경기남부 청년신혼부부 매입임대리츠 청약 일정</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@500;700;900&display=swap" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 800px;
      background-color: #F8F9FA;
      font-family: 'Pretendard', 'Noto Sans KR', sans-serif;
      margin: 0;
      padding: 0;
    }
    
    .container {
      width: 800px;
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      background-color: #F8F9FA;
    }

    /* Header (H=38px) */
    .header {
      background-color: #1F5ADB;
      height: 38px;
      padding: 0 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      z-index: 10;
    }
    .header h1 {
      font-size: 15px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: -0.5px;
    }
    .badge-top {
      background-color: #F5A623;
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 900;
      padding: 2px 7px;
      border-radius: 4px;
      white-space: nowrap;
    }

    /* Content Area (Ultra compact) */
    .content {
      padding: 8px 12px;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }

    /* Horizontal Timeline (5 Steps) */
    .timeline-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
    }
    
    .timeline-step {
      width: 130px;
      height: 112px;
      background-color: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 5px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: center;
      padding: 4px 2px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02);
      text-align: center;
    }
    
    .step-num {
      font-size: 8.8px;
      font-weight: 900;
      color: #94A3B8;
    }
    .step-name {
      font-size: 10.5px;
      font-weight: 900;
      color: #334155;
      line-height: 1.2;
      flex-grow: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 1px 0;
    }
    .step-date {
      font-size: 8px;
      font-weight: 900;
      color: #64748B;
      background-color: #F1F5F9;
      padding: 2px 4px;
      border-radius: 3px;
      white-space: nowrap;
    }

    /* Connection Arrow */
    .step-arrow {
      font-size: 11px;
      font-weight: 900;
      color: #CBD5E1;
      user-select: none;
    }

    /* Accent themes */
    .step-accent-blue {
      width: 140px;
      height: 118px;
      border: 2px solid #1F5ADB;
      background-color: #EAF0FB;
      box-shadow: 0 3px 6px rgba(31, 90, 219, 0.18);
    }
    .step-accent-blue .step-num { color: #1F5ADB; font-size: 9px; }
    .step-accent-blue .step-name { color: #1F5ADB; font-size: 11.2px; }
    .step-accent-blue .step-date { background-color: #1F5ADB; color: #FFFFFF; font-size: 7.5px; }

    .step-accent-gold {
      border: 2px solid #F5A623;
      background-color: #FEF3E2;
      box-shadow: 0 2px 5px rgba(245, 166, 35, 0.18);
    }
    .step-accent-gold .step-num { color: #D97706; }
    .step-accent-gold .step-name { color: #D97706; }
    .step-accent-gold .step-date { background-color: #F5A623; color: #FFFFFF; }

    /* Footer */
    .footer {
      border-top: 1px solid #E2E8F0;
      padding: 4px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 8.2px;
      color: #94A3B8;
      font-weight: 500;
      background-color: #FFFFFF;
    }
  </style>
</head>
<body>

  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1>경기남부 청년신혼부부 매입임대리츠 청약 일정</h1>
      <div class="badge-top">D-7 마감</div>
    </div>

    <!-- Content -->
    <div class="content">
      <div class="timeline-row">
        <!-- Step 1 -->
        <div class="timeline-step">
          <span class="step-num">01</span>
          <span class="step-name">입주자모집공고</span>
          <span class="step-date">2026.8.3.(월)</span>
        </div>
        
        <span class="step-arrow">➔</span>

        <!-- Step 2 -->
        <div class="timeline-step step-accent-blue">
          <span class="step-num">02</span>
          <span class="step-name">청약 접수</span>
          <span class="step-date">8.18.(화)~8.20.(목)</span>
        </div>

        <span class="step-arrow">➔</span>

        <!-- Step 3 -->
        <div class="timeline-step">
          <span class="step-num">03</span>
          <span class="step-name">서류 제출</span>
          <span class="step-date">8.24.~8.28. (등기)</span>
        </div>

        <span class="step-arrow">➔</span>

        <!-- Step 4 -->
        <div class="timeline-step">
          <span class="step-num">04</span>
          <span class="step-name">예비순번 발표</span>
          <span class="step-date">10.23.(금) 16:00~</span>
        </div>

        <span class="step-arrow">➔</span>

        <!-- Step 5 -->
        <div class="timeline-step step-accent-gold">
          <span class="step-num">05</span>
          <span class="step-name">계약체결</span>
          <span class="step-date">공가 발생 시 안내</span>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="footer">
      <span>* 서류대상자 발표: 8.21.(금) 16:00 이후 | 출처: LH 입주자모집공고 / 2026.8.3. 기준</span>
    </div>
  </div>

</body>
</html>
"""

# 2. 소득기준 한눈에 보기 HTML (완벽 픽셀 밀착)
HTML_INFO2 = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>청년신혼부부 매입임대리츠 소득기준, 얼마까지 가능할까?</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@500;700;900&display=swap" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 800px;
      background-color: #F8F9FA;
      font-family: 'Pretendard', 'Noto Sans KR', sans-serif;
      margin: 0;
      padding: 0;
    }
    
    .container {
      width: 800px;
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      background-color: #F8F9FA;
    }

    /* Header (H=38px) */
    .header {
      background-color: #1F5ADB;
      height: 38px;
      padding: 0 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      z-index: 10;
    }
    .header h1 {
      font-size: 15px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: -0.5px;
    }
    .badge-top {
      background-color: #F5A623;
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 900;
      padding: 2px 7px;
      border-radius: 4px;
      white-space: nowrap;
    }

    /* Content Area */
    .content {
      padding: 8px 14px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    /* 2 Columns Panel */
    .cols-2 {
      display: flex;
      justify-content: space-between;
      gap: 10px;
    }
    .panel-card {
      width: 50%;
      border-radius: 6px;
      padding: 6px 10px;
      border: 1.5px solid;
      display: flex;
      flex-direction: column;
      gap: 2px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.02);
    }
    .panel-blue { background-color: #EAF0FB; border-color: #B4CFF6; }
    .panel-gold { background-color: #FEF3E2; border-color: #FCD34D; }

    .panel-title {
      font-size: 11.2px;
      font-weight: 900;
      padding-bottom: 2px;
      border-bottom: 1.5px solid;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .panel-blue .panel-title { color: #1F5ADB; border-color: #1F5ADB; }
    .panel-gold .panel-title { color: #D97706; border-color: #D97706; }

    .income-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 9.5px;
    }
    .income-table th, .income-table td {
      padding: 2px 3px;
      text-align: center;
    }
    .income-table th {
      font-weight: 900;
      border-bottom: 1px solid rgba(0,0,0,0.1);
    }
    .income-table td {
      font-weight: 700;
    }
    .income-table td strong {
      font-weight: 900;
    }
    .panel-blue .income-table td strong { color: #1F5ADB; }
    .panel-gold .income-table td strong { color: #D97706; }

    /* Footer */
    .footer {
      border-top: 1px solid #E2E8F0;
      padding: 4px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 8.2px;
      color: #94A3B8;
      font-weight: 500;
      background-color: #FFFFFF;
    }
  </style>
</head>
<body>

  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1>청년신혼부부 매입임대리츠 소득기준, 얼마까지 가능할까?</h1>
      <div class="badge-top">소득기준</div>
    </div>

    <!-- Content -->
    <div class="content">
      <div class="cols-2">
        <!-- Left Panel: 외벌이(단독) 100% 이하 -->
        <div class="panel-card panel-blue">
          <div class="panel-title">
            <span>👤 외벌이(단독) 100% 이하</span>
          </div>
          <table class="income-table">
            <tr><th>가구원 수</th><th>월소득 상한</th></tr>
            <tr><td>1인 가구</td><td><strong>4,576,036원</strong></td></tr>
            <tr><td>2인 가구</td><td><strong>6,452,897원</strong></td></tr>
            <tr><td>3인 가구</td><td><strong>8,168,429원</strong></td></tr>
            <tr><td>4인 가구</td><td><strong>8,802,202원</strong></td></tr>
          </table>
        </div>

        <!-- Right Panel: 맞벌이 2인 130% / 3인 이상 120% 이하 -->
        <div class="panel-card panel-gold">
          <div class="panel-title">
            <span>👥 맞벌이 (2인 130% / 3인이상 120%)</span>
          </div>
          <table class="income-table">
            <tr><th>가구원 수</th><th>적용비율</th><th>월소득 상한</th></tr>
            <tr><td>2인 가구</td><td>130%</td><td><strong>7,626,751원</strong></td></tr>
            <tr><td>3인 가구</td><td>120%</td><td><strong>9,802,115원</strong></td></tr>
            <tr><td>4인 가구</td><td>120%</td><td><strong>10,562,642원</strong></td></tr>
          </table>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="footer">
      <span>* 도시근로자 가구당 월평균소득 기준 (세전) | 출처: LH 입주자모집공고 / 2026.8.3. 기준</span>
    </div>
  </div>

</body>
</html>
"""

# 3. 우선공급 순위 플로우차트 HTML (완벽 픽셀 밀착)
HTML_INFO3 = """<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>나는 몇 순위일까? 우선공급 기준 한눈에</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@500;700;900&display=swap" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 800px;
      background-color: #F8F9FA;
      font-family: 'Pretendard', 'Noto Sans KR', sans-serif;
      margin: 0;
      padding: 0;
    }
    
    .container {
      width: 800px;
      display: flex;
      flex-direction: column;
      justify-content: flex-start;
      background-color: #F8F9FA;
    }

    /* Header (H=38px) */
    .header {
      background-color: #1F5ADB;
      height: 38px;
      padding: 0 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      z-index: 10;
    }
    .header h1 {
      font-size: 15px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: -0.5px;
    }
    .badge-top {
      background-color: #F5A623;
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 900;
      padding: 2px 7px;
      border-radius: 4px;
      white-space: nowrap;
    }

    /* Content Area */
    .content {
      padding: 8px 14px;
      display: flex;
      flex-direction: column;
      gap: 5px;
    }

    .ranks-grid {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr;
      gap: 8px;
      width: 100%;
    }

    .rank-card {
      border-radius: 6px;
      padding: 6px 8px;
      border: 1.5px solid;
      display: flex;
      flex-direction: column;
      gap: 3px;
      font-size: 9.6px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.02);
    }
    .rank-1 { background-color: #EAF0FB; border-color: #1F5ADB; color: #1E293B; }
    .rank-2 { background-color: #FEF3E2; border-color: #FCD34D; color: #1E293B; }
    .rank-3 { background-color: #F1F5F9; border-color: #CBD5E1; color: #334155; }

    .rank-title {
      font-size: 11px;
      font-weight: 900;
      border-bottom: 1.5px solid;
      padding-bottom: 2px;
      display: flex;
      justify-content: space-between;
    }
    .rank-1 .rank-title { color: #1F5ADB; border-color: #1F5ADB; }
    .rank-2 .rank-title { color: #D97706; border-color: #D97706; }
    .rank-3 .rank-title { color: #475569; border-color: #475569; }

    .notice-box {
      background-color: #FEF9C3;
      border: 1px solid #FDE047;
      border-radius: 4px;
      padding: 3.5px 8px;
      font-size: 9.5px;
      font-weight: 900;
      color: #854D0E;
      text-align: center;
    }

    /* Footer */
    .footer {
      border-top: 1px solid #E2E8F0;
      padding: 4px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 8.2px;
      color: #94A3B8;
      font-weight: 500;
      background-color: #FFFFFF;
    }
  </style>
</head>
<body>

  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1>나는 몇 순위일까? 우선공급 기준 한눈에</h1>
      <div class="badge-top">LH 우선순위</div>
    </div>

    <!-- Content -->
    <div class="content">
      <div class="ranks-grid">
        <!-- 1순위 -->
        <div class="rank-card rank-1">
          <div class="rank-title">
            <span>🥇 [1순위]</span>
          </div>
          <div>• 신혼부부 (혼인 7년 이내)</div>
          <div>• 예비신혼부부 / 6세 이하 자녀 한부모</div>
          <div style="font-weight:900; color:#1F5ADB; margin-top:2px;">(경합 시 배점제 최대 16점)</div>
        </div>

        <!-- 2순위 -->
        <div class="rank-card rank-2">
          <div class="rank-title">
            <span>🥈 [2순위]</span>
          </div>
          <div>• 청년 (만 19~39세)</div>
          <div>• 대학생</div>
          <div style="font-weight:900; color:#D97706; margin-top:2px;">(경합 시 추첨)</div>
        </div>

        <!-- 3순위 -->
        <div class="rank-card rank-3">
          <div class="rank-title">
            <span>🥉 [3순위]</span>
          </div>
          <div>• 6세 이하 자녀 있는 혼인 가구</div>
          <div style="font-weight:900; color:#475569; margin-top:2px;">(경합 시 추첨)</div>
        </div>
      </div>

      <div class="notice-box">
        ⚖️ <strong>1순위 경합 시 배점제(최대 16점)</strong> → 수급자·자녀수·납입횟수·거주기간·장애인·직계존속 부양 항목 합산
      </div>
    </div>

    <!-- Footer -->
    <div class="footer">
      <span>* 출처: LH 입주자모집공고 / 2026.8.3. 기준</span>
    </div>
  </div>

</body>
</html>
"""

def render_image(html_content, filename):
    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context()
        page = context.new_page()
        
        # 1. 큰 높이 뷰포트로 페이지 로딩 후
        page.set_viewport_size({"width": 800, "height": 1000})
        
        temp_path = os.path.abspath(f"temp_{filename}.html")
        with open(temp_path, "w", encoding="utf-8") as f:
            f.write(html_content)
            
        page.goto(f"file:///{temp_path.replace(os.sep, '/')}")
        page.wait_for_timeout(1000)
        
        # 2. .container 요소의 실효 높이(bounding_box['height']) 동적 측정
        container_box = page.locator(".container").bounding_box()
        actual_height = int(container_box["height"]) if container_box else int(page.locator("body").bounding_box()["height"])
        
        # 3. 뷰포트를 딱 맞는 실효 높이 픽셀로 재설정 후 캡처 (단 1px의 허공 유격도 무조건 소거)
        page.set_viewport_size({"width": 800, "height": actual_height})
        page.wait_for_timeout(300)
        
        dest_path = os.path.join(DEST_DIR, filename)
        page.screenshot(path=dest_path, type="png")
        print(f"[성공] {filename} 동적 높이 측정 저장 완료 ({actual_height}px) -> {dest_path}")
        
        if os.path.exists(temp_path):
            os.remove(temp_path)
        browser.close()

def main():
    print("=== 경기남부 청년신혼부부 매입임대리츠 인포그래픽 3종 동적 높이 픽셀 완벽 소거 시작 ===")
    render_image(HTML_INFO1, "infographic-01-timeline.png")
    render_image(HTML_INFO2, "infographic-02-income.png")
    render_image(HTML_INFO3, "infographic-03-priority.png")
    print("=== 모든 가로형 인포그래픽 동적 높이 생성 완료 ===")

if __name__ == "__main__":
    main()
