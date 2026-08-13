import os
import sys
import base64
from playwright.sync_api import sync_playwright

# Windows 콘솔 인코딩 문제 해결
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

DEST_DIR = r"C:\Users\nahah\Desktop\Anti_outsocing"
OUTPUT_FILENAME = "2026-08-03_청년신혼부부매입임대리츠경기남부_thumb.jpg"

# 로컬 이미지를 Base64로 인코딩
with open("youth_reits_gyeonggi_south_bg.jpg", "rb") as image_file:
    base64_data = base64.b64encode(image_file.read()).decode('utf-8')

HTML_THUMBNAIL = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>청년·신혼부부 매입임대리츠 경기남부 썸네일</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;700;900&display=swap" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      width: 1600px;
      height: 900px;
      background-image: url('data:image/jpeg;base64,{base64_data}');
      background-size: cover;
      background-position: center;
      position: relative;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
      font-family: 'Pretendard', 'Noto Sans KR', sans-serif;
    }}
    
    /* Dark Overlay (#0D1B3E, 65% opacity) */
    .overlay {{
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(13, 27, 62, 0.65);
      z-index: 1;
    }}
    
    /* Background Grid Pattern */
    .bg-grid {{
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      background-image: linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
                        linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
      background-size: 40px 40px;
      z-index: 2;
    }}

    /* 1:1 Center Safe Area (900px wide, starting at left: 350px) */
    .safe-area {{
      position: absolute;
      left: 350px;
      top: 0;
      width: 900px;
      height: 900px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: center; /* Center-aligned content */
      padding: 100px 20px;
      z-index: 3;
      border-left: 1px dashed rgba(255, 255, 255, 0.06);
      border-right: 1px dashed rgba(255, 255, 255, 0.06);
    }}

    /* Top Row Badges */
    .top-row {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 100%;
    }}
    .badge-agency {{
      background-color: #F5A623;
      color: #FFFFFF;
      font-size: 32px;
      font-weight: 900;
      padding: 8px 24px;
      border-radius: 8px;
      box-shadow: 0 4px 15px rgba(245, 166, 35, 0.25);
    }}
    .badge-status {{
      background-color: #555555;
      color: #FFFFFF;
      font-size: 32px;
      font-weight: 900;
      padding: 8px 24px;
      border-radius: 8px;
      box-shadow: 0 4px 15px rgba(85, 85, 85, 0.25);
    }}

    /* Center Content Group */
    .center-group {{
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 18px;
      margin-top: -10px;
    }}
    .title-main {{
      font-size: 74px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: -2px;
      text-shadow: 0 4px 15px rgba(0, 0, 0, 0.5);
      white-space: nowrap;
      max-width: 860px;
    }}
    .highlight-stats {{
      font-size: 92px;
      font-weight: 900;
      color: #F5A623;
      letter-spacing: -2px;
      text-shadow: 0 4px 20px rgba(245, 166, 35, 0.25);
      white-space: nowrap;
      max-width: 860px;
    }}
    .sub-text {{
      font-size: 44px;
      font-weight: 900;
      color: #FFFFFF;
      letter-spacing: -1px;
      text-shadow: 0 3px 12px rgba(0, 0, 0, 0.4);
      white-space: nowrap;
      max-width: 860px;
    }}

    /* Bottom Info Date/Criteria */
    .bottom-info {{
      font-size: 32px;
      font-weight: 400;
      color: #FFFFFF;
      letter-spacing: -0.5px;
      text-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
    }}
  </style>
</head>
<body>
  <!-- Background patterns & gradient -->
  <div class="overlay"></div>
  <div class="bg-grid"></div>

  <!-- Center Aligned Safe Area -->
  <div class="safe-area">
    <!-- Top Row Badges -->
    <div class="top-row">
      <div class="badge-agency">LH</div>
      <div class="badge-status">예비입주자 모집</div>
    </div>
    
    <!-- Center Content Group -->
    <div class="center-group">
      <div class="title-main">청년·신혼부부 매입임대리츠</div>
      <div class="highlight-stats">예비 48세대</div>
      <div class="sub-text">경기남부 수원·시흥·안산·평택</div>
    </div>
    
    <!-- Bottom Info -->
    <div class="bottom-info">
      2026.8.3. 공고 기준
    </div>
  </div>
</body>
</html>
"""

def main():
    print(f"=== {OUTPUT_FILENAME} 생성 시작 (우측 상단 '예비입주자 모집') ===")
    
    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context()
        page = context.new_page()
        page.set_viewport_size({"width": 1600, "height": 900})
        
        temp_html_path = os.path.abspath("temp_thumbnail_youth_reits_gyeonggi_south.html")
        with open(temp_html_path, "w", encoding="utf-8") as f:
            f.write(HTML_THUMBNAIL)
            
        page.goto(f"file:///{temp_html_path.replace(os.sep, '/')}")
        page.wait_for_timeout(2000)
        
        dest_path = os.path.join(DEST_DIR, OUTPUT_FILENAME)
        page.screenshot(path=dest_path, type="jpeg", quality=95)
        print(f"[결과] 이미지 저장 완료 -> {dest_path}")
        
        if os.path.exists(temp_html_path):
            os.remove(temp_html_path)
            
        browser.close()
        
    print("\n[성공] 청년·신혼부부 매입임대리츠 경기남부 썸네일 수치가 완료되었습니다.")

if __name__ == "__main__":
    main()
