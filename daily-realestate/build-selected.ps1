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
  $summary = Short-Text $article.summary 104
  if (-not $summary) { $summary = 'RSS 요약이 짧습니다. 카드 제작 전 원문에서 수치와 문맥 확인이 필요합니다.' }
  $title = Short-Text $article.title 82
  $source = Short-Text $article.source 28
  $region = if ($article.region) { $article.region } else { '전국' }
  $category = if ($article.category) { $article.category } else { '주택공급' }

  return @(
    [pscustomobject]@{ type='cover'; kicker="$category · $region"; title=(Get-CoverTitle $article); body=$title },
    [pscustomobject]@{ type='second'; kicker='두 번째 표지'; title=(Get-PracticalTitle $article); body="기사 원문 기준으로`n핵심 쟁점만 따로 정리" },
    [pscustomobject]@{ type='point'; kicker='무슨 기사?'; title=$title; body="출처: $source`n$summary" },
    [pscustomobject]@{ type='point'; kicker='공급 관점'; title='핵심은 발표보다`n실행 단계입니다'; body="정책·사업·청약 뉴스는`n발표, 인허가, 착공, 입주를 구분해 봐야 합니다." },
    [pscustomobject]@{ type='point'; kicker='확인 포인트'; title='읽을 때 볼 3가지'; body="1. 공급 물량과 위치`n2. 실제 일정과 지연 가능성`n3. 전매·거주·자격 제한" },
    [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='한눈에 보는 핵심 요약'; body="분류 | $category`n지역 | $region`n출처 | $source`n상태 | 원문 수치·일정 검수 필요" },
    [pscustomobject]@{ type='cta'; kicker='마지막 체크'; title='일정은 바뀔 수 있습니다'; body="관심 지역이면 저장해 두고`n원문 링크에서 다시 확인하세요." }
  )
}

$baseCss = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic",sans-serif;background:#F8F9FA;color:#0D1B3E}.slide{width:1080px;height:1350px;position:relative;padding:170px 150px 180px;display:flex;flex-direction:column;justify-content:center;align-items:center;background:linear-gradient(145deg,#FFFFFF 0%,#EAF0FB 100%)}.slide:before{content:"";position:absolute;left:0;top:0;width:100%;height:22px;background:#1F5ADB}.kicker{align-self:center;background:#1F5ADB;color:#fff;border-radius:999px;padding:13px 25px;font-size:25px;font-weight:800;margin-bottom:38px;text-align:center;max-width:780px}.title{font-size:56px;line-height:1.25;letter-spacing:0;font-weight:900;word-break:keep-all;max-width:780px;text-align:center;white-space:pre-line}.body{font-size:29px;line-height:1.55;color:#3F4B5B;margin-top:38px;text-align:center;white-space:pre-line;font-weight:600;word-break:keep-all;max-width:780px}.footer{position:absolute;left:150px;right:150px;bottom:45px;display:flex;justify-content:space-between;gap:24px;font-size:21px;color:#64748B}.footer span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.cover{background:#0D1B3E;color:#fff}.cover:before{background:#F5A623}.cover .kicker{background:#F5A623;color:#0D1B3E}.cover .title{font-size:70px}.cover .body{color:#fff}.cover .footer{color:#fff}.second{background:#FFFFFF}.second .kicker,.summary .kicker{background:#F5A623;color:#0D1B3E}.point .title{font-size:54px}.summary{background:#F8F9FA}.summary .body{background:#fff;border-left:8px solid #1F5ADB;border-radius:22px;padding:32px 38px;text-align:left;line-height:1.7}.cta{background:#1F5ADB;color:#fff}.cta:before{background:#F5A623}.cta .kicker{background:#F5A623;color:#0D1B3E}.cta .body,.cta .footer{color:#fff}
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






