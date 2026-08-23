$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dateRoot = Join-Path $root 'output\2026-08-22'
$assetRoot = Join-Path $dateRoot 'article-assets'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'

function Encode-Html([string]$v) { [System.Net.WebUtility]::HtmlEncode($v) }
function File-Uri([string]$p) { 'file:///' + ((Resolve-Path $p).Path -replace '\\','/') }

$sets = @(
  [pscustomobject]@{
    slug='article-01-carousel'; source='내 손안에 서울'; articleDate='2024.12.08.'
    slides=@(
      @{type='cover'; eyebrow='공공기관 참여 모아타운'; title="SH·LH가 돕는`n모아타운 10곳 선정"; sub='모아주택 21개 사업구역 · 7개 자치구'; image=(Join-Path $assetRoot 'article01-map.png')},
      @{type='stats'; eyebrow='한눈에 보기'; title='이번 선정의 핵심 숫자'; stats=@(@('10곳','모아타운'),@('21개','사업구역'),@('7개','자치구'))},
      @{type='image'; eyebrow='선정지역'; title='어디가 선정됐나?'; sub='구기·홍제·화곡·등촌·상도·노량진·난곡·응봉·방학'; image=(Join-Path $assetRoot 'article01-map.png'); credit='기사 내 자료 · 내 손안에 서울'},
      @{type='list'; eyebrow='공공지원'; title='계획부터 준공까지 지원'; bullets=@('SH·LH가 관리계획 수립·변경 지원','조합 설립 단계의 행정·사업 지원','조합원 과반 동의 시 공동사업시행 참여')},
      @{type='stats'; eyebrow='사업 혜택'; title='사업성을 높이는 3가지'; stats=@(@('2만→4만㎡','사업면적 확대'),@('50%→30%','임대 기부채납 완화'),@('저리 융자','사업비·분석 지원'))},
      @{type='list'; eyebrow='공급 관점'; title='선정이 곧 착공은 아닙니다'; bullets=@('관리계획·조합설립 등 후속 절차가 남음','공공 참여로 초기 사업 리스크를 낮추는 구조','실제 공급 시점은 구역별 진행 속도에 따라 달라짐')},
      @{type='closing'; eyebrow='요약'; title="10개 모아타운에`n공공 실행력을 더한다"; sub='선정 → 계획 → 조합설립 → 사업시행 → 준공'; credit='출처: 내 손안에 서울 · 2024.12.08.'}
    )
  },
  [pscustomobject]@{
    slug='article-03-carousel'; source='이데일리'; articleDate='2025.01.24.'
    slides=@(
      @{type='cover'; eyebrow='모아타운·모아주택 통합심의'; title="서울 4곳 통과`n총 1,919가구 공급"; sub='면목본동·성내동·정릉동·화양동'; image=(Join-Path $assetRoot 'article03-map-1.jpg')},
      @{type='stats'; eyebrow='한눈에 보기'; title='이번 심의의 핵심 숫자'; stats=@(@('4건','통합심의 통과'),@('1,919가구','총 공급'),@('333가구','임대 포함'))},
      @{type='image'; eyebrow='중랑구 면목본동'; title='가장 큰 공급축'; sub='면목본동 63-1 일대 모아타운 위치도'; image=(Join-Path $assetRoot 'article03-map-1.jpg'); credit='기사 내 자료 · 이데일리 / 서울시 제공'},
      @{type='stats'; eyebrow='면목본동 계획'; title='기존 1,577 → 총 1,656가구'; stats=@(@('+79가구','공급 증가'),@('294가구','임대 포함'),@('4개소','모아주택 추진'))},
      @{type='image'; eyebrow='강동구 성내동'; title='2027년까지 87가구'; sub='지하 2층·지상 14층 · 임대 9가구 포함'; image=(Join-Path $assetRoot 'article03-map-2.jpg'); credit='기사 내 조감도 · 이데일리 / 서울시 제공'},
      @{type='list'; eyebrow='나머지 사업지'; title='정릉동·화양동도 공급'; bullets=@('정릉동 385-1: 3개동·15층, 136가구(임대 22)','화양동 32-12: 1개동·11층, 40가구(임대 8)','층수·용적률 완화로 사업 추진 여건 개선')},
      @{type='closing'; eyebrow='공급 관점'; title="심의 통과 이후`n사업 속도가 관건"; sub='관리계획·사업시행 절차와 실제 착공 시점을 계속 확인'; credit='출처: 이데일리 · 2025.01.24.'}
    )
  }
)

$css = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic",sans-serif;color:#0D1B3E}.slide{width:1080px;height:1350px;position:relative;padding:170px 150px 150px;background:linear-gradient(145deg,#fff,#EAF0FB);display:flex;flex-direction:column;justify-content:center;align-items:center}.slide:before{content:"";position:absolute;top:0;left:0;right:0;height:22px;background:#1F5ADB}.eyebrow{font-size:25px;font-weight:800;color:#fff;background:#1F5ADB;border-radius:999px;padding:13px 25px;margin-bottom:34px;text-align:center}.title{font-size:58px;line-height:1.22;font-weight:900;letter-spacing:-2.2px;text-align:center;word-break:keep-all;max-width:780px;white-space:pre-line}.sub{font-size:28px;line-height:1.45;font-weight:650;color:#555;text-align:center;margin-top:30px;max-width:780px;white-space:pre-line}.foot{position:absolute;left:150px;right:150px;bottom:45px;display:flex;justify-content:space-between;font-size:20px;color:#64748B}.cover{color:#fff;background:#0D1B3E;overflow:hidden}.cover:after{content:"";position:absolute;inset:0;background:linear-gradient(rgba(13,27,62,.28),rgba(13,27,62,.92));z-index:0}.cover .bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;filter:saturate(.75)}.cover>*:not(.bg){position:relative;z-index:1}.cover .foot{position:absolute;left:150px;right:150px;bottom:45px}.cover .eyebrow{background:#F5A623}.cover .title{font-size:70px}.cover .sub,.cover .foot{color:#fff}.stats-grid{width:780px;display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:46px}.stat{min-height:190px;border-radius:22px;background:#fff;border:2px solid #D9E4F7;display:flex;flex-direction:column;justify-content:center;align-items:center;padding:18px;text-align:center}.stat strong{font-size:43px;color:#1F5ADB;line-height:1.1}.stat span{font-size:24px;color:#555;margin-top:13px;line-height:1.3}.image-card{width:780px;max-height:660px;object-fit:contain;background:#fff;border-radius:22px;padding:10px;box-shadow:0 14px 40px rgba(13,27,62,.12);margin-top:30px}.image .title{font-size:48px}.image .sub{margin-top:15px}.list-wrap{width:780px;margin-top:38px;display:flex;flex-direction:column;gap:18px}.bullet{background:#fff;border-left:8px solid #1F5ADB;border-radius:18px;padding:25px 28px;font-size:29px;line-height:1.35;font-weight:700;word-break:keep-all}.closing{background:#1F5ADB;color:#fff}.closing:before{background:#F5A623}.closing .eyebrow{background:#F5A623}.closing .sub,.closing .foot{color:#fff}
'@

foreach($set in $sets){
  $dir=Join-Path $dateRoot $set.slug;New-Item -ItemType Directory -Path $dir -Force|Out-Null
  for($i=0;$i -lt $set.slides.Count;$i++){
    $s=$set.slides[$i];$num='{0:D2}' -f ($i+1);$body=''
    if($s.image){$body+="<img class='$(if($s.type -eq 'cover'){'bg'}else{'image-card'})' src='$(File-Uri $s.image)'>"}
    $body+="<div class='eyebrow'>$(Encode-Html $s.eyebrow)</div><div class='title'>$((Encode-Html $s.title)-replace "`n",'<br>')</div>"
    if($s.sub){$body+="<div class='sub'>$(Encode-Html $s.sub)</div>"}
    if($s.stats){$body+='<div class="stats-grid">';foreach($st in $s.stats){$body+="<div class='stat'><strong>$(Encode-Html $st[0])</strong><span>$(Encode-Html $st[1])</span></div>"};$body+='</div>'}
    if($s.bullets){$body+='<div class="list-wrap">';foreach($b in $s.bullets){$body+="<div class='bullet'>$(Encode-Html $b)</div>"};$body+='</div>'}
    $credit=if($s.credit){$s.credit}else{"출처: $($set.source) · $($set.articleDate)"}
    $body+="<div class='foot'><span>$(Encode-Html $credit)</span><span>부동산 공급 브리핑</span></div>"
    $html="<!doctype html><html lang='ko'><head><meta charset='utf-8'><style>$css</style></head><body><main class='slide $($s.type)'>$body</main></body></html>"
    $hp=Join-Path $dir "$num.html";$pp=Join-Path $dir "$num.png";Set-Content -LiteralPath $hp -Value $html -Encoding UTF8
    if(Test-Path $pp){Remove-Item -LiteralPath $pp -Force};$url='file:///'+($hp -replace '\\','/');&$chrome --headless --disable-gpu --hide-scrollbars --window-size=1080,1350 --force-device-scale-factor=1 --screenshot=$pp $url|Out-Null
    if(-not(Test-Path $pp)){throw "렌더링 실패: $pp"}
  }
  $caption="[$($set.articleDate) 부동산 공급 브리핑]`r`n`r`n$($set.slides[0].title -replace "`n",' ')`r`n`r`n기사 내용을 7장으로 정리했습니다.`r`n`r`n#모아타운 #모아주택 #정비사업 #서울부동산 #주택공급"
  Set-Content -LiteralPath (Join-Path $dir 'caption.txt') -Value $caption -Encoding UTF8
  Write-Host "$($set.slug): $($set.slides.Count)장 완료"
}
