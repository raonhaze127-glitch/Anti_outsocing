import os
import json
import sys
from playwright.sync_api import sync_playwright
from PIL import Image

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

WATERMARK_TEXT = "@cheongyak_home"
FOOTER_TEXT = "출처: LH 입주자모집공고 / 2026.08.03. 기준"

# --- HTML TEMPLATES (1080 x 1350 px) ---

# S01 Cover
HTML_S01 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background: radial-gradient(circle at 50% 50%, #1F5ADB 0%, #0D1B3E 100%);
      position: relative; overflow: hidden; display: flex; flex-direction: column; justify-content: center; align-items: center;
    }}
    .bg-grid {{
      position: absolute; top: 0; left: 0; right: 0; bottom: 0;
      background-image: linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
                        linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
      background-size: 40px 40px; z-index: 0;
    }}
    .top-badge {{
      background-color: rgba(255, 255, 255, 0.1); color: #FFFFFF; font-size: 24px; font-weight: 700;
      padding: 10px 24px; border-radius: 30px; border: 1px solid rgba(255, 255, 255, 0.2);
      margin-bottom: 40px; letter-spacing: -0.5px; z-index: 10;
    }}
    .main-title {{
      font-size: 80px; font-weight: 800; color: #FFFFFF; line-height: 1.3; text-align: center;
      letter-spacing: -2px; margin-bottom: 30px; text-shadow: 0 4px 12px rgba(0,0,0,0.3); z-index: 10;
      word-break: keep-all; width: 900px;
    }}
    .sub-title {{
      font-size: 60px; font-weight: 800; color: #F5A623; text-align: center;
      letter-spacing: -1px; margin-bottom: 30px; text-shadow: 0 4px 10px rgba(245, 166, 35, 0.2); z-index: 10;
    }}
    .location-badge {{
      font-size: 32px; font-weight: 700; color: #FFFFFF; opacity: 0.9;
      margin-bottom: 50px; z-index: 10; letter-spacing: -0.5px;
    }}
    .cta-button {{
      background-color: #FFFFFF; color: #1F5ADB; font-size: 28px; font-weight: 700;
      padding: 16px 44px; border-radius: 40px; box-shadow: 0 10px 20px rgba(31, 90, 219, 0.3);
      letter-spacing: -0.5px; z-index: 10;
    }}
    .bg-deco-circle {{
      position: absolute; width: 600px; height: 600px; background: radial-gradient(circle, rgba(31, 90, 219, 0.15) 0%, transparent 70%);
      top: -100px; right: -100px; z-index: 1;
    }}
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(255,255,255,0.7); z-index: 20; }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(255,255,255,0.5); z-index: 20; }}
  </style>
</head>
<body>
  <div class="bg-grid"></div>
  <div class="bg-deco-circle"></div>
  <div class="top-badge" id="s01-badge">청약 접수 2026.8.18.~8.20.</div>
  <div class="main-title" id="s01-title">경기남부 청년·신혼부부<br/>매입임대리츠</div>
  <div class="sub-title" id="s01-sub">예비입주자 48세대</div>
  <div class="location-badge">수원·시흥·안산·평택 6개 단지</div>
  <div class="cta-button">상세 조건·임대료 확인하기 ▶</div>
  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S02 Summary
HTML_S02 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #FFFFFF; position: relative; overflow: hidden;
    }}
    .top-chip {{
      position: absolute; top: 80px; left: 60px; background-color: #EAF0FB; color: #1F5ADB;
      font-size: 22px; font-weight: 700; padding: 8px 20px; border-radius: 20px;
    }}
    .section-title {{
      position: absolute; top: 160px; left: 60px; font-size: 52px; font-weight: 700; color: #0D1B3E;
    }}
    
    .info-list {{
      position: absolute; top: 270px; left: 60px; width: 960px; display: flex; flex-direction: column; gap: 16px;
    }}
    .info-row {{
      background-color: #F8F9FA; border: 1.5px solid #E2E8F0; border-radius: 16px; padding: 22px 30px;
      display: flex; justify-content: space-between; align-items: center; font-size: 28px;
    }}
    .info-label {{ font-weight: 700; color: #555555; }}
    .info-val {{ font-weight: 800; color: #0D1B3E; }}
    .hl-blue {{ color: #1F5ADB; }}
    
    .alert-box {{
      position: absolute; top: 800px; left: 60px; width: 960px; height: 200px;
      background-color: #FEF2F2; border-left: 6px solid #EF4444; border-radius: 4px 20px 20px 4px;
      padding: 30px 40px; display: flex; flex-direction: column; justify-content: center; gap: 8px;
      box-shadow: 0 10px 20px rgba(239, 68, 68, 0.03);
    }}
    .alert-title {{ font-size: 26px; font-weight: 800; color: #EF4444; }}
    .alert-desc {{ font-size: 24px; color: #555555; line-height: 1.45; font-weight: 600; }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(85,85,85,0.7); }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(85,85,85,0.5); }}
  </style>
</head>
<body>
  <div class="top-chip" id="s02-chip">공고 정보</div>
  <div class="section-title" id="s02-title">이 공고, 핵심만 먼저 볼게요</div>
  
  <div class="info-list">
    <div class="info-row">
      <span class="info-label">📍 공급 지역</span>
      <span class="info-val">수원 · 시흥 · 안산 · 평택</span>
    </div>
    <div class="info-row">
      <span class="info-label">🏢 공급 규모</span>
      <span class="info-val">6개 단지 / 전용 <span class="hl-blue">59㎡</span> (단일)</span>
    </div>
    <div class="info-row">
      <span class="info-label">👥 모집 인원</span>
      <span class="info-val">예비입주자 <span class="hl-blue">48세대</span></span>
    </div>
    <div class="info-row">
      <span class="info-label">📅 신청 기간</span>
      <span class="info-val">8.18.(화) 10:00 ~ 8.20.(목) 18:00</span>
    </div>
    <div class="info-row">
      <span class="info-label">💻 신청 방법</span>
      <span class="info-val">LH청약플러스 (인터넷 / 모바일)</span>
    </div>
  </div>

  <div class="alert-box">
    <div class="alert-title">⚠️ 공가 없음 주의</div>
    <div class="alert-desc">현재 공가는 없는 상태이며, 당첨되어도 바로 계약 및 입주를 보장하지 않는 예비입주자 모집 공고입니다.</div>
  </div>

  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S03 Eligibility
HTML_S03 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #FFFFFF; position: relative; overflow: hidden;
    }}
    .top-chip {{
      position: absolute; top: 80px; left: 60px; background-color: #EAF0FB; color: #1F5ADB;
      font-size: 22px; font-weight: 700; padding: 8px 20px; border-radius: 20px;
    }}
    .section-title {{
      position: absolute; top: 160px; left: 60px; font-size: 52px; font-weight: 700; color: #0D1B3E;
    }}
    .section-sub {{
      position: absolute; top: 240px; left: 60px; font-size: 26px; font-weight: 700; color: #1F5ADB;
    }}
    
    .stack-container {{
      position: absolute; top: 310px; left: 60px; width: 960px; display: flex; flex-direction: column; gap: 20px;
    }}
    .rank-card {{
      border-radius: 20px; padding: 24px 30px; display: flex; flex-direction: column; gap: 8px;
    }}
    .rank-card-blue {{ background-color: #EAF0FB; }}
    .rank-card-gray {{ background-color: #F8F9FA; }}
    .rank-title {{ font-size: 28px; font-weight: 800; color: #0D1B3E; }}
    .rank-desc {{ font-size: 24px; color: #555555; line-height: 1.4; }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(85,85,85,0.7); }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(85,85,85,0.5); }}
  </style>
</head>
<body>
  <div class="top-chip" id="s03-chip">신청 자격</div>
  <div class="section-title" id="s03-title">나는 몇 순위로 신청할까?</div>
  <div class="section-sub" id="s03-sub">공통 조건: 무주택세대구성원 · 도시근로자 월평균소득 기준 충족</div>
  
  <div class="stack-container">
    <div class="rank-card rank-card-blue" style="height: 180px;">
      <div class="rank-title" style="color: #1F5ADB;">🥇 1순위 (신혼부부형)</div>
      <div class="rank-desc">• 혼인 7년 이내 신혼부부 / 예비신혼부부<br/>• 만 6세 이하 자녀를 둔 한부모가족</div>
    </div>
    <div class="rank-card rank-card-gray" style="height: 180px;">
      <div class="rank-title">🥈 2순위 (청년형)</div>
      <div class="rank-desc">• 만 19세 이상 ~ 39세 이하 청년<br/>• 대학생 (입학예정자 포함)</div>
    </div>
    <div class="rank-card rank-card-blue" style="height: 180px;">
      <div class="rank-title" style="color: #1F5ADB;">🥉 3순위 (일반 가구형)</div>
      <div class="rank-desc">• 만 6세 이하 자녀가 있는 혼인 가구<br/>• 1순위 요건에 해당하지 않는 가구</div>
    </div>
  </div>

  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S04 Income
HTML_S04 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #0D1B3E; position: relative; overflow: hidden;
    }}
    .top-chip {{
      position: absolute; top: 80px; left: 60px; background-color: #F5A623; color: #0D1B3E;
      font-size: 22px; font-weight: 700; padding: 8px 20px; border-radius: 20px;
    }}
    .section-title {{
      position: absolute; top: 160px; left: 60px; font-size: 52px; font-weight: 700; color: #FFFFFF;
    }}
    
    .panel-income {{
      position: absolute; left: 60px; width: 960px; background-color: #1A3A6B; border-radius: 24px;
      padding: 24px 30px; display: flex; flex-direction: column; gap: 14px;
    }}
    .panel-header {{
      font-size: 26px; font-weight: 700; color: #FFFFFF; border-bottom: 2px solid #1F5ADB; padding-bottom: 8px;
    }}
    .panel-header span {{ color: #F5A623; }}
    .inc-row {{
      display: flex; justify-content: space-between; align-items: center; font-size: 28px; color: #FFFFFF;
    }}
    .inc-val {{ font-size: 32px; font-weight: 800; color: #F5A623; }}
    
    .bottom-note {{
      position: absolute; top: 1010px; width: 1080px; text-align: center; font-size: 24px; color: #888888;
    }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(255,255,255,0.7); }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(255,255,255,0.5); }}
  </style>
</head>
<body>
  <div class="top-chip" id="s04-chip">소득 기준</div>
  <div class="section-title" id="s04-title">소득 기준은 얼마까지?</div>
  
  <!-- Single income 100% -->
  <div class="panel-income" style="top: 270px; height: 350px;">
    <div class="panel-header">외벌이·단독 가구 (월평균소득 100% 이하)</div>
    <div class="inc-row"><span>1인 가구</span><span class="inc-val">4,576,036원 이하</span></div>
    <div class="inc-row"><span>2인 가구</span><span class="inc-val">6,452,897원 이하</span></div>
    <div class="inc-row"><span>3인 가구</span><span class="inc-val">8,168,429원 이하</span></div>
    <div class="inc-row"><span>4인 가구</span><span class="inc-val">8,802,202원 이하</span></div>
  </div>

  <!-- Double income -->
  <div class="panel-income" style="top: 640px; height: 310px;">
    <div class="panel-header">맞벌이 가구 소득 제한 기준</div>
    <div class="inc-row"><span>2인 맞벌이 (130%)</span><span class="inc-val">7,626,751원 이하</span></div>
    <div class="inc-row"><span>3인 맞벌이 (120%)</span><span class="inc-val">9,802,115원 이하</span></div>
    <div class="inc-row"><span>4인 맞벌이 (120%)</span><span class="inc-val">10,562,642원 이하</span></div>
  </div>

  <div class="bottom-note" id="s04-note">💡 세대 전원(성년자)의 세전 월소득을 합산하여 판정합니다.</div>
  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S05 Terms
HTML_S05 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #FFFFFF; position: relative; overflow: hidden;
    }}
    .top-chip {{
      position: absolute; top: 80px; left: 60px; background-color: #EAF0FB; color: #1F5ADB;
      font-size: 22px; font-weight: 700; padding: 8px 20px; border-radius: 20px;
    }}
    .section-title {{
      position: absolute; top: 160px; left: 60px; font-size: 52px; font-weight: 700; color: #0D1B3E; line-height: 1.25;
    }}
    
    .table-container {{
      position: absolute; top: 290px; left: 60px; width: 960px; height: 500px;
      background-color: #F8F9FA; border: 1.5px solid #E2E8F0; border-radius: 20px; padding: 10px 24px;
    }}
    table {{ width: 100%; border-collapse: collapse; text-align: left; }}
    th {{ font-size: 24px; font-weight: 800; color: #1F5ADB; padding: 18px 0; border-bottom: 2px solid #1F5ADB; }}
    td {{ font-size: 22px; font-weight: 600; color: #1A1A1A; padding: 14px 0; border-bottom: 1px solid #E2E8F0; }}
    tr:last-child td {{ border-bottom: none; }}
    .col-right {{ text-align: right; }}
    
    .alert-box {{
      position: absolute; top: 820px; left: 60px; width: 960px; height: 150px;
      background-color: #FEF2F2; border-left: 6px solid #EF4444; border-radius: 4px 16px 16px 4px;
      padding: 24px 30px; display: flex; align-items: center; gap: 20px;
      box-shadow: 0 10px 20px rgba(239,68,68,0.02);
    }}
    .alert-icon {{ font-size: 40px; }}
    .alert-text {{ font-size: 26px; color: #EF4444; font-weight: 700; }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(85,85,85,0.7); }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(85,85,85,0.5); }}
  </style>
</head>
<body>
  <div class="top-chip" id="s05-chip">임대 조건</div>
  <div class="section-title" id="s05-title">보증금과 월임대료는 단지마다 달라요</div>
  
  <div class="table-container">
    <table>
      <thead>
        <tr>
          <th>단지명 (수원·시흥·안산·평택)</th>
          <th class="col-right">보증금</th>
          <th class="col-right">월 임대료</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>권선신일유토빌</td>
          <td class="col-right">1.19억 ~ 1.21억 원</td>
          <td class="col-right">29.3만 ~ 31.0만 원</td>
        </tr>
        <tr>
          <td>호매실더센트라고 (1)</td>
          <td class="col-right">1.43억 원</td>
          <td class="col-right">28.6만 원</td>
        </tr>
        <tr>
          <td>시흥6차푸르지오 1단지</td>
          <td class="col-right">1.275억 원</td>
          <td class="col-right">10.3만 원</td>
        </tr>
        <tr>
          <td>안산8차푸르지오 (1)</td>
          <td class="col-right">1.31억 ~ 1.33억 원</td>
          <td class="col-right">11.6만 ~ 13.4만 원</td>
        </tr>
        <tr>
          <td>서재자이아파트</td>
          <td class="col-right">1.17억 ~ 1.27억 원</td>
          <td class="col-right">10.1만 ~ 17.3만 원</td>
        </tr>
        <tr>
          <td>비전경남아너스빌</td>
          <td class="col-right">1.17억 원</td>
          <td class="col-right">4.4만 원</td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="alert-box">
    <span class="alert-icon">❌</span>
    <span class="alert-text">보증금과 월임대료 상호전환은 불가능합니다.</span>
  </div>

  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S06 Notices
HTML_S06 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #FFFFFF; position: relative; overflow: hidden;
    }}
    .top-chip {{
      position: absolute; top: 80px; left: 60px; background-color: #FEF3E2; color: #C47A00;
      font-size: 22px; font-weight: 700; padding: 8px 20px; border-radius: 20px;
    }}
    .section-title {{
      position: absolute; top: 160px; left: 60px; font-size: 52px; font-weight: 700; color: #0D1B3E;
    }}
    
    .list-container {{
      position: absolute; top: 270px; left: 60px; width: 960px; display: flex; flex-direction: column; gap: 14px;
    }}
    .list-item {{
      background-color: #F8F9FA; border-left: 6px solid #F5A623; border-radius: 4px 16px 16px 4px;
      padding: 24px 30px; display: flex; flex-direction: column; gap: 8px;
    }}
    .item-title {{ font-size: 28px; font-weight: 700; color: #0D1B3E; }}
    .item-desc {{ font-size: 24px; color: #555555; line-height: 1.45; }}
    .hl-orange {{ color: #F5A623; font-weight: 800; }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(85,85,85,0.7); }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(85,85,85,0.5); }}
  </style>
</head>
<body>
  <div class="top-chip" id="s06-chip">주의 사항</div>
  <div class="section-title" id="s06-title">신청 전 꼭 알아야 할 5가지</div>
  
  <div class="list-container">
    <div class="list-item">
      <div class="item-title">1. 바로 입주하는 공고가 아님</div>
      <div class="item-desc">현재 거주 중인 입주자가 퇴거해 공가가 발생해야 순번에 따라 계약이 이뤄집니다.</div>
    </div>
    <div class="list-item">
      <div class="item-title">2. 잔여 임대기간은 단지별 2~5년</div>
      <div class="item-desc">단지별 최초 입주 시기가 달라 남은 임대 계약 보장 기간이 다릅니다.</div>
    </div>
    <div class="list-item">
      <div class="item-title">3. 보증금-임대료 전환 불가</div>
      <div class="item-desc">영구임대와 달리 전환 제도가 적용되지 않아 공고 조건 그대로 유지하셔야 합니다.</div>
    </div>
    <div class="list-item">
      <div class="item-title">4. 중복 신청은 전부 무효 처리</div>
      <div class="item-desc">동일인이 복수 단지에 신청하거나 부부가 각각 중복 신청하는 경우 모두 자동 무효 처리됩니다.</div>
    </div>
    <div class="list-item">
      <div class="item-title">5. 서류 제출은 오직 등기우편만</div>
      <div class="item-desc">우체국 등기우편만 접수하며, <span class="hl-orange">2026년 8월 28일 우체국 소인분</span>까지만 정상 접수됩니다.</div>
    </div>
  </div>

  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

# S07 Schedule & Checklist
HTML_S07 = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.css" />
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: 'Pretendard', sans-serif; }}
    body {{
      width: 1080px; height: 1350px; background-color: #1F5ADB; position: relative; overflow: hidden;
    }}
    .bg-icon {{
      position: absolute; right: -80px; bottom: -80px; width: 600px; height: 600px; opacity: 0.08; z-index: 1;
    }}
    .section-title {{
      position: absolute; top: 100px; left: 60px; font-size: 52px; font-weight: 700; color: #FFFFFF;
    }}
    
    .panel-schedule {{
      position: absolute; top: 220px; left: 60px; width: 960px; height: 310px;
      background-color: rgba(255, 255, 255, 0.1); border-radius: 20px; padding: 24px 30px;
      display: flex; flex-direction: column; gap: 10px; z-index: 10;
      border: 1.5px solid rgba(255, 255, 255, 0.15);
    }}
    .sched-h {{ font-size: 26px; font-weight: 700; color: #F5A623; margin-bottom: 6px; }}
    .sched-item {{ font-size: 24px; color: #FFFFFF; display: flex; justify-content: space-between; }}
    .sched-val {{ font-weight: 700; }}
    
    .panel-checklist {{
      position: absolute; top: 560px; left: 60px; width: 960px; height: 350px;
      background-color: rgba(255, 255, 255, 0.1); border-radius: 20px; padding: 24px 30px;
      display: flex; flex-direction: column; gap: 12px; z-index: 10;
      border: 1.5px solid rgba(255, 255, 255, 0.15);
    }}
    .check-h {{ font-size: 26px; font-weight: 700; color: #F5A623; margin-bottom: 6px; }}
    .check-row {{ font-size: 22px; color: #FFFFFF; display: flex; align-items: center; gap: 12px; }}
    
    .link-note {{
      position: absolute; top: 940px; width: 1080px; text-align: center;
      font-size: 28px; font-weight: 700; color: #F5A623; z-index: 10;
      line-height: 1.4; padding: 0 60px;
    }}
    
    .watermark {{ position: absolute; right: 60px; bottom: 40px; font-size: 14px; color: rgba(255,255,255,0.7); z-index: 20; }}
    .footer {{ position: absolute; left: 60px; bottom: 40px; font-size: 12px; color: rgba(255,255,255,0.5); z-index: 20; }}
  </style>
</head>
<body>
  <svg class="bg-icon" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>
  
  <div class="section-title" id="s07-title">청약 전 이것만 체크하세요</div>
  
  <!-- Schedule -->
  <div class="panel-schedule">
    <div class="sched-h">📅 청약 핵심 일정</div>
    <div class="sched-item"><span>청약 접수</span><span class="sched-val">8.18.(화) ~ 8.20.(목) 18:00</span></div>
    <div class="sched-item"><span>서류대상자 발표</span><span class="sched-val">8.21.(금) 16:00 이후</span></div>
    <div class="sched-item"><span>서류 제출 접수</span><span class="sched-val">8.24.(월) ~ 8.28.(금) 등기우편</span></div>
    <div class="sched-item"><span>예비순번 발표</span><span class="sched-val">10.23.(금) 16:00 이후</span></div>
  </div>

  <!-- Checklist -->
  <div class="panel-checklist">
    <div class="check-h">✔️ 청약 체크리스트</div>
    <div class="check-row">⬜ 무주택세대구성원 유지 및 자격 확인</div>
    <div class="check-row">⬜ 가구원 수별 소득 한도 기준 충족 확인</div>
    <div class="check-row">⬜ 6개 단지 중 단 1곳만 선택 완료</div>
    <div class="check-row">⬜ 동일 세대원/부부 중 1명만 청약 신청</div>
    <div class="check-row">⬜ 단지별 잔여 임대기간 (2~5년) 및 전환 불가 조건 동의</div>
  </div>
  
  <div class="link-note" id="s07-cta">
    단지별 전체 조건표·배점표·공식 공고 링크는<br/>프로필 링크 블로그에서 즉시 확인하세요!
  </div>
  
  <div class="watermark">{WATERMARK_TEXT}</div>
  <div class="footer">{FOOTER_TEXT}</div>
</body>
</html>
"""

SLIDES = [
    {"name": "carousel-gyeonggi-reits-01-cover.png", "html": HTML_S01, "validators": {"badge": ("#s01-badge", "청약 접수"), "title": ("#s01-title", "경기남부"), "sub": ("#s01-sub", "48세대")}},
    {"name": "carousel-gyeonggi-reits-02-summary.png", "html": HTML_S02, "validators": {"chip": ("#s02-chip", "공고 정보"), "title": ("#s02-title", "핵심만")}},
    {"name": "carousel-gyeonggi-reits-03-eligibility.png", "html": HTML_S03, "validators": {"chip": ("#s03-chip", "신청 자격"), "title": ("#s03-title", "몇 순위로")}},
    {"name": "carousel-gyeonggi-reits-04-income.png", "html": HTML_S04, "validators": {"chip": ("#s04-chip", "소득 기준"), "title": ("#s04-title", "얼마까지"), "note": ("#s04-note", "월소득")}},
    {"name": "carousel-gyeonggi-reits-05-terms.png", "html": HTML_S05, "validators": {"chip": ("#s05-chip", "임대 조건"), "title": ("#s05-title", "보증금과")}},
    {"name": "carousel-gyeonggi-reits-06-notices.png", "html": HTML_S06, "validators": {"chip": ("#s06-chip", "주의 사항"), "title": ("#s06-title", "5가지")}},
    {"name": "carousel-gyeonggi-reits-07-schedule-check.png", "html": HTML_S07, "validators": {"title": ("#s07-title", "체크하세요"), "cta": ("#s07-cta", "블로그")}},
]

def main():
    print("=== 경기남부 매입임대리츠 캐러셀 7장 생성 및 검증 시작 ===")
    validation_report = {}
    
    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context()
        
        for item in SLIDES:
            name = item["name"]
            html_content = item["html"]
            validators = item["validators"]
            
            print(f"\n[작업 시작] {name} (1080 x 1350)")
            page = context.new_page()
            page.set_viewport_size({"width": 1080, "height": 1350})
            
            temp_html_path = os.path.abspath(f"temp_{name.replace('.png', '.html')}")
            with open(temp_html_path, "w", encoding="utf-8") as f:
                f.write(html_content)
                
            page.goto(f"file:///{temp_html_path.replace(os.sep, '/')}")
            page.wait_for_timeout(1500)
            
            item_report = {}
            all_valid = True
            
            print(f"[{name} 데이터 검증]")
            for key, (selector, expected) in validators.items():
                element = page.locator(selector)
                if element.count() > 0:
                    text = element.text_content().strip()
                    match = "".join(expected.split()) in "".join(text.split())
                    status = "통과" if match else "실패"
                    if not match:
                        all_valid = False
                    item_report[key] = {"selector": selector, "expected": expected, "actual": text, "status": status}
                    print(f" - {key}: '{text}' vs '{expected}' -> {status}")
                else:
                    all_valid = False
                    item_report[key] = {"selector": selector, "expected": expected, "actual": "없음", "status": "실패"}
                    print(f" - {key}: 요소를 찾을 수 없음 -> 실패")
                    
            output_path = os.path.join(os.getcwd(), name)
            page.screenshot(path=output_path, type="png")
            print(f" -> 이미지 저장 완료: {output_path}")
            
            img_valid = False
            if os.path.exists(output_path):
                with Image.open(output_path) as img:
                    w, h = img.size
                    if w == 1080 and h == 1350 and img.format == "PNG":
                        img_valid = True
                        print(f" -> 규격 확인: {w}x{h} (포맷: {img.format}) - 통과")
                    else:
                        print(f" -> 규격 확인: {w}x{h} (포맷: {img.format}) - 실패")
                        
            validation_report[name] = {"data_valid": all_valid, "file_valid": img_valid, "details": item_report}
            if os.path.exists(temp_html_path):
                os.remove(temp_html_path)
            page.close()
            
        browser.close()
        
    report_path = os.path.join(os.getcwd(), "reits_carousel_verification_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(validation_report, f, ensure_ascii=False, indent=2)
        
    print(f"\n=== 검증 리포트 저장 완료: {report_path} ===")
    all_success = all(r["data_valid"] and r["file_valid"] for r in validation_report.values())
    if all_success:
        print("\n[SUCCESS] 경기남부 매입임대리츠 캐러셀 7장이 완벽하게 생성되었으며 검증을 통과했습니다!")
    else:
        print("\n[WARNING] 검증 중 실패 항목이 존재합니다.")

if __name__ == "__main__":
    main()
