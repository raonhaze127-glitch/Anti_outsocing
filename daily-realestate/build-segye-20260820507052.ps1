$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root 'output\2026-08-22\segye-20260820507052-carousel'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$sourceUrl = 'https://www.segye.com/newsView/20260820507052'

function Encode-Html([string]$value) { [System.Net.WebUtility]::HtmlEncode($value) }

$slides = @(
  @{type='cover question'; tag='광명 재건축 체크'; title="용적률 늘었는데`n분담금은 왜 오를까?"; sub='철산·하안 재건축에 새 변수가 생겼습니다'},
  @{type='cover benefit'; tag='조합원이 확인할 4가지'; title="공공임대·공사비·`n일반분양·사업일정"; sub='광명시 공문이 재건축 사업성에 미치는 영향'},
  @{type='timeline'; tag='무슨 일이 있었나'; title='광명시가 공문을 보냈습니다'; steps=@(@('8월 19일','재건축 조합·추진위 등에 일괄 발송'),@('요청 내용','정비계획에 공공임대주택 적극 반영'),@('적용 대상','철산·하안 재건축 정비사업'))},
  @{type='compare'; tag='왜 요구하나'; title='추가 용적률 ↔ 공공기여'; left=@('도시계획 혜택','법정 기준을 넘는 중첩용적률','사업성·개발이익 확대'); right=@('공공의 요구','공공임대주택 공급','제로에너지건축물 조성')},
  @{type='flow'; tag='분담금 영향 구조'; title='조합의 셈법이 복잡해진 이유'; flow=@('공공임대 확대','일반분양 물량 감소','ZEB·공사비 부담','추가분담금 압력')},
  @{type='stats'; tag='시장 흐름에 등장한 새 변수'; title='신고가 흐름 속 공문이 나왔습니다'; sub="정비구역 지정 기대감으로 최고가 거래가 이어지던 상황에서`n공공임대 반영 요청이 향후 사업성의 변수로 등장했습니다"; stats=@(@('9억 5,000만원','하안주공 12단지 59㎡','7월 16일경 신고가'),@('7억 5,500만원','하안주공 11단지 49㎡','7월 21일경 신고가'))},
  @{type='summary'; tag='핵심 요약'; title='철산·하안 재건축 체크리스트'; rows=@(@('현재 단계','공공임대 반영 요청 공문 발송'),@('핵심 변수','일반분양 감소·ZEB 비용'),@('가능한 영향','분담금 증가·계획 수정·일정 지연'),@('확인할 것','정비계획 반영 수준과 조합 추산'))},
  @{type='cta'; tag='다시 확인하세요'; title="정비계획이 바뀌면`n분담금도 달라집니다"; sub="일정과 사업성 변경을 놓치지 않도록`n저장하고, 철산·하안 재건축을 기다리는 분과 공유하세요"}
)

$css = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic",sans-serif;color:#0D1B3E}.slide{width:1080px;height:1350px;position:relative;padding:170px 150px 150px;display:flex;flex-direction:column;justify-content:center;align-items:center;background:linear-gradient(145deg,#fff,#EAF0FB)}.slide:before{content:"";position:absolute;inset:0 0 auto;height:22px;background:#1F5ADB}.tag{font-size:25px;font-weight:850;color:#fff;background:#1F5ADB;border-radius:999px;padding:13px 25px;margin-bottom:34px;text-align:center}.title{font-size:58px;line-height:1.22;font-weight:900;letter-spacing:-2.2px;text-align:center;word-break:keep-all;max-width:780px;white-space:pre-line}.sub{font-size:29px;line-height:1.45;font-weight:650;color:#555;text-align:center;margin-top:30px;max-width:780px;white-space:pre-line}.foot{position:absolute;left:150px;right:150px;bottom:45px;display:flex;justify-content:space-between;font-size:20px;color:#64748B}.cover{background:#0D1B3E;color:#fff}.cover:before{background:#F5A623}.cover .tag{background:#F5A623}.cover .title{font-size:70px}.cover .sub,.cover .foot{color:#fff}.cover:after{content:"";position:absolute;width:520px;height:520px;border:90px solid rgba(31,90,219,.22);border-radius:50%;right:-180px;bottom:-170px}.benefit{background:#1F5ADB}.benefit:after{border-color:rgba(245,166,35,.26)}.timeline-wrap{width:780px;margin-top:38px;display:flex;flex-direction:column;gap:18px}.step{display:grid;grid-template-columns:170px 1fr;align-items:center;background:#fff;border-radius:20px;padding:25px 28px;box-shadow:0 10px 28px rgba(13,27,62,.08)}.step strong{font-size:28px;color:#1F5ADB}.step span{font-size:27px;font-weight:700;line-height:1.35}.compare-grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;width:780px;margin-top:38px}.panel{background:#fff;border-radius:22px;padding:30px 26px;min-height:310px}.panel.orange{border-top:10px solid #F5A623}.panel.blue{border-top:10px solid #1F5ADB}.panel h3{font-size:31px;margin:0 0 22px;text-align:center}.panel p{font-size:25px;line-height:1.5;font-weight:650;margin:12px 0;text-align:center}.flow-wrap{display:flex;align-items:stretch;width:780px;margin-top:42px;gap:8px}.flow-item{flex:1;background:#fff;border-radius:18px;padding:28px 14px;display:flex;align-items:center;justify-content:center;text-align:center;font-size:24px;line-height:1.3;font-weight:800;border:2px solid #D9E4F7}.arrow{display:flex;align-items:center;font-size:28px;color:#F5A623;font-weight:900}.stats-grid{display:grid;grid-template-columns:1fr 1fr;gap:20px;width:780px;margin-top:40px}.stat{background:#fff;border-radius:22px;padding:34px 28px;text-align:center;border:2px solid #D9E4F7}.stat strong{display:block;font-size:42px;color:#1F5ADB}.stat span{display:block;font-size:25px;font-weight:750;margin-top:17px;line-height:1.4}.stat em{display:block;font-size:22px;color:#777;font-style:normal;margin-top:12px}.summary-table{width:780px;margin-top:36px;background:#fff;border-radius:22px;overflow:hidden}.row{display:grid;grid-template-columns:190px 1fr;border-bottom:2px solid #EAF0FB}.row:last-child{border-bottom:0}.row strong{background:#EAF0FB;padding:24px;font-size:25px;color:#1F5ADB}.row span{padding:24px;font-size:25px;line-height:1.35;font-weight:700}.cta{background:#1F5ADB;color:#fff}.cta:before{background:#F5A623}.cta .tag{background:#F5A623}.cta .sub,.cta .foot{color:#fff}
'@

for($i=0;$i -lt $slides.Count;$i++){
  $s=$slides[$i];$body="<div class='tag'>$(Encode-Html $s.tag)</div><div class='title'>$((Encode-Html $s.title)-replace "`n",'<br>')</div>"
  if($s.sub){$body+="<div class='sub'>$((Encode-Html $s.sub)-replace "`n",'<br>')</div>"}
  if($s.steps){$body+='<div class="timeline-wrap">';foreach($x in $s.steps){$body+="<div class='step'><strong>$(Encode-Html $x[0])</strong><span>$(Encode-Html $x[1])</span></div>"};$body+='</div>'}
  if($s.left){$body+='<div class="compare-grid"><div class="panel blue">';$body+="<h3>$(Encode-Html $s.left[0])</h3>";foreach($x in $s.left[1..($s.left.Count-1)]){$body+="<p>$(Encode-Html $x)</p>"};$body+='</div><div class="panel orange">';$body+="<h3>$(Encode-Html $s.right[0])</h3>";foreach($x in $s.right[1..($s.right.Count-1)]){$body+="<p>$(Encode-Html $x)</p>"};$body+='</div></div>'}
  if($s.flow){$body+='<div class="flow-wrap">';for($j=0;$j -lt $s.flow.Count;$j++){$body+="<div class='flow-item'>$(Encode-Html $s.flow[$j])</div>";if($j-lt$s.flow.Count-1){$body+='<div class="arrow">→</div>'}};$body+='</div>'}
  if($s.stats){$body+='<div class="stats-grid">';foreach($x in $s.stats){$body+="<div class='stat'><strong>$(Encode-Html $x[0])</strong><span>$(Encode-Html $x[1])</span><em>$(Encode-Html $x[2])</em></div>"};$body+='</div>'}
  if($s.rows){$body+='<div class="summary-table">';foreach($x in $s.rows){$body+="<div class='row'><strong>$(Encode-Html $x[0])</strong><span>$(Encode-Html $x[1])</span></div>"};$body+='</div>'}
  $body+='<div class="foot"><span>출처: 세계일보 · 2026.08.20.</span><span>부동산 공급 브리핑</span></div>'
  $html="<!doctype html><html lang='ko'><head><meta charset='utf-8'><style>$css</style></head><body><main class='slide $($s.type)'>$body</main></body></html>"
  $num='{0:D2}'-f($i+1);$htmlPath=Join-Path $outDir "$num.html";$pngPath=Join-Path $outDir "$num.png";Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8
  if(Test-Path $pngPath){Remove-Item -LiteralPath $pngPath -Force};$url='file:///'+($htmlPath-replace'\\','/');&$chrome --headless --disable-gpu --hide-scrollbars --window-size=1080,1350 --force-device-scale-factor=1 --screenshot=$pngPath $url|Out-Null
  if(-not(Test-Path $pngPath)){throw "렌더링 실패: $pngPath"}
}

$caption=@'
[광명 철산·하안 재건축 체크]

광명시가 재건축 정비계획에 공공임대주택 반영을 요청했습니다. 추가 용적률에 따른 공공기여와 제로에너지건축물 기준이 일반분양 물량, 공사비, 조합원 분담금과 일정에 어떤 영향을 줄지 확인해야 합니다.

정비계획이 바뀌면 분담금도 달라질 수 있으니 저장해 두고 다시 확인하세요.

#광명재건축 #철산재건축 #하안재건축 #하안주공 #정비사업 #공공임대 #조합원분담금
'@
Set-Content -LiteralPath (Join-Path $outDir 'caption.txt') -Value $caption -Encoding UTF8
$review=@"
# 세계일보 기사 카드뉴스 검수

- 기사: $sourceUrl
- 카드 수: 8장
- 기사 이미지: 하안주공 전경 사진으로, 조감도·위치도 기준에 맞지 않아 미사용
- [ ] 광명시 공문 발송일과 대상 확인
- [ ] 공공임대 반영은 요청 단계임을 유지
- [ ] 분담금 증가를 확정 사실로 표현하지 않음
- [ ] 거래가격·면적·시점 확인
- [ ] 1장·2장 이중 표지, 7장 요약 보드, 8장 CTA 확인
"@
Set-Content -LiteralPath (Join-Path $outDir 'REVIEW.md') -Value $review -Encoding UTF8
Write-Host "완료: 8장 / $outDir"
