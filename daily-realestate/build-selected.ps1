param(
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
  [string]$Numbers = '',
  [switch]$NoRender
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$outDir = Join-Path $root (Join-Path 'output' $Date)
$candidatePath = Join-Path $outDir 'candidates.json'
if (-not (Test-Path -LiteralPath $candidatePath)) { throw "먼저 해당 날짜의 기사를 수집하세요: $Date" }

$loadedCandidates = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })

if (-not $Numbers) {
  $selectionPath = Join-Path $outDir 'selection.txt'
  if (Test-Path -LiteralPath $selectionPath) {
    $Numbers = ((Get-Content -LiteralPath $selectionPath -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*#' }) -join ',')
  }
}

$indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
if ($indexes.Count -eq 0) { throw "선택 번호가 없습니다. selection.txt에 예: 1,3,7 을 입력하세요." }

$invalid = @($indexes | Where-Object { $_ -lt 1 -or $_ -gt $candidates.Count })
if ($invalid.Count) { throw "존재하지 않는 기사 번호: $($invalid -join ', ') (가능 범위: 1~$($candidates.Count))" }

$enrichScript = Join-Path $root 'enrich-selected.ps1'
if (Test-Path -LiteralPath $enrichScript) {
  & $enrichScript -Date $Date -Numbers ($indexes -join ',')
}

function Html([string]$value) { return [System.Net.WebUtility]::HtmlEncode($value) }

function Short-Text([string]$value, [int]$max = 72) {
  if (-not $value) { return '' }
  $clean = (($value -replace '\s+', ' ').Trim())
  if ($clean.Length -le $max) { return $clean }
  return $clean.Substring(0, $max - 1).Trim() + '…'
}

function Get-TopicLabel($article) {
  if ($article.category -eq '청약·분양') { return '청약 일정' }
  if ($article.category -eq '재개발·재건축') { return '정비사업 단계' }
  if ($article.category -eq '교통·SOC') { return '교통 호재' }
  if ($article.category -eq '신도시·택지') { return '택지 공급' }
  return '주택공급'
}

function Get-CoverTitle($article) {
  $title = [string]$article.title
  if ($article.category -eq '청약·분양') { return "이번 청약`n놓치면 안 될 핵심만" }
  if ($article.category -eq '재개발·재건축') { return "이 정비사업`n지금 어느 단계일까?" }
  if ($article.category -eq '교통·SOC') { return "이 교통 이슈`n어디가 달라질까?" }
  if ($article.category -eq '신도시·택지') { return "새 공급지`n체크할 포인트" }
  if ($title -match '모아주택') { return "모아주택 공급`n속도가 빨라진다" }
  return "주택공급 뉴스`n핵심만 빠르게"
}

function Get-PracticalTitle($article) {
  if ($article.category -eq '청약·분양') { return "일정·물량·조건`n먼저 확인하세요" }
  if ($article.category -eq '재개발·재건축') { return "단계·세대수·주의점`n이 3가지만 보세요" }
  if ($article.category -eq '교통·SOC') { return "노선·시기·수혜권`n따로 봐야 합니다" }
  if ($article.category -eq '신도시·택지') { return "위치·물량·입주시점`n한 번에 점검" }
  return "정책 발표보다 중요한 건`n실제 공급 시점"
}

function Get-ReferenceHookTitle($article) {
  $title = [string]$article.title
  if ($title -match '([가-힣A-Za-z0-9·]+역)') { return "$($Matches[1])`n정말로 생기나?" }
  if ($title -match '(모아타운|모아주택)') { return "모아타운`n정말 빨라지나?" }
  if ($title -match '(용산공원|공공주택지구|신도시|택지)') { return "이 공급지`n정말 추진되나?" }
  if ($article.category -eq '청약·분양') { return "이번 청약`n진짜 체크할 건?" }
  if ($article.category -eq '재개발·재건축') { return "이 정비사업`n정말 빨라지나?" }
  if ($article.category -eq '교통·SOC') { return "이 노선`n정말 생기나?" }
  return "이 공급 뉴스`n진짜 핵심은?"
}

function Get-KeyNumbers([string]$text) {
  $matches = @([regex]::Matches($text, '(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(세대|가구|호|만호|억원|조원|년|월|일|곳|km|분|%)?') | ForEach-Object { $_.Value } | Select-Object -Unique)
  if ($matches.Count -eq 0) { return @('수치 확인', '원문 기준') }
  return @($matches | Select-Object -First 4)
}

function Get-RegionHashtags($article) {
  $region = [string]$article.region
  $tags = [System.Collections.ArrayList]::new()
  foreach ($tag in @('부동산뉴스','주택공급')) { [void]$tags.Add($tag) }
  if ($region -and $region -ne '전국') { [void]$tags.Add(($region -replace '\s+', '')) }
  if ($article.category -match '재개발|재건축') { foreach ($tag in @('재개발','재건축','정비사업')) { [void]$tags.Add($tag) } }
  elseif ($article.category -match '청약|분양') { foreach ($tag in @('청약','분양','분양정보')) { [void]$tags.Add($tag) } }
  elseif ($article.category -match '교통|SOC') { foreach ($tag in @('교통호재','철도','역세권')) { [void]$tags.Add($tag) } }
  elseif ($article.category -match '신도시|택지') { foreach ($tag in @('신도시','택지지구','공공주택')) { [void]$tags.Add($tag) } }
  else { [void]$tags.Add('부동산정책') }
  return @($tags | Select-Object -Unique | ForEach-Object { "#$_" })
}

function Find-BrowserExecutable {
  $candidates = @(
    $env:CHROME_PATH,
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) { return $path }
  }

  $command = Get-Command chrome -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $edgeCommand = Get-Command msedge -ErrorAction SilentlyContinue
  if ($edgeCommand) { return $edgeCommand.Source }

  throw 'Chrome 또는 Edge 실행 파일을 찾을 수 없습니다. CHROME_PATH 환경변수로 브라우저 경로를 지정하세요.'
}

function New-Slides($article, [int]$number) {
  $topic = Get-TopicLabel $article
  $summary = Short-Text $article.summary 118
  if (-not $summary) { $summary = 'RSS 요약이 짧습니다. 카드 제작 전 원문에서 수치와 문맥 확인이 필요합니다.' }
  $title = Short-Text $article.title 86
  $source = Short-Text $article.source 28
  $region = if ($article.region) { $article.region } else { '전국' }
  $category = if ($article.category) { $article.category } else { '주택공급' }
  $numbers = Get-KeyNumbers "$($article.title) $($article.summary)"
  $numberText = ($numbers -join ' · ')

  return @(
    [pscustomobject]@{ type='cover'; kicker=$topic; title=(Get-ReferenceHookTitle $article); body="$title" },
    [pscustomobject]@{ type='table'; kicker='핵심만 보면'; title='그래서 뭐가 바뀌나'; body="분류|$category`n지역|$region`n출처|$source`n키워드|$topic" },
    [pscustomobject]@{ type='number'; kicker='숫자 체크'; title=$numberText; body=$summary },
    [pscustomobject]@{ type='table'; kicker='아직 봐야 할 것'; title='확정과 검토를 나눠보세요'; body="단계|원문 기준 확인`n일정|변경 가능성 체크`n수치|기사 기준일 확인`n이미지|공식 자료만 사용" },
    [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='저장 전 체크'; body="1. 발표인지 확정인지 구분`n2. 공급 물량·위치 다시 확인`n3. 일정은 원문 링크에서 재확인`n4. 애매한 내용은 제외" }
  )
}

$baseCss = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic",sans-serif;background:#0B1115;color:#fff}.slide{width:1080px;height:1350px;position:relative;padding:145px 88px 92px;display:flex;flex-direction:column;justify-content:flex-start;align-items:flex-start;overflow:hidden;background:radial-gradient(circle at 72% 28%,rgba(244,185,66,.20),transparent 22%),linear-gradient(180deg,rgba(10,17,21,.50) 0%,rgba(9,18,18,.78) 48%,rgba(0,0,0,.96) 100%),linear-gradient(135deg,#415C5E 0%,#101B1C 50%,#050708 100%)}.slide:before{content:"";position:absolute;inset:0;background:linear-gradient(150deg,rgba(255,255,255,.10),transparent 36%),repeating-linear-gradient(90deg,rgba(255,255,255,.035) 0 1px,transparent 1px 140px);opacity:.55}.slide:after{content:"";position:absolute;left:-80px;right:-80px;bottom:-30px;height:420px;background:linear-gradient(0deg,rgba(0,0,0,.75),transparent),radial-gradient(ellipse at 30% 80%,rgba(61,98,76,.55),transparent 38%);filter:blur(1px)}.inner{position:relative;z-index:2;width:100%;height:100%;display:flex;flex-direction:column}.handle{font-size:25px;font-weight:800;color:rgba(255,255,255,.72);margin-bottom:70px}.handle:before{content:"";display:inline-block;width:12px;height:12px;border-radius:50%;background:#F4B942;margin-right:10px;vertical-align:3px;box-shadow:0 0 14px rgba(244,185,66,.7)}.count{position:absolute;z-index:3;right:60px;top:55px;background:rgba(0,0,0,.58);color:#fff;border-radius:999px;padding:18px 26px;font-size:28px;font-weight:700}.kicker{align-self:flex-start;background:#F4B942;color:#0D1114;border-radius:999px;padding:13px 26px;font-size:26px;font-weight:900;margin-bottom:34px;text-align:center;max-width:780px}.title{font-size:62px;line-height:1.22;letter-spacing:-2.4px;font-weight:950;word-break:keep-all;max-width:900px;text-align:left;white-space:pre-line;text-shadow:0 3px 18px rgba(0,0,0,.35)}.body{font-size:31px;line-height:1.65;color:rgba(255,255,255,.74);margin-top:34px;text-align:left;white-space:pre-line;font-weight:650;word-break:keep-all;max-width:900px}.accent{width:116px;height:8px;border-radius:8px;background:#F4B942;margin:34px 0 24px}.footer{position:absolute;z-index:3;left:88px;right:88px;bottom:52px;display:flex;justify-content:space-between;gap:24px;border-top:1px solid rgba(255,255,255,.24);padding-top:28px;font-size:22px;color:rgba(255,255,255,.62)}.footer span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rows{width:100%;margin-top:34px;border-top:1px solid rgba(255,255,255,.22)}.row{display:grid;grid-template-columns:270px 1fr;gap:28px;align-items:center;border-bottom:1px solid rgba(255,255,255,.18);padding:27px 0}.row .label{font-size:34px;font-weight:900;color:#fff}.row .value{font-size:34px;line-height:1.35;font-weight:950;color:#F4B942;text-align:right;word-break:keep-all}.cover{justify-content:flex-end}.cover .inner{justify-content:flex-end;padding-bottom:110px}.cover .title{font-size:68px}.cover .body{font-size:30px;color:rgba(255,255,255,.70);max-width:860px}.table .title{font-size:58px;margin-bottom:12px}.number .kicker{background:transparent;color:#F4B942;padding:0;margin-bottom:26px}.number .title{font-size:82px;color:#F4B942;letter-spacing:-2px}.number .body{font-size:34px;color:#fff;line-height:1.55;max-width:880px}.summary .kicker{background:transparent;color:#F4B942;padding:0}.summary .title{font-size:64px}.summary .body{font-size:36px;color:#fff;line-height:1.72;border-left:8px solid #F4B942;padding-left:28px}
'@

$brand = if ($config.account) { $config.account } else { $config.brandName }
$chrome = Find-BrowserExecutable
$chromeProfileDir = Join-Path $outDir '_chrome-profile'
if (-not $NoRender) {
  New-Item -ItemType Directory -Path $chromeProfileDir -Force | Out-Null
}
$createdSets = @()

foreach ($index in $indexes) {
  $article = $candidates[$index - 1]
  $setName = 'article-{0:D2}-carousel' -f $index
  $setDir = Join-Path $outDir $setName
  New-Item -ItemType Directory -Path $setDir -Force | Out-Null
  $detailPath = Join-Path $setDir 'article-detail.json'
  $detail = $null
  if (Test-Path -LiteralPath $detailPath) {
    $detail = Get-Content -LiteralPath $detailPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }

  $slides = @(New-Slides $article $index)
  if ($slides.Count -lt 5 -or $slides.Count -gt 8) { throw "슬라이드 수 규칙 위반: $setName / $($slides.Count)장" }

  for ($i = 0; $i -lt $slides.Count; $i++) {
    $slide = $slides[$i]
    $num = '{0:D2}' -f ($i + 1)
    $safeTitle = (Html $slide.title) -replace "`n", '<br>'
    $safeBody = (Html $slide.body) -replace "`n", '<br>'
    $doc = "<!doctype html><html lang='ko'><head><meta charset='utf-8'><style>$baseCss</style></head><body><main class='slide $($slide.type)'><div class='kicker'>$(Html $slide.kicker)</div><div class='title'>$safeTitle</div><div class='body'>$safeBody</div><div class='footer'><span>출처: $(Html $article.source) · $Date</span><span>$(Html $brand)</span></div></main></body></html>"
    $htmlPath = Join-Path $setDir "$num.html"
    $pngPath = Join-Path $setDir "$num.png"
    Set-Content -LiteralPath $htmlPath -Value $doc -Encoding UTF8

    if (-not $NoRender) {
      if (Test-Path -LiteralPath $pngPath) { Remove-Item -LiteralPath $pngPath -Force }
      $url = 'file:///' + ($htmlPath -replace '\\', '/')
      $chromeArgs = @(
        '--headless=new',
        "--user-data-dir=$chromeProfileDir",
        '--disable-gpu',
        '--disable-gpu-compositing',
        '--disable-software-rasterizer',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--hide-scrollbars',
        '--window-size=1080,1350',
        '--force-device-scale-factor=1',
        '--password-store=basic',
        "--screenshot=$pngPath",
        $url
      )
      $chromeOutput = & $chrome @chromeArgs 2>&1
      $rendered = $false
      for ($attempt = 0; $attempt -lt 10; $attempt++) {
        if (Test-Path -LiteralPath $pngPath) {
          $rendered = $true
          break
        }
        Start-Sleep -Milliseconds 250
      }
      if (-not $rendered) {
        $chromeOutput | Set-Content -LiteralPath (Join-Path $setDir 'chrome-render.log') -Encoding UTF8
        throw "PNG 렌더링 실패: $pngPath (chrome-render.log 확인)"
      }
    }
  }

  $review = @(
    "# $Date $setName 검수",
    '',
    "- 선택 번호: $index",
    "- 제목: $($article.title)",
    "- 분류/지역: $($article.category) / $($article.region)",
    "- 출처: $($article.source)",
    "- 링크: $($article.url)",
    '',
    "## 원문/문맥 추출 상태",
    "- 추출 상태: $(if ($detail) { $detail.fetchStatus } else { 'not_available' })",
    "- 수동 원문 URL: $(if ($detail -and $detail.manualOriginalUrl) { $detail.manualOriginalUrl } else { '없음' })",
    "- 실제 추출 URL: $(if ($detail -and $detail.fetchedUrl) { $detail.fetchedUrl } else { '확인 필요' })",
    "- 해석 가능한 원문 URL: $(if ($detail -and $detail.resolvedUrl) { $detail.resolvedUrl } else { '확인 필요' })",
    "- 원문 메타 설명: $(if ($detail -and $detail.metaDescription) { Short-Text $detail.metaDescription 140 } else { '확인 필요' })",
    '',
    "## 문맥 경고",
    "$(if ($detail -and $detail.contextWarnings -and $detail.contextWarnings.Count -gt 0) { (($detail.contextWarnings | ForEach-Object { '- ' + $_ }) -join "`r`n") } else { '- 자동 경고 없음. 그래도 게시 전 원문 수치와 단계는 확인 필요' })",
    '',
    "## 이미지 후보",
    "$(if ($detail -and $detail.imageCandidates -and $detail.imageCandidates.Count -gt 0) { (($detail.imageCandidates | Select-Object -First 8 | ForEach-Object { '- [' + $_.usage + '] ' + $_.url + $(if ($_.alt) { ' / alt: ' + $_.alt } else { '' }) }) -join "`r`n") } else { '- 자동 사용 가능한 공식 이미지 후보 없음. 이미지가 필요하면 사용자 확인 후 사용' })",
    '',
    "## 게시 전 확인",
    "- [ ] 기사 원문에서 수치·일정·사업 단계 확인",
    "- [ ] 원인과 결과를 임의로 연결하지 않았는지 확인",
    "- [ ] 거래 사례·가격 언급은 기사 문맥과 함께 설명했는지 확인",
    "- [ ] 조감도·위치도·노선도 등 공식 원문 발췌 자료만 사용했는지 확인",
    "- [ ] 사용 조건이 불분명한 이미지는 게시 전 사용자 확인",
    "- [ ] 5~8장 구성, 1080x1350 PNG 확인"
  )
  $review -join "`r`n" | Set-Content -LiteralPath (Join-Path $setDir 'REVIEW.md') -Encoding UTF8

  $caption = @(
    "[$($article.category) / $($article.region)] $($article.title)",
    '',
    "기사 원문 기준으로 주택공급 관점의 핵심만 정리했습니다.",
    "일정과 조건은 바뀔 수 있으니 관심 지역이면 저장 후 원문을 다시 확인하세요.",
    '',
    "출처: $($article.source)",
    "$($article.url)",
    '',
    "#부동산뉴스 #주택공급 #재개발 #재건축 #청약 #분양 #정비사업"
  ) -join "`r`n"
  Set-Content -LiteralPath (Join-Path $setDir 'caption.txt') -Value $caption -Encoding UTF8

  $createdSets += [pscustomobject]@{
    number = $index
    title = $article.title
    dir = $setDir
    slides = $slides.Count
    rendered = (-not $NoRender)
    detail = (Test-Path -LiteralPath $detailPath)
  }
}

$status = [ordered]@{
  runAt = (Get-Date -Format o)
  date = $Date
  selectedNumbers = $indexes
  selected = $createdSets.Count
  sets = $createdSets
  rendered = (-not $NoRender)
  enriched = $true
  state = 'article_carousels_created'
}
$status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'status.json') -Encoding UTF8

if (-not $NoRender -and (Test-Path -LiteralPath $chromeProfileDir)) {
  $resolvedProfile = (Resolve-Path -LiteralPath $chromeProfileDir).Path
  $resolvedOutDir = (Resolve-Path -LiteralPath $outDir).Path
  if ($resolvedProfile.StartsWith($resolvedOutDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedProfile -Recurse -Force
  }
}

Write-Host "카드뉴스 완료: 선택 $($indexes -join ', ') / 기사별 $($createdSets.Count)세트 / $outDir"






