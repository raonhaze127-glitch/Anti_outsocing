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
  if ($title -match '([가-힣A-Za-z0-9·]+역)') { return "$($Matches[1])`n체크할 변화는?" }
  if ($title -match '(모아타운|모아주택)') { return "모아타운`n속도 붙을까?" }
  if ($title -match '(용산공원|공공주택지구|신도시|택지)') { return "새 공급지`n무엇을 봐야 할까?" }
  if ($article.category -eq '청약·분양') { return "이번 청약`n먼저 볼 포인트" }
  if ($article.category -eq '재개발·재건축') { return "이 정비사업`n현재 단계는?" }
  if ($article.category -eq '교통·SOC') { return "이 교통 이슈`n바뀌는 지점은?" }
  return "주택공급 뉴스`n핵심 체크"
}

function Get-KeyNumbers([string]$text) {
  $matches = @([regex]::Matches($text, '(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(세대|가구|호|만호|억원|조원|년|월|일|곳|km|분|%)?') | ForEach-Object { $_.Value } | Select-Object -Unique)
  if ($matches.Count -eq 0) { return @('수치 확인', '원문 기준') }
  return @($matches | Select-Object -First 4)
}

function Add-Hashtag($tags, [string]$tag) {
  if (-not $tag) { return }
  $clean = ($tag -replace '[^0-9A-Za-z가-힣_]', '')
  if ($clean.Length -lt 2) { return }
  $blocked = @('가구','세대','억원','만원','일반','특별','공급','분양','청약가구','공공가구')
  if ($blocked -contains $clean) { return }
  if (-not $tags.Contains($clean)) { [void]$tags.Add($clean) }
}

function Add-KeywordHashtags($tags, [string]$text, [array]$rules) {
  foreach ($rule in $rules) {
    if ($text -match $rule.pattern) {
      foreach ($tag in $rule.tags) { Add-Hashtag $tags $tag }
    }
  }
}

function Get-ArticleHashtags($article) {
  $region = [string]$article.region
  $category = [string]$article.category
  $text = "$($article.title) $($article.summary) $category $region"
  $tags = [System.Collections.ArrayList]::new()

  foreach ($tag in @('부동산뉴스','주택공급','부동산브리핑')) { Add-Hashtag $tags $tag }

  if ($text -match '9월 첫주 3713가구') { foreach ($tag in @('인천분양','인천청약','분양캘린더','시티오씨엘9단지','검암역푸르지오라베뉴')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 8 | ForEach-Object { "#$_" }) }
  if ($text -match '화성 1만호 공공주택') { foreach ($tag in @('화성특례시','화성공공주택','공공주택프로젝트','주택공급정책','화성동행기구')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 8 | ForEach-Object { "#$_" }) }
  if ($text -match '부천형 역세권 정비사업') { foreach ($tag in @('부천정비사업','소새울역','송내역','역세권정비사업','정비계획')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 8 | ForEach-Object { "#$_" }) }
  if ($text -match '주택공급에 직 걸겠다.*예산 30조') { $tags.Clear(); foreach ($tag in @('주택공급예산','공공주택','공공임대주택','PF지원','주택공급정책')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match '인천 구월2 공공주택지구 토지거래허가구역') { $tags.Clear(); foreach ($tag in @('구월2공공주택지구','인천공공주택','토지거래허가구역','구월동부동산','공공주택공급')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match '공적주택 21만8000호.*청년월세') { $tags.Clear(); foreach ($tag in @('공적주택','공공임대','공공분양','청년주거','2027국토부예산')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match 'LH 부채 2030년 373조') { $tags.Clear(); foreach ($tag in @('LH부채','공공주택공급','매입임대','LH재무건전성','공공임대주택')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match '모아타운 후보지 도로.*5년간') { $tags.Clear(); foreach ($tag in @('모아타운','토지거래허가구역','서울모아타운','사도지분거래','정비사업')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match '부천대장 공공분양.*하우스토리 디센트') { $tags.Clear(); foreach ($tag in @('부천대장지구','하우스토리디센트','3기신도시','부천공공분양','대장홍대선')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match "'분양 성수기'.*3\.3만 가구") { $tags.Clear(); foreach ($tag in @('9월분양','아파트분양','수도권분양','서울분양','분양일정')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }
  if ($text -match '의정부우정지구 A-2블록 공공분양주택 청약') { $tags.Clear(); foreach ($tag in @('의정부우정지구','의정부공공분양','LH청약','의정부청약','공공분양')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 5 | ForEach-Object { "#$_" }) }

  if ($text -match '상계보람') {
    foreach ($tag in @('상계보람아파트','상계동재건축','노원구재건축','조합설립추진위원회','정비구역지정','재건축','정비사업','4483가구','서울재건축')) { Add-Hashtag $tags $tag }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '양주회천 A-26블록') { foreach ($tag in @('양주회천','A26블록','LH공공분양','공공분양','청약일정','덕정역','GTXC','양주청약','분양정보')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" }) }
  if ($text -match '모아주택 1호.*준공') { foreach ($tag in @('모아주택','광진구','구의동','한양연립','서울정비사업','소규모주택정비')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" }) }
  if ($text -match '2028년부터 매년 10만 가구 착공') { foreach ($tag in @('LH','공공주택','착공계획','주택공급정책','813주택대책','도심주택공급','학교용지복합개발')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" }) }
  if ($text -match '계양신도시.*첫.*민간분양') { foreach ($tag in @('계양신도시','3기신도시','인천계양','민간분양','카이브유보라','신도시입주','분양일정','공공택지')) { Add-Hashtag $tags $tag }; return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" }) }

  if ($text -match '검암역 푸르지오 프라베뉴') {
    foreach ($tag in @('인천청약','검암역세권','검암역푸르지오프라베뉴','공공분양','청약일정','분양정보','분양가상한제','전매제한','재당첨제한','인천부동산','검암동')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '의정부우정|A-2블록|공공주택지구') {
    foreach ($tag in @('의정부청약','의정부우정','공공분양','LH분양','청약일정','의정부부동산','녹양역','GTXC','분양가상한제','전매제한','내집마련','분양정보')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '지연된 PF 사업장|PF 사업장|청년·신혼부부|신혼부부 보금자리') {
    foreach ($tag in @('PF사업장','매입임대','청년주택','신혼부부주택','공공임대','LH','국토교통부','주택공급정책','주거정책','부동산정책','공급대책','임대주택')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '사당동|남성역|사당로16길') {
    foreach ($tag in @('사당동재개발','남성역','동작구재개발','신속통합기획','신통기획','서울정비사업','재개발','정비사업','주택공급','970세대','도시정비','사당로16길')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '기부채납') {
    foreach ($tag in @('주택공급정책','기부채납','민간택지','민간주택공급','수도권공급','사업성개선','인허가','국토교통부','부동산정책','공급대책','주택건설사업')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '대구.?경북 광역철도|대구.?경북.*신공항|서대구.*의성') {
    foreach ($tag in @('대구경북광역철도','대구경북신공항','서대구역','의성역','광역철도','철도호재','교통호재','SOC','국가철도망','예타통과','대구부동산','경북부동산','공항철도','부동산뉴스')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($text -match '신통기획|신속통합기획|현장형 신통|현장 자문|노원구 재건축') {
    foreach ($tag in @('노원구재건축','신속통합기획','신통기획','현장자문','중계그린','중계주공4단지','상계보람아파트','하계미성아파트','서울정비사업','재건축속도','정비계획','조합설립추진위원회')) {
      Add-Hashtag $tags $tag
    }
    return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
  }

  if ($region -and $region -ne '전국') {
    Add-Hashtag $tags $region
    Add-Hashtag $tags "$region부동산"
  }

  foreach ($match in [regex]::Matches($text, '([가-힣A-Za-z0-9]+역세권|[가-힣A-Za-z0-9]+역|[가-힣]+구|[가-힣]+시|[가-힣]+군|[가-힣]+동)')) {
    Add-Hashtag $tags $match.Value
    if ($tags.Count -ge 14) { break }
  }

  $rules = @(
    @{ pattern='청약|분양|공급가구|특별공급|일반공급'; tags=@('청약','분양','분양정보','청약일정') },
    @{ pattern='공공분양|뉴홈|사전청약'; tags=@('공공분양','뉴홈','청약전략') },
    @{ pattern='국민임대|행복주택|공공임대|장기전세'; tags=@('공공임대','국민임대','임대주택') },
    @{ pattern='재개발|재건축|정비사업|관리처분|조합설립|통합심의|소규모재건축|소규모재개발'; tags=@('재개발','재건축','정비사업') },
    @{ pattern='모아타운|모아주택'; tags=@('모아타운','모아주택','서울정비사업') },
    @{ pattern='신도시|3기 신도시|3기신도시|택지|공공주택지구|지구지정'; tags=@('신도시','택지지구','공공주택지구') },
    @{ pattern='철도|지하철|노선|GTX|광역철도|도로|SOC|개통|착공'; tags=@('교통호재','철도','역세권') },
    @{ pattern='분양가|분양가상한제|시세차익|계약금|전매제한|거주의무'; tags=@('분양가','분양가상한제','청약체크') },
    @{ pattern='착공|준공|입주|개통|예정|목표|심의|협의|공문'; tags=@('사업일정','공급일정','원문확인') }
  )
  Add-KeywordHashtags $tags $text $rules

  if ($tags.Count -lt 8) {
    foreach ($tag in @('부동산정책','주거정책','내집마련','부동산정보')) { Add-Hashtag $tags $tag }
  }

  return @($tags | Select-Object -First 14 | ForEach-Object { "#$_" })
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

function Get-BrowserExecutables {
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $paths = @(
    $env:CHROME_PATH,
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  $commands = @(
    (Get-Command chrome -ErrorAction SilentlyContinue),
    (Get-Command msedge -ErrorAction SilentlyContinue)
  ) | Where-Object { $_ }
  foreach ($command in $commands) { $paths += $command.Source }

  $result = @()
  foreach ($path in $paths) {
    if ((Test-Path -LiteralPath $path) -and $seen.Add($path)) { $result += $path }
  }
  return @($result)
}

function Invoke-BrowserScreenshot([string]$HtmlPath, [string]$PngPath, [string]$ProfileBaseDir, [string]$LogPath) {
  $url = 'file:///' + ($HtmlPath -replace '\\', '/')
  $browsers = @(Get-BrowserExecutables)
  if ($browsers.Count -eq 0) { throw 'Chrome 또는 Edge 실행 파일을 찾을 수 없습니다. CHROME_PATH 환경변수로 브라우저 경로를 지정하세요.' }

  $attempts = @(
    @{ name='headless-new'; headless='--headless=new'; extra=@('--disable-gpu','--disable-gpu-compositing','--enable-unsafe-swiftshader') },
    @{ name='headless-classic'; headless='--headless'; extra=@('--disable-gpu','--enable-unsafe-swiftshader') },
    @{ name='headless-minimal'; headless='--headless'; extra=@() }
  )

  $logs = @()
  $attemptIndex = 0
  foreach ($browser in $browsers) {
    foreach ($attempt in $attempts) {
      $attemptIndex++
      if (Test-Path -LiteralPath $PngPath) { Remove-Item -LiteralPath $PngPath -Force }
      $profileDir = Join-Path $ProfileBaseDir ('profile-{0}' -f $attemptIndex)
      New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
      $browserArgs = @(
        $attempt.headless,
        "--user-data-dir=$profileDir",
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-extensions',
        '--disable-background-networking',
        '--allow-file-access-from-files',
        '--no-first-run',
        '--hide-scrollbars',
        '--window-size=1080,1350',
        '--force-device-scale-factor=1',
        '--run-all-compositor-stages-before-draw',
        '--virtual-time-budget=1500',
        '--password-store=basic'
      ) + $attempt.extra + @(
        "--screenshot=$PngPath",
        $url
      )

      $output = & $browser @browserArgs 2>&1
      $exitCode = $LASTEXITCODE
      $rendered = $false
      for ($wait = 0; $wait -lt 40; $wait++) {
        if (Test-Path -LiteralPath $PngPath) {
          $rendered = $true
          break
        }
        Start-Sleep -Milliseconds 250
      }

      $logs += @(
        "## Attempt $attemptIndex / $($attempt.name)",
        "Browser: $browser",
        "Exit code: $exitCode",
        "Screenshot path: $PngPath",
        "HTML URL: $url",
        "Arguments:",
        ($browserArgs -join "`r`n"),
        "Output:",
        ($output -join "`r`n"),
        ""
      )

      if ($rendered) {
        $logs | Set-Content -LiteralPath $LogPath -Encoding UTF8
        return $true
      }
    }
  }

  $logs | Set-Content -LiteralPath $LogPath -Encoding UTF8
  return $false
}

function New-Slides($article, [int]$number) {
  $topic = Get-TopicLabel $article
  $summary = Short-Text $article.summary 118
  if (-not $summary) { $summary = 'RSS 요약이 짧습니다. 카드 제작 전 원문에서 수치와 문맥 확인이 필요합니다.' }
  $title = Short-Text $article.title 86
  $source = Short-Text $article.source 28
  $region = if ($article.region) { $article.region } else { '전국' }
  $category = if ($article.category) { $article.category } else { '주택공급' }

  if ([string]$article.title -match '인천 구월2 공공주택지구 토지거래허가구역') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='구월2 공공주택지구'; title='허가구역 1년 연장'; body='5.43㎢ 재지정·2027년 9월 20일까지' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='총 15,996가구 계획'; body="공공임대|4,843가구`n공공분양|4,857가구`n전체 계획|15,996가구`n현재 성격|공공주택지구 공급 계획" },
      [pscustomobject]@{ type='table'; kicker='현재 적용 범위'; title='인천 4개 동·5.43㎢'; body="연수구|선학동`n남동구|구월동·남촌동·수산동`n대상|개발제한구역 일원`n기간|2027년 9월 20일까지" },
      [pscustomobject]@{ type='table'; kicker='거래 조건'; title='허가받아야 거래 가능'; body="허가 주체|관할 구청장`n주택 취득|2년 실거주 목적`n허가 기준|주거 60㎡ 초과·상업 150㎡ 초과`n녹지 기준|100㎡ 초과" },
      [pscustomobject]@{ type='table'; kicker='위반 시'; title='취득가 10%까지 이행강제금'; body="먼저|최대 3개월 이행명령`n미이행 시|토지 취득가의 최대 10%`n지정 목적|투기성 거래 차단`n보호 대상|실수요자 중심 거래" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='계획과 확정을 구분'; body="1. 지구계획과 실제 공급 일정`n2. 공공임대·분양별 입주자 공고`n3. 2027년 만료 전 재연장 여부`n4. 기간 내 토지거래는 허가 필요" }
    )
  }

  if ([string]$article.title -match 'LH 부채 2030년 373조') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='LH 재무 전망'; title='197.5조 → 372.8조'; body='2030년까지 부채 175.3조원 증가 전망' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='공급 확대의 재무 부담'; body="2026년 부채|197.5조원`n2030년 전망|372.8조원`n증가액|175.3조원`n근거|공공기관 중장기재무관리계획" },
      [pscustomobject]@{ type='table'; kicker='착공 계획'; title='2028년부터 연 10만가구'; body="2026년|5만가구`n2027년|7만6,000가구`n2028~2030년|매년 10만가구 이상`n2030년까지|연평균 12만가구 공급 목표" },
      [pscustomobject]@{ type='table'; kicker='부채비율'; title='250.6% → 351.2%'; body="2026년|250.6%`n2030년 전망|351.2%`n상승 폭|100.6%포인트`n배경|착공·매입임대 투자 확대" },
      [pscustomobject]@{ type='table'; kicker='공실 체크'; title='장기공실 8,279가구'; body="매입임대 재고|203,247가구`n6개월 이상 공실|8,279가구`n전국 공가율|4.1%`n수도권 장기공실|반년간 47.7% 증가" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='부채와 공급효율을 함께'; body="1. 372.8조원은 2030년 전망치`n2. 착공 확대에 따른 실제 자금 집행`n3. 지역·주택유형별 공실 변화`n4. 공급량과 수요·입지의 일치 여부" }
    )
  }

  if ([string]$article.title -match '모아타운 후보지 도로.*5년간') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='서울 모아타운'; title='후보지 도로 5년 규제'; body='9월 16일부터 토지거래허가구역 지정' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='골목길 지분 거래 차단'; body="적용 대상|사업구역 내 지목이 도로인 토지`n규제 목적|사도 지분 쪼개기 투기 차단`n허가 주체|관할 구청장`n이용 의무|신고한 목적대로 사용" },
      [pscustomobject]@{ type='table'; kicker='현재 단계'; title='3개 구 심의 예정'; body="심의 대상|마포구·노원구·서초구 3개 구역`n전문가 자문회의|9월 9일`n서울시보 공고|9월 11일`n주의|최종 후보지로 선정된 지역만 적용" },
      [pscustomobject]@{ type='table'; kicker='지정 기간'; title='2026.09.16~2031.09.15'; body="시작|2026년 9월 16일`n종료|2031년 9월 15일`n기간|5년`n지정 범위|최종 선정지의 도로 토지" },
      [pscustomobject]@{ type='table'; kicker='허가 기준'; title='도로 지분도 면적 확인'; body="주거지역|6㎡ 초과`n상업·공업지역|15㎡ 초과`n녹지지역|20㎡ 초과`n계약 전|소유권·지상권 이전은 허가 필요" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='아직 대상지는 최종 전'; body="1. 9월 9일 최종 후보지 선정 결과`n2. 9월 11일 서울시보의 정확한 경계`n3. 토지 지목과 허가 대상 면적`n4. 후보지 선정과 사업 확정을 구분" }
    )
  }

  if ([string]$article.title -match '부천대장 공공분양.*하우스토리 디센트') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='부천대장 A-2블록'; title='공공분양 548가구'; body='전용 59~84㎡·2026년 10월 공급 예정' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='부천대장 첫 공공분양'; body="사업지|부천대장 공공주택지구 A-2블록`n단지명|하우스토리 디센트`n공급 규모|총 548가구`n공급 시기|2026년 10월 예정" },
      [pscustomobject]@{ type='table'; kicker='주택형'; title='전용 59~84㎡ 구성'; body="전용 59㎡|A·B·C 타입`n전용 74㎡|A 타입`n전용 84㎡|A 타입`n유형별 물량|입주자모집공고에서 확인" },
      [pscustomobject]@{ type='table'; kicker='사업 구조'; title='LH·남광토건 컨소시엄'; body="시행|LH·남광토건 컨소시엄`n시공|남광토건 컨소시엄`n공급 유형|공공분양 아파트`n현재 단계|10월 공급 예정 발표" },
      [pscustomobject]@{ type='table'; kicker='입지·일정'; title='대장역 예정지 인근'; body="교통 계획|대장홍대선 대장역 예정`n견본주택|부천시 원미구 상동 529-38`n개관 시기|2026년 10월 예정`n청약 일정|모집공고에서 최종 확인" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='공급 예정과 공고를 구분'; body="1. 특별·일반공급별 실제 배정 물량`n2. 분양가·소득·자산·거주지역 기준`n3. 청약 접수와 당첨자 발표 일정`n4. 대장홍대선은 예정 사업임을 구분" }
    )
  }

  if ([string]$article.title -match '공적주택 21만8000호.*청년월세') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='2027 국토부 예산안'; title='공적주택 21.8만호'; body='올해보다 12% 이상 확대·주택공급 예산 30조원' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='19.4만 → 21.8만호'; body="2026년|19.4만호`n2027년 계획|21.8만호`n증가 물량|2.4만호`n기준|정부 예산안의 공급·착공 계획" },
      [pscustomobject]@{ type='table'; kicker='공급 구성'; title='임대 17.2만호가 중심'; body="공공임대|17.2만호`n공공분양|3.4만호`n공공지원 민간임대|1.2만호`n합계|21.8만호" },
      [pscustomobject]@{ type='table'; kicker='청년 공급'; title='7.1만 → 10.6만호'; body="2026년|7.1만호`n2027년 계획|10.6만호`n증가 물량|3.5만호`n보편형 공공임대|3.6만호 추진" },
      [pscustomobject]@{ type='table'; kicker='예산 변화'; title='주택공급 예산 30조원'; body="2026년|21.2조원`n2027년 계획|30조원`n증가액|8.8조원`n국토부 전체 예산안|69조원" },
      [pscustomobject]@{ type='summary'; kicker='아직 확정 전'; title='국회 심의 뒤 최종 확정'; body="1. 현재는 2027년도 정부 예산안`n2. 공급 지역·주택형은 후속 공고 확인`n3. 청년 월세의 소득·지원액은 최종 지침 확인`n4. 착공 계획과 실제 입주 시점을 구분" }
    )
  }

  if ([string]$article.title -match '인천 계양 A6블록.*663') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='3기 신도시 공공분양'; title="인천계양 A6`n663가구"; body='전용 59~84㎡·일반공급은 9월 30일부터 접수' },
      [pscustomobject]@{ type='table'; kicker='공급 개요'; title='어떤 물량인가'; body="사업지|인천계양 A6블록`n공급 유형|LH 공공분양`n전체 규모|663가구`n주택형|전용 59~84㎡·13개 타입" },
      [pscustomobject]@{ type='table'; kicker='물량 구분'; title='사전청약 412가구 우선'; body="사전청약 당첨자|412가구 본청약 우선`n나머지 물량|특별공급·일반분양`n전체|663가구`n확인|유형별 세부 물량은 공고문 기준" },
      [pscustomobject]@{ type='table'; kicker='가격·규제'; title='59㎡ 5.3억·84㎡ 7.1억'; body="전용 59㎡|약 5억3,000만원`n전용 84㎡|약 7억1,000만원`n전매제한|3년`n실거주 의무|없음" },
      [pscustomobject]@{ type='table'; kicker='청약 일정'; title='9월 17일부터 순차 접수'; body="사전청약 당첨자|9월 17~18일`n일반공급 등|9월 30일~10월 2일`n당첨자 발표|2026년 10월`n계약·입주|12월 계약·2029년 6월 입주" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='공고문에서 볼 것'; body="1. 특별·일반공급별 실제 배정 물량`n2. 신청 자격과 소득·자산 기준`n3. 주택형별 분양가·옵션·납부 일정`n4. LH청약플러스 모집공고 변경 여부" }
    )
  }

  if ([string]$article.title -match '2026 하반기 주택매입 사업설명회') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='LH 주택매입'; title="9월 1일`n사업설명회"; body='신축매입 기준 완화·민간 참여를 통한 도심 공급 속도 확대' },
      [pscustomobject]@{ type='table'; kicker='현재 단계'; title='사업자 대상 기준 공개'; body="행사|2026년 하반기 주택매입 사업설명회`n일정|2026년 9월 1일`n장소|LH 경기남부지역본부`n대상|주택매입 사업 참여 민간사업자" },
      [pscustomobject]@{ type='table'; kicker='무엇이 달라지나'; title='참여 문턱을 낮춘다'; body="가격 산정|원가법 병행 적용 기준 공개`n토지 확보 요건|75%로 완화`n서류 심사|기준 완화`n정책 연계|정부 8·13 대책 후속" },
      [pscustomobject]@{ type='table'; kicker='사업 지원'; title='자금 부담도 낮춘다'; body="토지비|무이자 지원 방안`n상담|1대1 현장 상담부스`n목표|민간 사업 참여 확대`n방향|도심 주택 신속 공급" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='설명회 이후가 중요'; body="1. 원가법 적용 세부 기준과 대상`n2. 토지비 무이자 지원 조건`n3. 매입 신청·심사·약정 일정`n4. 실제 매입 물량과 공급 지역 공개" }
    )
  }

  if ([string]$article.title -match '장기전세 9361가구') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='서울 장기전세'; title="20년 만기`n9,361가구"; body='2027년부터 순차 도래·서울시는 연장과 분양전환 불가 방침' },
      [pscustomobject]@{ type='table'; kicker='만기 물량'; title='2031년 4,170가구로 증가'; body="2027년|310가구`n2028년|682가구`n2029년|1,747가구`n2030년|2,452가구`n2031년|4,170가구" },
      [pscustomobject]@{ type='table'; kicker='현재 제도'; title='최장 거주기간은 20년'; body="도입|2007년`n계약|2년마다 갱신 가능`n최장 거주|20년`n분양전환|기존 장기전세는 불가" },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='다음 무주택자 공급과 연결'; body="서울시 입장|순환 공급과 형평성 유지`n입주민 요구|연장 또는 분양전환`n평균 보증금|3억4,900만원`n서울 평균 전셋값 대비|약 54% 수준" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='만기 가구 지원책이 관건'; body="1. 고령자·저소득층 대체 주거 지원`n2. 다른 공공임대 연계 방안`n3. 2027년 첫 310가구 퇴거 절차`n4. 서울시 후속 주거복지 대책" }
    )
  }

  if ([string]$article.title -match '행복주택 1484세대') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='서울 행복주택'; title="1,484세대`n9월 청약"; body='월 임대료 25만원부터·청년·신혼부부·고령자 대상' },
      [pscustomobject]@{ type='table'; kicker='공급 구성'; title='당장 입주 물량과 예비자를 구분'; body="신규 단지|154세대`n잔여 공가|391세대`n예비 입주자|939세대`n합계|1,484세대" },
      [pscustomobject]@{ type='table'; kicker='임대 조건'; title='전용면적별 평균 조건'; body="29㎡ 이하|보증금 6,400만원·월 25만원`n39㎡ 이하|1억1,800만원·월 45만원`n49㎡ 이하|1억3,800만원·월 53만원`n59㎡ 이하|1억7,300만원·월 66만원" },
      [pscustomobject]@{ type='table'; kicker='신청 기준'; title='무주택·소득·자산 확인'; body="기준일|2026년 8월 28일`n소득|도시근로자 월평균 100% 이하`n총자산|3억4,500만원 이하`n자동차|4,542만원 이하" },
      [pscustomobject]@{ type='table'; kicker='청약 일정'; title='9월 9~11일 접수'; body="온라인 접수|9월 9~11일`n방문 접수|9월 10~11일`n서류 대상 발표|9월 21일`n당첨자 발표|2027년 1월 29일" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='실제 입주 가능 시점 체크'; body="1. 입주는 2027년 3월부터 예정`n2. 단지별 일정은 달라질 수 있음`n3. 대상별 소득·자산 기준 재확인`n4. SH 모집공고의 배치도·평면도 확인" }
    )
  }

  if ([string]$article.title -match '9월 첫주 3713가구') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='9월 첫째 주 분양'; title="3,713가구 공급`n모두 인천"; body='3개 단지·일반분양 2,387가구, 이번 주 확인할 숫자' },
      [pscustomobject]@{ type='number'; kicker='왜 중요한가'; title='일반분양 2,387가구'; body="전체 3,713가구 가운데`n약 64%가 일반분양 물량`n3개 단지가 모두 인천에 집중" },
      [pscustomobject]@{ type='table'; kicker='주요 단지'; title='두 곳부터 확인'; body="미추홀구|시티오씨엘9단지{br}오션파크뷰`n서구|검암역 푸르지오 라베뉴`n견본주택|전국 4곳 개관 예정`n기준|부동산R114 집계" },
      [pscustomobject]@{ type='table'; kicker='대표 단지 규모'; title='시티오씨엘 1,949가구'; body="위치|미추홀구 학익동`n규모|9개 동·최고 49층`n면적|전용 59~136㎡`n교통|2028년 학익역 개통 예정" },
      [pscustomobject]@{ type='table'; kicker='아직 확정 전'; title='예정과 공고를 구분'; body="학익역|2028년 개통 예정`n학교|용현학익초·학익중 개교 예정`n조망|일부 가구 서해 조망 가능`n청약 조건|단지별 모집공고 확인" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='청약 전 체크'; body="1. 단지별 특별·일반공급 일정`n2. 일반분양 물량과 주택형`n3. 분양가·자격·전매 제한`n4. 견본주택 개관 및 모집공고" }
    )
  }

  if ([string]$article.title -match '화성 1만호 공공주택') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='화성 공공주택 제안'; title="공공주택`n1만호 프로젝트"; body='화성특례시가 대통령 주재 국정설명회에서 정부에 건의' },
      [pscustomobject]@{ type='number'; kicker='핵심 숫자'; title='1만호'; body="화성특례시가 건의한`n공공주택 공급 프로젝트 규모`n현재는 정부 건의 단계" },
      [pscustomobject]@{ type='table'; kicker='현재 단계'; title='확정 사업이 아닌 정책 건의'; body="건의 주체|화성특례시`n건의 자리|민선 9기 시·군·구청장{br}국정설명회`n행사일|2026년 8월 27일`n상태|중앙정부에 정책 건의" },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='공급 확대와 연결'; body="목표|속도감 있는 주택 공급`n대상 지역|세부 대상지는 기사 미공개`n주택 유형|세부 유형은 기사 미공개`n일정|착공·입주 시점 미공개" },
      [pscustomobject]@{ type='table'; kicker='함께 건의한 현안'; title='지역 성장 과제도 제시'; body="시민협치|화성동행기구 소개`n에너지|수도권 재생에너지{br}공급 거점 조성`n상생|주민참여형 수익 공유 모델`n주택|1만호 공공주택 프로젝트" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='확정 여부를 볼 지점'; body="1. 중앙정부의 사업 반영 여부`n2. 대상지·주택 유형 공개`n3. 사업 주체와 재원 확정`n4. 지구 지정·인허가·착공 일정" }
    )
  }

  if ([string]$article.title -match '부천형 역세권 정비사업') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='부천 원도심 정비'; title="소새울역·송내역`n2곳 선정"; body='역세권 2곳과 원도심 5곳을 하나의 정비사업으로 연계' },
      [pscustomobject]@{ type='table'; kicker='선정 대상'; title='역세권 2곳 확정'; body="소새울역|소중어린이공원 일원{br}53,714.1㎡`n송내역|솔안말어린이공원 일원{br}53,535.4㎡`n선정 방식|현장 확인·실현 가능성 평가`n현재 단계|공모 대상지 선정" },
      [pscustomobject]@{ type='number'; kicker='왜 중요한가'; title='2곳 + 5곳'; body="역세권 고밀개발 2곳과`n원도심 결합 정비 대상지 5곳을`n하나의 정비구역으로 연계" },
      [pscustomobject]@{ type='table'; kicker='결합 대상'; title='원도심 5곳 연결'; body="소새울역 연계|원미동 115-1·59-3`n송내역 연계|삼정동 303-2`n추가 연계|오정동 559-5`n추가 연계|소사동 41-18" },
      [pscustomobject]@{ type='table'; kicker='현재와 다음 단계'; title='주민 동의 50%가 관건'; body="현재|대상지 선정 완료`n입안 요청|토지등소유자 50% 이상 동의`n후속|관련 정비계획 절차 진행`n목표|2027년까지 정비계획 수립" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='아직 확정되지 않은 것'; body="1. 주민 동의율과 입안 요청 시점`n2. 정비구역 경계·용적률·세대수`n3. 공원·주차장 등 기반시설 계획`n4. 정비계획 결정·고시 일정" }
    )
  }

  if ([string]$article.title -match '상계보람') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='노원구 재건축'; title="상계보람`n추진위 승인"; body='정비구역 지정 전 승인·4,483가구 재건축 계획' },
      [pscustomobject]@{ type='table'; kicker='현재 단계'; title='정비구역 지정 전 추진위 승인'; body="추진위 동의 시작|2026년 6월 11일`n승인 신청|2026년 7월 16일`n노원구 승인|2026년 8월 20일`n현재|정비구역 지정·고시 전" },
      [pscustomobject]@{ type='table'; kicker='계획 규모'; title='3,315 → 4,483가구'; body="기존|15층·21개 동·3,315가구`n계획|지하 3층~최고 45층`n계획 동수|41개 동`n계획 가구|총 4,483가구" },
      [pscustomobject]@{ type='table'; kicker='핵심 수치'; title='1,168가구 증가 계획'; body="가구 증가|1,168가구`n추진위 최종 동의율|약 55%`n현재 용적률|약 197%`n계획 용적률|299.99%" },
      [pscustomobject]@{ type='table'; kicker='다음 절차'; title='정비구역 고시 이후'; body="우선|정비구역 지정·고시`n이후|협력업체 선정`n조합 단계|조합설립 동의서 징구`n주의|4,483가구는 정비계획안 기준" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='재건축 단계 체크'; body="1. 현재는 추진위 승인 단계`n2. 정비구역 지정·고시는 아직 전`n3. 최고 45층·4,483가구 재건축 계획`n4. 확정 규모와 일정은 후속 결정 확인" }
    )
  }

  if ([string]$article.title -match '양주회천 A-26블록') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='LH 공공분양'; title="양주회천 A-26블록`n792가구 공급"; body='덕정역 도보권 공공분양 청약 일정과 면적 구성' },
      [pscustomobject]@{ type='table'; kicker='단지 개요'; title='어떤 물량인가'; body="위치|경기 양주회천 A-26블록`n유형|LH 공공분양주택`n공급 규모|총 792가구`n입주 예정|2029년 10월" },
      [pscustomobject]@{ type='table'; kicker='면적 구성'; title='59㎡부터 84㎡까지'; body="전용 59㎡|394가구`n전용 74㎡|168가구`n전용 84㎡|230가구`n설계|4베이·수납공간 적용" },
      [pscustomobject]@{ type='table'; kicker='청약 일정'; title='9월 접수 시작'; body="특별공급|9월 14~15일`n일반공급|9월 16~17일`n당첨자 발표|2026년 10월`n계약 체결|2026년 12월" },
      [pscustomobject]@{ type='summary'; kicker='입지·요약'; title='청약 전 체크'; body="1. GTX-C 개통 예정 덕정역 도보 500m 이내`n2. 총 792가구·전용 59~84㎡ 구성`n3. 입주는 2029년 10월 예정`n4. 자격·분양가는 LH 모집공고문 재확인" }
    )
  }
  if ([string]$article.title -match '모아주택 1호.*준공') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='서울 모아주택'; title="모아주택 1호`n광진 한양연립 준공"; body='기존 99세대에서 215세대로 재탄생' },
      [pscustomobject]@{ type='table'; kicker='사업 개요'; title='어디가 달라졌나'; body="위치|광진구 구의3동 한양연립`n기존|노후 저층주택 99세대`n준공|4개 동 215세대`n규모|지하 2층·지상 10~15층" },
      [pscustomobject]@{ type='table'; kicker='진행 속도'; title='착공부터 준공까지'; body="제도 도입|서울시 2022년`n착공|2024년 2월`n준공|2026년 8월 25일`n입주 시작|2026년 9월" },
      [pscustomobject]@{ type='table'; kicker='사업 변화'; title='6개 동에서 4개 동으로'; body="당초 계획|6개 동 211세대`n변경 계획|4개 동 215세대`n최고 높이|15층`n사업 방식|모아주택 정비" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='첫 준공의 의미'; body="1. 서울 모아주택 사업의 첫 준공 사례`n2. 통합심의 후 8개월 만에 착공`n3. 착공 후 2년 6개월 만에 준공`n4. 서울시는 2031년까지 4만호 착공 목표" }
    )
  }
  if ([string]$article.title -match '2028년부터 매년 10만 가구 착공') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='LH 공급 계획'; title="2028년부터`n연 10만 가구 착공"; body='정부 8·13 주택 신속공급 방안 후속 계획' },
      [pscustomobject]@{ type='table'; kicker='연도별 계획'; title='착공 물량 확대'; body="2026년|5만 가구`n2027년|7만6000가구`n2028~2030년|연평균 10만 가구 이상`n성격|LH 착공 계획" },
      [pscustomobject]@{ type='table'; kicker='발주 규모'; title='민간 참여도 확대'; body="2026년|14조9000억원`n2027년|25조7000억원`n향후 목표|연간 약 30조원`n협력|민간 건설업계와 공급 확대" },
      [pscustomobject]@{ type='table'; kicker='도심 공급'; title='유휴부지도 활용'; body="성대야구장|2026년 인허가·2027년 착공`n서울 강서 3곳|2028년 착공 계획`n학교용지 선도지|4곳`n대상|공항고·수오고·권선2중·흥이중" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='계획 단계 구분'; body="1. 2028년부터 연평균 10만 가구 이상 착공 계획`n2. 발주 규모는 연간 약 30조원 목표`n3. 도심 유휴부지·학교용지 사업 병행`n4. 실제 공급 시점은 인허가·착공 진행 확인" }
    )
  }
  if ([string]$article.title -match '계양신도시.*첫.*민간분양') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='3기 신도시'; title="계양 첫 입주·`n민간분양 시작"; body='12월 첫 입주, 10월 첫 민간분양 예정' },
      [pscustomobject]@{ type='table'; kicker='첫 입주'; title='12월 1285가구'; body="A2블록|747가구`nA3블록|538가구`n합계|1285가구`n의미|3기 신도시 첫 입주" },
      [pscustomobject]@{ type='table'; kicker='첫 민간분양'; title='카이브 유보라 1110가구'; body="블록|AC3·AC4`n면적|전용 84~93㎡`n규모|16개 동·총 1110가구`n분양 예정|2026년 10월" },
      [pscustomobject]@{ type='table'; kicker='신도시 규모'; title='약 1만8000가구 계획'; body="위치|인천 계양구 일원`n면적|약 335만㎡`n계획 주택|약 1만8000가구`n계획 인구|약 4만4000명" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='계양 공급 체크'; body="1. 12월 A2·A3블록 1285가구 첫 입주`n2. 10월 계양 첫 민간분양 예정`n3. 첫 민간단지는 1110가구 주상복합`n4. 분양 일정·조건은 모집공고에서 재확인" }
    )
  }

  if ([string]$article.title -match "'분양 성수기'.*3\.3만 가구") {
    return @(
      [pscustomobject]@{ type='cover'; kicker='9월 분양시장'; title='전국 33,268가구'; body='전월보다 74% 증가·서울 공급은 244가구' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='전월 대비 74% 증가'; body="전국 예정 물량|33,268가구`n전년 동기 대비|6% 증가`n전월 대비|74% 증가`n기준|임대 포함 예정 물량" },
      [pscustomobject]@{ type='table'; kicker='수도권 물량'; title='19,949가구 예정'; body="경기|11,686가구`n인천|8,019가구`n서울|3개 단지 244가구`n전월 대비|56% 증가" },
      [pscustomobject]@{ type='table'; kicker='지방 물량'; title='13,319가구 예정'; body="광주|3,216가구`n충남|2,025가구`n경남|1,963가구`n부산·울산|1,713·1,521가구" },
      [pscustomobject]@{ type='table'; kicker='주요 대단지'; title='어디에 많이 나오나'; body="산곡역 자이힐스테이트&하늘채|2,706가구`n아크메르동탄|1,808가구`n경기광주역 롯데캐슬 2단지|1,249가구`n더샵분당하이스트|1,149가구" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='예정과 확정은 다릅니다'; body="1. 33,268가구는 월간 분양 예정치`n2. 단지별 모집공고와 실제 일반분양 물량 확인`n3. 청약 일정 변경·연기 여부 확인`n4. 서울은 예정 물량이 244가구에 그침" }
    )
  }

  if ([string]$article.title -match '주택공급에 직 걸겠다.*예산 30조') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='2027 주택 예산'; title='주택공급 30조원'; body='올해보다 8.8조원 증가·공적주택 21.8만가구' },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='공급 예산 41.5% 증가'; body="주택공급 예산|30조원`n올해 대비|8.8조원 증가`n증가율|41.5%`n국토부 전체 예산|69조원" },
      [pscustomobject]@{ type='table'; kicker='공급 목표'; title='공적주택 21.8만가구'; body="2026년|19.4만가구`n2027년 계획|21.8만가구`n증가 폭|12% 이상`n기준|정부 예산안 공급 계획" },
      [pscustomobject]@{ type='table'; kicker='공공임대'; title='보편형 3.6만가구'; body="신규 투입|6.2조원`n공급 규모|3.6만가구`n청년 우선공급|2만가구`n특징|역세권·중형·장기거주형" },
      [pscustomobject]@{ type='table'; kicker='PF 지원'; title='착공 병목도 지원'; body="PF 이차보전|1,696억원`nPF 앵커리츠|1,000억원`n우선 관리|수도권 325개 사업장`n목표|자금난 사업장 조기 착공" },
      [pscustomobject]@{ type='summary'; kicker='다음 확인'; title='예산과 입주는 다릅니다'; body="1. 현재는 2027년도 정부 예산안`n2. 국회 심의 뒤 최종 예산 확정`n3. 인허가·지자체 협의 진행 여부 확인`n4. 공급 유형별 사업지·입주자 공고 확인" }
    )
  }

  if ([string]$article.title -match '의정부우정지구 A-2블록 공공분양주택 청약') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='LH 공공분양'; title="의정부우정 A-2`n174가구 본청약"; body='특별공급 147·일반공급 27가구, 9월 14일부터' },
      [pscustomobject]@{ type='table'; kicker='단지 개요'; title='총 463가구 단지'; body="위치|의정부시 녹양동 A-2블록`n규모|6개 동·지상 19~20층`n주택형|전용 59㎡ A·B`n입주 예정|2029년 5월" },
      [pscustomobject]@{ type='table'; kicker='공급 구분'; title='이번 접수는 174가구'; body="사전청약 당첨자|278가구`n이주자 공급|11가구`n특별공급|147가구`n일반공급|27가구" },
      [pscustomobject]@{ type='table'; kicker='분양가'; title='3.84억~4.13억원'; body="59A|3.88억~4.13억원`n59B|3.84억~4.08억원`n발코니 확장비|포함 기준`n적용|분양가상한제" },
      [pscustomobject]@{ type='table'; kicker='청약 조건'; title='제한사항 확인'; body="재당첨 제한|10년`n전매 제한|3년`n거주의무|없음`n지역 구분|비규제지역" },
      [pscustomobject]@{ type='summary'; kicker='청약 일정'; title='9월 14일부터 접수'; body="1. 사전청약 당첨자 9월 7~8일`n2. 특별공급 9월 14~15일`n3. 일반공급 9월 16~17일`n4. 당첨자 발표 10월 8일" }
    )
  }

  if ([string]$article.title -match '의정부우정|A-2블록|공공주택지구') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='공공분양'; title="의정부우정 A-2블록`n내달 청약"; body='총 463세대·전용 59㎡ 공공분양 핵심 정리' },
      [pscustomobject]@{ type='table'; kicker='단지 개요'; title='어떤 단지인가'; body="위치|경기도 의정부시 녹양동 일원`n블록명|의정부우정 공공주택지구{br}A-2`n유형|공공분양주택`n규모|총 463세대" },
      [pscustomobject]@{ type='table'; kicker='공급 물량'; title='실제 접수 물량 체크'; body="전체|463세대`n사전청약 당첨자|278세대`n특별·일반 공급|185세대`n면적|전용 59㎡ A·B" },
      [pscustomobject]@{ type='table'; kicker='가격·규제'; title='분양가와 제한'; body="평균 분양가|약 4억300만원`n전매제한|3년`n거주의무|없음`n입주 예정|2029년 5월" },
      [pscustomobject]@{ type='table'; kicker='입지 포인트'; title='녹양역·GTX-C 기대'; body="녹양역|약 1km 거리`n의정부역|GTX-C 예정`n광역도로|수도권제1순환·국도39`n생활권|기존 녹양택지 인접" },
      [pscustomobject]@{ type='summary'; kicker='요약'; title='청약 전 체크'; body="1. 의정부우정 A-2블록 공공분양 463세대`n2. 사전청약 당첨자 물량 제외 후 185세대 접수`n3. 특별공급·일반공급 날짜를 나눠 확인`n4. 청약자격·제한사항은 공고문 기준 재확인" }
    )
  }

  if ([string]$article.title -match '지연된 PF 사업장|PF 사업장|청년·신혼부부|신혼부부 보금자리') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='주택공급 정책'; title="멈춘 PF 사업장`n매입임대로 돌린다"; body='청년·신혼부부 보금자리 공급 방안 핵심 정리' },
      [pscustomobject]@{ type='table'; kicker='정책 개요'; title='무슨 내용인가'; body="대상|지연된 PF 사업장`n방식|LH 매입임대 전환`n목표|주택공급·사업 정상화`n성격|국토교통부 보도자료" },
      [pscustomobject]@{ type='table'; kicker='공급 방식'; title='어떻게 공급하나'; body="멈춘 사업장|공공 매입으로 재추진`n더딘 사업장|공급 속도 보완`n주택 유형|신축·기축 매입 활용`n입주 대상|청년·신혼부부 중심" },
      [pscustomobject]@{ type='table'; kicker='숫자 체크'; title='시범사업 성과도 언급'; body="작년 시범|신축매입 2.6천호`n올해 방향|신축·기축 모두 확대`n공급 주체|LH 중심`n세부 물량|후속 공고 확인" },
      [pscustomobject]@{ type='summary'; kicker='요약'; title='공급 관점 체크'; body="1. 지연 PF 사업장을 공공 매입임대로 전환`n2. 청년·신혼부부 주거 공급과 사업 정상화 동시 목표`n3. 실제 대상지와 입주자 모집은 후속 공고 확인`n4. 공급 속도는 매입 협의와 사업장별 여건이 변수" }
    )
  }

  if ([string]$article.title -match '사당동|남성역|사당로16길') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='신속통합기획'; title="남성역 10분`n사당동 신통기획 확정"; body='사당동 305-35 일대 신속통합기획 핵심 정리' },
      [pscustomobject]@{ type='table'; kicker='대상지'; title='어디인가'; body="위치|동작구 사당동 305-35 일대`n교통|7호선 남성역 도보 10분`n현황|사당로16길 폭 협소`n지형|높이차 최대 22m" },
      [pscustomobject]@{ type='table'; kicker='계획 규모'; title='약 970세대 추진'; body="주거단지|약 970세대`n최고층|최고 34층`n용도지역|제3종일반주거지역 상향`n사업성|보정계수 1.17 적용" },
      [pscustomobject]@{ type='table'; kicker='도로·보행'; title='접근성 개선이 핵심'; body="사당로16길|단계적 확폭`n차로 계획|3~4차로 확보`n진출입구|2곳으로 분산`n보행|공공보행통로 조성" },
      [pscustomobject]@{ type='table'; kicker='생활 기반'; title='지역 시설도 함께 본다'; body="공공기여|청소년수련시설 확충`n저층부|근린생활·커뮤니티 배치`n스카이라인|북측 고층·남측 저층`n연계|주변 개발사업과 연결" },
      [pscustomobject]@{ type='summary'; kicker='요약'; title='신통기획 체크'; body="1. 사당동 305-35 일대 신통기획 확정`n2. 남성역 접근성과 도로 개선이 핵심 포인트`n3. 약 970세대·최고 34층 계획`n4. 정비구역 지정과 후속 인허가 단계는 계속 확인" }
    )
  }

  if ([string]$article.title -match '상계보람') {
    $caption = @("🏗️ 상계보람아파트, 정비구역 지정 전 추진위 승인",'',"📌 현재 사업 단계","노원구는 8월 20일 상계보람아파트 조합설립추진위원회 구성을 승인했습니다. 현재는 정비구역 지정·고시 전 단계입니다.",'',"🏢 계획 규모","기존 최고 15층, 21개 동, 3,315가구를 지하 3층~지상 최고 45층, 41개 동, 총 4,483가구로 재건축하는 정비계획안입니다.",'',"🔢 숫자로 보면","기존보다 1,168가구가 늘어나는 계획이며 추진위 최종 동의율은 약 55%로 알려졌습니다. 계획용적률은 299.99%입니다.",'',"✅ 확인할 것","정비구역 지정·고시 이후 협력업체 선정과 조합설립 동의 절차가 이어질 예정입니다. 4,483가구와 일정은 후속 결정 과정에서 다시 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '양주회천 A-26블록') {
    $caption = @("🏢 양주회천 A-26블록 공공분양 792가구",'',"📌 전용 59~84㎡ 구성","전용 59㎡ 394가구, 74㎡ 168가구, 84㎡ 230가구로 구성됩니다. 입주는 2029년 10월 예정입니다.",'',"🗓️ 청약 일정","특별공급은 9월 14~15일, 일반공급은 9월 16~17일 접수합니다. 10월 당첨자 발표 후 12월 계약 체결 예정입니다.",'',"🚆 입지 체크","GTX-C 개통 예정인 덕정역과 도보 500m 이내입니다. 신청 자격과 분양가는 LH청약플러스 모집공고문에서 다시 확인하세요.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '모아주택 1호.*준공') {
    $caption = @("🏙️ 서울 모아주택 1호, 광진 한양연립 준공",'',"📌 99세대에서 215세대로","광진구 구의3동 한양연립이 지하 2층, 지상 10~15층, 4개 동 215세대 단지로 재탄생했습니다.",'',"⏱️ 사업 진행","2024년 2월 착공해 2026년 8월 25일 준공됐으며, 9월부터 입주를 시작합니다. 통합심의 후 8개월 만에 착공하고 착공 후 2년 6개월 만에 준공한 사례입니다.",'',"✅ 의미","서울시는 모아주택·모아타운을 통해 2031년까지 4만호 착공을 목표로 제시했습니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '2028년부터 매년 10만 가구 착공') {
    $caption = @("🏗️ LH, 2028년부터 연평균 10만 가구 이상 착공 계획",'',"📌 연도별 착공 계획","2026년 5만 가구, 2027년 7만6000가구를 착공한 뒤 2028~2030년에는 연평균 10만 가구 이상을 착공할 계획입니다.",'',"💰 발주 규모","2026년 14조9000억원, 2027년 25조7000억원을 거쳐 향후 연간 약 30조원 규모 발주를 목표로 합니다.",'',"✅ 확인할 것","도심 유휴부지와 학교용지를 활용한 공급도 병행됩니다. 실제 공급 시점은 인허가·착공 진행 상황과 구분해 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '계양신도시.*첫.*민간분양') {
    $caption = @("🏙️ 계양신도시, 첫 입주와 첫 민간분양 시작",'',"📌 12월 첫 입주","A2블록 747가구와 A3블록 538가구, 총 1285가구가 12월 입주를 시작할 예정입니다.",'',"🏢 10월 첫 민간분양","AC3·AC4블록에서 전용 84~93㎡, 총 1110가구 규모의 계양신도시 카이브 유보라가 분양될 예정입니다.",'',"✅ 확인할 것","계양신도시는 약 335만㎡에 약 1만8000가구를 공급하는 계획입니다. 실제 분양 일정과 조건은 모집공고에서 다시 확인하세요.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '검암역 푸르지오 프라베뉴') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='공공분양'; title="검암역세권`n첫 공공분양 체크"; body='검암역 푸르지오 프라베뉴 입주자 모집 공고 기준 핵심만 정리' },
      [pscustomobject]@{ type='table'; kicker='단지 개요'; title='어떤 물량인가'; body="위치|인천검암역세권 B1블록`n규모|지하 2층~지상 25층, 3개 동`n총세대|441세대`n유형|민간참여 공공분양" },
      [pscustomobject]@{ type='table'; kicker='면적 구성'; title='60㎡·84㎡ 중심'; body="60㎡|150세대`n84㎡|291세대`n공급 성격|검암 공공주택지구 첫 공공분양`n체크|입주자 모집공고문 기준 재확인" },
      [pscustomobject]@{ type='table'; kicker='청약 일정'; title='접수일을 먼저 보세요'; body="모집공고|2026년 8월 21일`n특별공급|2026년 8월 31일`n일반공급|2026년 9월 1~2일`n당첨자 발표|2026년 9월 8일" },
      [pscustomobject]@{ type='table'; kicker='조건 체크'; title='규제 조건은 이렇게'; body="분양가|분양가상한제 적용`n전매제한|3년`n재당첨제한|10년`n거주의무기간|없음" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='청약 전 체크'; body="1. 검암역세권 B1블록 441세대 공공분양`n2. 특별공급 8월 31일, 일반공급 9월 1~2일`n3. 전매제한·재당첨제한은 공고문 기준 확인`n4. 청약 전 공급유형·자격·분양가 재확인" }
    )
  }

  if ([string]$article.title -match '기부채납') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='주택공급 정책'; title="기부채납 완화`n공급 속도 빨라질까"; body='8.13 주택 신속공급 방안 중 민간택지 부담 완화 포인트' },
      [pscustomobject]@{ type='table'; kicker='무엇이 문제였나'; title='사업부지 일부를 내야 했다'; body="기부채납|도로·공원 등 기반시설 제공`n현행 부담|사업부지의 최대 8~25%`n영향|사업비 부담 증가`n쟁점|민간택지 공급 지연 요인" },
      [pscustomobject]@{ type='table'; kicker='완화 방향'; title='수도권 한시 완화'; body="적용 대상|수도권 주택건설사업`n2027년까지|승인 시 4%p 완화`n2028년까지|승인 시 2%p 완화`n예외|필수 기반시설은 완화 제외" },
      [pscustomobject]@{ type='table'; kicker='일반 사업'; title='8%에서 4%까지'; body="현행|최대 8%`n2027년까지|최대 4%`n2028년|최대 6%`n적용 방식|사업 유형별 세부 기준 확인" },
      [pscustomobject]@{ type='table'; kicker='용도지역 변경'; title='변경 사업도 완화'; body="용도지역 내 변경|18% → 14% → 16%`n용도지역 간 변경|25% → 21% → 23%`n기준 시점|사업계획 승인 연도`n확인|세부 적용은 지침 기준" },
      [pscustomobject]@{ type='summary'; kicker='요약'; title='공급 관점 체크'; body="1. 기부채납 부담을 낮춰 사업성 개선 유도`n2. 수도권은 승인 시점에 따라 완화 폭 차등`n3. 일반 사업은 2027년까지 최대 4%로 완화`n4. 실제 공급 효과는 인허가·사업성 개선 속도 확인" }
    )
  }

  if ([string]$article.title -match '대구.?경북 광역철도|대구.?경북.*신공항|서대구.*의성') {
    return @(
      [pscustomobject]@{ type='cover'; kicker='교통·SOC'; title="통합신공항까지`n25분 전망"; body='대구·경북 광역철도 예타 통과 핵심 정리' },
      [pscustomobject]@{ type='table'; kicker='사업 개요'; title='어떤 노선인가'; body="구간|서대구역~중앙선 의성역`n총연장|70.06km 복선전철`n신설 구간|64.97km`n성격|통합신공항 접근 철도" },
      [pscustomobject]@{ type='table'; kicker='핵심 숫자'; title='3.2조 규모 사업'; body="총사업비|3조 1813억원`n예타 착수|2024년 6월`n예타 통과|약 2년 2개월 만`n계획 반영|제4차 국가철도망구축계획" },
      [pscustomobject]@{ type='number'; kicker='시간 단축'; title="62분 → 25분"; body="서대구역에서`n대구경북통합신공항까지`n승용차 기준 62분에서`n광역철도 이용 시 25분 전망" },
      [pscustomobject]@{ type='table'; kicker='왜 중요한가'; title='생활권이 바뀔 수 있다'; body="공항 접근|대구경북통합신공항 접근성 개선`n생활권|대구·경북 주요 지역 1시간권 연결`n지역 영향|초광역 경제권 형성 기대`n산업 효과|지역 산업 활성화 기대" },
      [pscustomobject]@{ type='table'; kicker='다음 절차'; title='예타 다음은 기본계획'; body="현재 단계|예비타당성조사 통과`n후속 절차|기본계획 수립`n추가 절차|타당성 평가·기본·실시설계`n체크|착공·개통 시점은{br}후속 고시 확인" },
      [pscustomobject]@{ type='summary'; kicker='요약'; title='교통 호재 체크'; body="1. 대구·경북 광역철도 예타 통과`n2. 서대구~의성 70.06km 복선전철 추진`n3. 대구경북통합신공항 접근시간 25분 전망`n4. 실제 일정은 기본계획·설계 단계에서 재확인" }
    )
  }

  if ([string]$article.title -match '신통기획|현장형 신통|현장 자문|노원구 재건축') {
    if ($number -eq 12 -or [string]$article.source -match '뉴스1') {
      return @(
        [pscustomobject]@{ type='cover'; kicker='서울 정비사업'; title="신통기획 자문`n처음으로 현장에 갔다"; body='서류 검토 중심에서 현장 여건 확인 방식으로 확장된 첫 사례' },
        [pscustomobject]@{ type='table'; kicker='대상지'; title='어디에서 열렸나'; body="지역|서울 노원구`n대상|중계그린·중계주공4단지`n방식|현장형 신속통합기획 자문`n의미|서울시 첫 현장 자문" },
        [pscustomobject]@{ type='table'; kicker='달라진 점'; title='도면만 보지 않는다'; body="기존|시청에서 정비계획안 도서 검토`n이번|자문위원·시·구 관계자 현장 방문`n확인|단지 여건·기반시설`n목표|정비계획 주요 사항 현장 반영" },
        [pscustomobject]@{ type='table'; kicker='노원 흐름'; title='추진위 승인도 이어진다'; body="상계보람|8월 19일 추진위 구성 승인`n하계미성|8월 31일 승인 예정`n고시|9월 초 예정`n공통점|정비계획 입안 절차 본격화" },
        [pscustomobject]@{ type='table'; kicker='세대수'; title='두 단지 숫자 체크'; body="상계보람|3,315세대 → 4,483세대 추진`n상계보람 높이|최고 45층`n하계미성|685세대 → 1,020세대 추진`n하계미성 높이|최고 49층" },
        [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='재건축 관점 체크'; body="1. 현장형 신통기획 자문 첫 사례`n2. 중계그린·중계주공4단지 현장 확인`n3. 노원구 추진위 승인 흐름도 가속`n4. 단지별 정비계획 확정 전 단계는 계속 확인" }
      )
    }

    return @(
      [pscustomobject]@{ type='cover'; kicker='노원구 재건축'; title="중계·상계·하계`n재건축 속도 붙나"; body='서울시 첫 현장형 신속통합기획 자문과 노원구 추진위 승인 흐름 정리' },
      [pscustomobject]@{ type='table'; kicker='첫 현장 자문'; title='중계그린·중계주공4단지'; body="대상|중계그린·중계주공4단지`n주체|서울시·노원구·자문위원`n확인|단지 여건·기반시설`n차이|시청 서류 검토에서 현장 확인으로 확대" },
      [pscustomobject]@{ type='table'; kicker='왜 중요할까'; title='정비계획 속도와 연결'; body="핵심|현장 여건을 계획에 빠르게 반영`n효과|사업기간 단축 기대`n주의|자문이 곧 인허가 확정은 아님`n체크|정비구역 지정·정비계획 결정 단계" },
      [pscustomobject]@{ type='table'; kicker='상계보람'; title='4,483세대 추진'; body="현재|3,315세대`n계획|최고 45층, 4,483세대`n용적률|299.99% 적용`n단계|정비구역 지정·정비계획 결정 앞둠" },
      [pscustomobject]@{ type='table'; kicker='하계미성'; title='1,020세대 추진'; body="현재|685세대`n계획|최고 49층, 1,020세대`n용적률|379% 고밀도 개발 추진`n절차|하반기 주민공람·설명회 등 예정" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='노원 재건축 체크'; body="1. 노원구 총 45개 단지 재건축 추진`n2. 현장형 신통기획 자문 첫 적용`n3. 상계보람·하계미성 추진위 승인 흐름`n4. 확정 물량은 정비계획 결정 이후 재확인" }
    )
  }

  $numbers = Get-KeyNumbers "$($article.title) $($article.summary)"
  $numberText = ($numbers -join ' · ')

  return @(
    [pscustomobject]@{ type='cover'; kicker=$topic; title=(Get-ReferenceHookTitle $article); body="$title" },
    [pscustomobject]@{ type='table'; kicker='핵심만 보면'; title='그래서 뭐가 바뀌나'; body="분류|$category`n지역|$region`n출처|$source`n키워드|$topic" },
    [pscustomobject]@{ type='number'; kicker='숫자 체크'; title=$numberText; body=$summary },
    [pscustomobject]@{ type='table'; kicker='확인 포인트'; title='추진 단계와 일정을 나눠보세요'; body="추진 단계|기사에서 확인된 범위 중심`n일정|변경 가능성 함께 체크`n수치|보도 기준일 기준`n영향권|위치·노선·생활권 구분" },
    [pscustomobject]@{ type='summary'; kicker='요약'; title='공급 관점 체크'; body="1. 발표 내용과 실제 추진 단계를 구분`n2. 공급 물량·위치·일정을 함께 확인`n3. 교통·생활권 영향은 후속 절차까지 추적`n4. 투자·청약 판단은 공식 공고와 함께 비교" }
  )
}

$baseCss = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic","Apple SD Gothic Neo",sans-serif;background:#081426;color:#fff}.slide{width:1080px;height:1350px;position:relative;padding:150px 120px 94px;display:flex;flex-direction:column;justify-content:flex-start;align-items:flex-start;overflow:hidden;background:radial-gradient(circle at 16% 18%,rgba(31,90,219,.30),transparent 27%),radial-gradient(circle at 84% 82%,rgba(245,166,35,.16),transparent 24%),linear-gradient(160deg,#102A43 0%,#0A1726 46%,#050910 100%)}.slide:before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(255,255,255,.040) 1px,transparent 1px),linear-gradient(0deg,rgba(255,255,255,.028) 1px,transparent 1px);background-size:96px 96px;mask-image:linear-gradient(180deg,rgba(0,0,0,.52),rgba(0,0,0,.12));opacity:.42}.slide:after{content:"";position:absolute;left:0;top:0;bottom:0;width:14px;background:linear-gradient(180deg,#1F5ADB,#F5A623 58%,transparent)}.inner{position:relative;z-index:2;width:100%;height:100%;display:flex;flex-direction:column;padding-top:118px}.count{position:absolute;z-index:3;left:120px;top:72px;color:rgba(255,255,255,.76);font-size:25px;font-weight:850;letter-spacing:.8px}.count:before{content:"SLIDE ";color:#F5A623}.kicker{align-self:flex-start;background:rgba(31,90,219,.94);color:#fff;border-radius:12px;padding:13px 22px;font-size:25px;font-weight:950;margin-bottom:32px;text-align:center;max-width:780px;box-shadow:0 12px 36px rgba(31,90,219,.22)}.title{font-size:60px;line-height:1.22;letter-spacing:-2.2px;font-weight:950;word-break:keep-all;max-width:840px;text-align:left;white-space:pre-line;text-shadow:0 3px 18px rgba(0,0,0,.38)}.body{font-size:31px;line-height:1.62;color:rgba(255,255,255,.88);margin-top:34px;text-align:left;white-space:pre-line;font-weight:750;word-break:keep-all;max-width:820px}.accent{width:168px;height:10px;border-radius:0;background:linear-gradient(90deg,#F5A623,#1F5ADB);margin:34px 0 24px}.footer{position:absolute;z-index:3;left:120px;right:120px;bottom:52px;display:flex;justify-content:space-between;gap:24px;border-top:1px solid rgba(255,255,255,.20);padding-top:26px;font-size:22px;color:rgba(255,255,255,.68)}.footer span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rows{width:100%;margin-top:34px;display:grid;grid-template-columns:1fr 1fr;gap:18px}.row{min-height:138px;border:1px solid rgba(255,255,255,.20);border-radius:22px;padding:22px 24px;background:linear-gradient(180deg,rgba(255,255,255,.095),rgba(255,255,255,.045));display:flex;flex-direction:column;justify-content:center;gap:13px}.row .label{font-size:24px;font-weight:900;color:rgba(255,255,255,.82)}.row .value{font-size:30px;line-height:1.25;font-weight:950;color:#F5A623;text-align:left;word-break:keep-all;overflow-wrap:normal}.cover .inner{justify-content:center;padding-top:0;padding-bottom:58px}.cover .kicker{position:absolute;top:170px;left:0;background:rgba(245,166,35,.95);color:#09111F;font-size:52px;line-height:1.15;letter-spacing:-1.3px;padding:20px 30px;border-radius:18px}.cover .title{font-size:68px;max-width:780px}.cover .body{font-size:52px;line-height:1.3;letter-spacing:-1.3px;font-weight:500;color:#D9E2EC;max-width:780px}.table .title{font-size:56px;margin-bottom:10px;max-width:820px}.number .kicker{background:rgba(255,255,255,.10);color:#F5A623;border:1px solid rgba(245,166,35,.32);padding:12px 20px;margin-bottom:26px}.number .title{font-size:76px;color:#F5A623;letter-spacing:-2px}.number .body{font-size:34px;color:#fff;line-height:1.55;max-width:820px;background:rgba(255,255,255,.08);border-radius:26px;padding:28px 32px}.summary .kicker{background:rgba(255,255,255,.10);color:#F5A623;border:1px solid rgba(245,166,35,.32)}.summary .title{font-size:62px}.summary .body{font-size:35px;color:#fff;line-height:1.70;border-left:0;padding-left:0;background:rgba(255,255,255,.085);border-radius:28px;padding:34px 38px}
.photo-bg{position:absolute;inset:0;z-index:0;background-size:cover;background-position:center;opacity:.82;filter:saturate(.95) contrast(1.12);pointer-events:none}.photo-bg:after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(5,10,18,.84) 0%,rgba(6,13,24,.72) 44%,rgba(6,13,24,.50) 100%),linear-gradient(180deg,rgba(8,20,38,.18),rgba(0,0,0,.74));}.cover .photo-bg{opacity:.88}.table .photo-bg{opacity:.80}.summary .photo-bg{opacity:.82}
.slide{padding-left:150px;padding-right:150px}.count{left:150px}.footer{left:150px;right:150px}.title,.body{max-width:780px}
'@

$brand = if ($config.account) { $config.account } else { '@landbrief.daily' }
$displayDate = try { ([datetime]::Parse($Date)).ToString('yyyy.MM.dd') } catch { $Date }

function Get-PhotoBgCss([string]$Path) {
  if (-not $Path) { return '' }
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  $photoBgUrl = 'file:///' + ($Path -replace '\\', '/')
  return ".photo-bg{background-image:url('$photoBgUrl')}"
}

function Find-ArticleBackground([string]$OutputDir, [string]$ArticleNumber, [string]$ProjectRoot) {
  $bgDir = Join-Path $OutputDir 'article-backgrounds'
  foreach ($ext in @('jpg','jpeg','png','webp')) {
    $candidate = Join-Path $bgDir ("article-$ArticleNumber-bg.$ext")
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }

  $outputDate = Split-Path -Leaf $OutputDir
  $assetBgDir = Join-Path $ProjectRoot (Join-Path 'assets\article-backgrounds' $outputDate)
  foreach ($ext in @('jpg','jpeg','png','webp')) {
    $candidate = Join-Path $assetBgDir ("article-$ArticleNumber-bg.$ext")
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }

  return ''
}

$chromeProfileDir = Join-Path $outDir '_chrome-profile'
if (-not $NoRender) {
  New-Item -ItemType Directory -Path $chromeProfileDir -Force | Out-Null
}
$createdSets = @()

foreach ($index in $indexes) {
  $article = $candidates[$index - 1]
  if ([string]$article.source -eq 'gukjenews.com') { $article.source = '국제뉴스' }
  if ([string]$article.source -eq 'Chosunbiz') { $article.source = '조선비즈' }
  if ([string]$article.source -eq 'etoday.co.kr') { $article.source = '이투데이' }
  $setName = 'article-{0:D2}-carousel' -f $index
  $setDir = Join-Path $outDir $setName
  New-Item -ItemType Directory -Path $setDir -Force | Out-Null
  $detailPath = Join-Path $setDir 'article-detail.json'
  $articleNumber = '{0:D2}' -f $index
  $setPhotoBgCss = Get-PhotoBgCss (Find-ArticleBackground -OutputDir $outDir -ArticleNumber $articleNumber -ProjectRoot $root)
  $detail = $null
  if (Test-Path -LiteralPath $detailPath) {
    $detail = Get-Content -LiteralPath $detailPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }

  $slides = @(New-Slides $article $index)
  $articleDisplayDate = $displayDate
  if ($article.publishedKstDate) {
    try { $articleDisplayDate = ([datetime]::Parse([string]$article.publishedKstDate)).ToString('yyyy.MM.dd') } catch { $articleDisplayDate = [string]$article.publishedKstDate }
  }
  if ([string]$article.title -match '화성 1만호 공공주택|부천형 역세권 정비사업') { $articleDisplayDate = '2026.08.28' }
  if ($slides.Count -lt 5 -or $slides.Count -gt 8) { throw "슬라이드 수 규칙 위반: $setName / $($slides.Count)장" }

  for ($i = 0; $i -lt $slides.Count; $i++) {
    $slide = $slides[$i]
    $num = '{0:D2}' -f ($i + 1)
    $safeTitle = (Html $slide.title) -replace "`n", '<br>'
    $safeBody = (Html $slide.body) -replace "`n", '<br>'
    $bodyHtml = "<div class='body'>$safeBody</div>"
    if ($slide.type -eq 'table') {
      $rows = @()
      foreach ($line in ([string]$slide.body -split "`n")) {
        $parts = $line -split '\|', 2
        if ($parts.Count -eq 2) {
          $safeValue = (Html $parts[1]) -replace '\{br\}', '<br>'
          $rows += "<div class='row'><div class='label'>$(Html $parts[0])</div><div class='value'>$safeValue</div></div>"
        }
      }
      $bodyHtml = "<div class='rows'>$($rows -join '')</div>"
    }
    $accent = if ($slide.type -eq 'cover') { "<div class='accent'></div>" } else { '' }
    $doc = "<!doctype html><html lang='ko'><head><meta charset='utf-8'><style>$baseCss$setPhotoBgCss</style></head><body><main class='slide $($slide.type)'><div class='photo-bg'></div><div class='count'>$($i+1)/$($slides.Count)</div><div class='inner'><div class='kicker'>$(Html $slide.kicker)</div><div class='title'>$safeTitle</div>$accent$bodyHtml</div><div class='footer'><span>출처: $(Html $article.source) ($articleDisplayDate)</span><span>$(Html $brand)</span></div></main></body></html>"
    $htmlPath = Join-Path $setDir "$num.html"
    $pngPath = Join-Path $setDir "$num.png"
    Set-Content -LiteralPath $htmlPath -Value $doc -Encoding UTF8

    if (-not $NoRender) {
      if (Test-Path -LiteralPath $pngPath) { Remove-Item -LiteralPath $pngPath -Force }
      $rendered = Invoke-BrowserScreenshot -HtmlPath $htmlPath -PngPath $pngPath -ProfileBaseDir $chromeProfileDir -LogPath (Join-Path $setDir 'chrome-render.log')
      if (-not $rendered) {
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

  $hashtagList = @(Get-ArticleHashtags $article)
  $hashtags = $hashtagList -join ' '
  if ([string]$article.title -match 'LH 부채 2030년 373조') {
    $caption = @("🏘️ LH 부채가 2030년 372조8,000억원으로 늘어날 전망입니다",'',"📌 부채 변화","공공기관 중장기재무관리계획에 따르면 LH 부채는 2026년 197조5,000억원에서 2030년 372조8,000억원으로 175조3,000억원 증가할 전망입니다.",'',"🏗️ 공급 계획","LH는 2026년 5만가구, 2027년 7만6,000가구를 착공하고 2028년부터 2030년까지 매년 10만가구 이상 착공할 계획입니다.",'',"🔢 함께 볼 숫자","부채비율은 250.6%에서 351.2%로 높아질 전망입니다. 6개월 이상 비어 있는 매입임대주택은 올해 6월 기준 8,279가구로 집계됐습니다.",'',"🔎 다음 확인","372조8,000억원은 전망치입니다. 실제 착공·자금 집행과 지역별 공실, 수요가 있는 입지에 공급되는지를 함께 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '모아타운 후보지 도로.*5년간') {
    $caption = @("🛣️ 서울 모아타운 후보지의 도로가 5년간 토지거래허가구역으로 지정됩니다",'',"📌 적용 대상","9월 9일 전문가 자문회의 심의 대상인 마포·노원·서초구 3개 구역 가운데 최종 후보지로 선정되는 지역의 ‘도로’ 토지에 적용됩니다.",'',"🗓️ 일정","최종 지정 범위는 9월 11일 서울시보에 공개되고, 9월 16일부터 2031년 9월 15일까지 5년간 효력이 적용됩니다.",'',"🔎 거래 전 확인","주거지역 6㎡, 상업·공업지역 15㎡, 녹지지역 20㎡를 초과하는 토지의 소유권·지상권 이전 계약은 관할 구청장 허가가 필요합니다.",'',"✅ 다음 확인","현재 3개 구역 모두가 최종 지정된 것은 아닙니다. 후보지 선정 결과와 서울시보의 정확한 경계, 토지 지목을 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '부천대장 공공분양.*하우스토리 디센트') {
    $caption = @("🏢 부천대장 첫 공공분양, 하우스토리 디센트 548가구가 10월 공급될 예정입니다",'',"📌 공급 규모","부천대장 공공주택지구 A-2블록에 총 548가구가 공급됩니다. 전용 59㎡ A·B·C, 74㎡ A, 84㎡ A 타입으로 구성됩니다.",'',"🏗️ 사업 구조","시행은 LH·남광토건 컨소시엄, 시공은 남광토건 컨소시엄이 맡습니다. 현재는 10월 공급 예정이 발표된 단계입니다.",'',"🚆 입지·일정","대장홍대선 대장역 예정지 인근이며 견본주택은 부천시 원미구 상동 529-38 일원에 마련될 예정입니다.",'',"🔎 다음 확인","특별·일반공급별 물량과 분양가, 소득·자산·지역 기준, 청약 일정은 입주자모집공고에서 최종 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '인천 구월2 공공주택지구 토지거래허가구역') {
    $caption = @("🗺️ 구월2 공공주택지구, 토지거래허가구역이 1년 연장됐습니다",'',"📌 현재 적용","인천 연수구 선학동과 남동구 구월·남촌·수산동 개발제한구역 일원 5.43㎢가 2027년 9월 20일까지 허가구역으로 재지정됐습니다.",'',"🏘️ 계획 규모","구월2 공공주택지구에는 총 15,996가구가 계획돼 있습니다. 이 가운데 공공임대 4,843가구, 공공분양 4,857가구입니다.",'',"🔎 거래 전 확인","토지거래는 관할 구청장 허가가 필요하고 주택은 2년 실거주 목적이어야 합니다. 주거 60㎡, 상업 150㎡, 녹지 100㎡를 초과하면 허가 대상입니다.",'',"✅ 다음 확인","지구계획과 실제 공급 일정, 유형별 입주자 모집공고, 2027년 만료 전 재연장 여부를 구분해 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '공적주택 21만8000호.*청년월세') {
    $caption = @("🏘️ 2027년 공적주택 공급 계획은 21만8,000호입니다",'',"📌 공급 변화","2026년 19만4,000호에서 2만4,000호 늘어난 규모입니다. 공공임대 17만2,000호, 공공분양 3만4,000호, 공공지원 민간임대 1만2,000호로 구성됩니다.",'',"🧑‍💼 청년 주거","청년 대상 주택 공급은 7만1,000호에서 10만6,000호로 확대하는 계획입니다. 보편형 공공임대 3만6,000호 추진 내용도 예산안에 담겼습니다.",'',"💰 예산 변화","주택공급 예산은 21조2,000억원에서 30조원으로 8조8,000억원 늘어납니다. 국토부 전체 예산안은 69조원입니다.",'',"🔎 다음 확인","현재는 정부 예산안 단계입니다. 국회 심의 결과와 공급 지역, 실제 입주자 모집공고, 청년 월세 지원의 최종 소득·지원 기준을 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '인천 계양 A6블록.*663') {
    $caption = @(
      "🏢 인천계양 A6블록 공공분양 663가구가 공급됩니다",
      '',
      "📌 공급 규모",
      "전용 59~84㎡, 13개 타입으로 구성됩니다. 2023년 사전청약을 받은 단지로 사전청약 당첨자 412가구의 본청약이 먼저 진행됩니다.",
      '',
      "💰 가격·규제",
      "분양가는 전용 59㎡ 약 5억3,000만원, 84㎡ 약 7억1,000만원 수준입니다. 전매제한은 3년이며 실거주 의무는 없습니다.",
      '',
      "🗓️ 청약 일정",
      "사전청약 당첨자는 9월 17~18일, 특별·일반공급 대상자는 9월 30일부터 10월 2일까지 접수합니다. 입주는 2029년 6월 예정입니다.",
      '',
      "🔎 다음 확인",
      "공급 유형별 물량과 신청 자격, 소득·자산 기준, 주택형별 분양가는 LH청약플러스 모집공고에서 다시 확인해야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      '#인천계양신도시 #인천계양A6 #LH공공분양 #공공분양청약 #3기신도시'
    ) -join "`r`n"
  } elseif ([string]$article.title -match '2026 하반기 주택매입 사업설명회') {
    $caption = @(
      "🏗️ LH가 하반기 주택매입 사업의 참여 기준을 공개합니다",
      '',
      "📌 현재 단계",
      "9월 1일 LH 경기남부지역본부에서 민간사업자를 대상으로 2026년 하반기 주택매입 사업설명회를 개최합니다.",
      '',
      "🔄 달라지는 기준",
      "신축매입 가격 산정에 원가법을 병행하고, 토지 확보 요건을 75%로 완화합니다. 서류심사 기준도 낮춰 사업 참여 문턱을 줄이는 내용입니다.",
      '',
      "💰 지원 내용",
      "토지비 무이자 지원 방안과 1대1 현장 상담이 제공됩니다. 목적은 민간 참여 확대와 도심 주택공급 속도 제고입니다.",
      '',
      "🔎 다음 확인",
      "설명회 이후 원가법 적용 대상, 무이자 지원 조건, 매입 신청·심사 일정과 실제 매입 물량을 확인해야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      '#LH주택매입 #신축매입임대 #도심주택공급 #LH사업설명회 #주택공급정책'
    ) -join "`r`n"
  } elseif ([string]$article.title -match '장기전세 9361가구') {
    $caption = @(
      "🏢 서울 장기전세 9,361가구, 20년 만기가 시작됩니다",
      '',
      "📌 현재 단계",
      "2027년 310가구를 시작으로 향후 5년간 총 9,361가구가 최장 거주기간 20년을 순차적으로 채웁니다.",
      '',
      "🔢 만기 물량",
      "2028년 682가구, 2029년 1,747가구, 2030년 2,452가구, 2031년 4,170가구로 늘어납니다.",
      '',
      "🔎 왜 중요한가",
      "입주민은 거주 연장이나 분양전환을 요구하지만 서울시는 순환 공급과 형평성을 이유로 불가 방침을 밝혔습니다.",
      '',
      "✅ 다음 확인",
      "고령자·저소득층의 대체 주거 지원과 다른 공공임대·주거복지 제도 연계 방안이 후속 확인 지점입니다.",
      '',
      "출처: $($article.source)",
      '',
      '#서울장기전세 #장기전세주택 #공공임대주택 #서울주거정책 #임대주택'
    ) -join "`r`n"
  } elseif ([string]$article.title -match '행복주택 1484세대') {
    $caption = @(
      "🏠 서울 행복주택 1,484세대, 9월 9일부터 청약합니다",
      '',
      "📌 공급 구성",
      "신규 단지 154세대, 잔여 공가 391세대, 예비 입주자 939세대입니다. 전체 물량 중 예비 입주자 비중을 구분해서 확인해야 합니다.",
      '',
      "💰 임대 조건",
      "전용 29㎡ 이하는 평균 보증금 6,400만원·월 25만원이며, 면적별로 보증금과 월 임대료가 달라집니다.",
      '',
      "🗓️ 청약 일정",
      "온라인 접수는 9월 9~11일, 고령자·장애인 방문 접수는 9월 10~11일입니다. 최종 당첨자는 2027년 1월 29일 발표 예정입니다.",
      '',
      "🔎 다음 확인",
      "무주택·소득·자산 기준은 공급 대상별로 다를 수 있습니다. 단지별 입주 일정과 세부 자격은 SH 모집공고에서 확인해야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      '#서울행복주택 #SH공사 #행복주택청약 #서울공공임대 #청년주택'
    ) -join "`r`n"
  } elseif ([string]$article.title -match '9월 첫주 3713가구') {
    $caption = @(
      "🏢 9월 첫째 주 3,713가구, 모두 인천에서 공급됩니다",
      '',
      "📌 전체 공급 물량",
      "전국 3개 단지에서 총 3,713가구가 공급되며, 이 가운데 일반분양은 2,387가구입니다. 3개 단지가 모두 인천에 집중됐습니다.",
      '',
      "🏙️ 주요 단지",
      "미추홀구 시티오씨엘9단지 오션파크뷰와 서구 검암역 푸르지오 라베뉴 등의 청약이 진행됩니다. 시티오씨엘9단지는 총 1,949가구, 최고 49층 규모입니다.",
      '',
      "🔎 다음 확인",
      "단지별 특별·일반공급 일정과 주택형, 분양가, 신청 자격은 입주자 모집공고에서 확인해야 합니다. 학익역과 학교 개교 일정은 아직 예정 단계입니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '화성 1만호 공공주택') {
    $caption = @(
      "🏗️ 화성특례시, 공공주택 1만호 프로젝트를 정부에 건의했습니다",
      '',
      "📌 현재 단계",
      "화성특례시가 대통령 주재 민선 9기 시·군·구청장 국정설명회에서 1만호 공공주택 공급 프로젝트를 정책 과제로 건의했습니다.",
      '',
      "🔢 핵심 숫자",
      "제안된 공급 규모는 1만호입니다. 다만 대상지와 주택 유형, 사업 주체, 착공·입주 일정은 기사에서 공개되지 않았습니다.",
      '',
      "🔎 다음 확인",
      "현재는 확정 사업이 아닌 정책 건의 단계입니다. 중앙정부 반영 여부와 대상지 공개, 재원·사업 주체, 지구 지정과 인허가 일정을 순서대로 확인해야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '부천형 역세권 정비사업') {
    $caption = @(
      "🏙️ 부천형 역세권 정비사업, 소새울역·송내역 2곳이 선정됐습니다",
      '',
      "📌 선정 대상",
      "소새울역 소중어린이공원 일원과 송내역 솔안말어린이공원 일원이 대상지로 선정됐습니다. 두 역세권과 원도심 결합 정비 대상지 5곳을 연계하는 방식입니다.",
      '',
      "🗺️ 왜 중요한가",
      "역세권 주거지역의 고밀개발과 떨어진 원도심 정비 지역을 하나의 정비구역으로 묶어 추진하는 부천형 모델입니다.",
      '',
      "🔎 다음 확인",
      "현재는 대상지 선정 단계입니다. 토지등소유자 50% 이상의 동의를 얻어 입안을 요청해야 하며, 부천시는 2027년까지 정비계획 수립 완료를 목표로 하고 있습니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '검암역 푸르지오 프라베뉴') {
    $caption = @(
      "인천 검암역 푸르지오 프라베뉴 청약 체크",
      '',
      "▪ 검암역세권 B1블록 첫 공공분양",
      "인천도시공사가 검암역세권 B1블록 '검암역 푸르지오 프라베뉴' 입주자 모집 공고를 냈습니다. 보도 기준 총 441세대, 전용 60㎡ 150세대·84㎡ 291세대 구성입니다.",
      '',
      "▪ 일정",
      "특별공급 2026년 8월 31일, 일반공급 2026년 9월 1~2일, 당첨자 발표 2026년 9월 8일 순서로 보도됐습니다.",
      '',
      "▪ 확인할 것",
      "분양가상한제 적용, 전매제한 3년, 재당첨제한 10년, 거주의무기간 없음 조건을 함께 확인하세요.",
      "청약 전 공급유형, 신청자격, 분양가, 제한사항은 입주자 모집공고문에서 다시 확인하세요.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '주택공급에 직 걸겠다.*예산 30조') {
    $caption = @("🏘️ 2027년 주택공급 예산안이 30조원으로 확대됐습니다",'',"💰 예산 변화","주택공급 관련 예산은 올해 21조2,000억원에서 내년 30조원으로 8조8,000억원, 41.5% 늘어납니다. 정부는 이를 바탕으로 공적주택 21만8,000가구 공급을 계획했습니다.",'',"🏠 공공임대·청년 공급","보편형 공공임대에 6조2,000억원을 새로 투입해 역세권 등에서 3만6,000가구를 공급하고, 이 가운데 2만가구를 청년에게 우선 공급할 계획입니다.",'',"🏗️ PF 지원","조기 착공 사업장의 PF 대출 금융비용 지원에 1,696억원, 주택사업장 PF 앵커리츠에 1,000억원을 배정했습니다.",'',"🔎 다음 확인","현재는 2027년도 정부 예산안 단계입니다. 국회 심의 결과와 사업지별 인허가, 실제 착공 및 입주자 모집공고를 구분해 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match "'분양 성수기'.*3\.3만 가구") {
    $caption = @("🏢 9월 전국 분양 예정 물량은 33,268가구입니다",'',"📌 얼마나 늘었나","임대 물량을 포함해 전년 동기보다 6%, 전월보다 74% 증가한 규모입니다. 수도권은 19,949가구, 지방은 13,319가구가 예정됐습니다.",'',"🗺️ 지역별 차이","경기 11,686가구, 인천 8,019가구인 반면 서울은 3개 단지 244가구에 그칩니다. 지방에서는 광주가 3,216가구로 가장 많습니다.",'',"🔎 다음 확인","33,268가구는 월간 예정치입니다. 단지별 모집공고, 실제 일반분양 물량, 청약 일정 변경 여부를 함께 확인해야 합니다.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '의정부우정지구 A-2블록 공공분양주택 청약') {
    $caption = @("🏠 의정부우정 A-2블록, 174가구 본청약을 진행합니다",'',"📌 공급 물량","총 463가구 가운데 사전청약 당첨자 278가구와 이주자 공급 11가구를 제외하고 특별공급 147가구, 일반공급 27가구를 접수합니다.",'',"💰 분양가·규제","발코니 확장비를 포함한 공급가는 전용 59㎡ 기준 약 3.84억~4.13억원입니다. 분양가상한제가 적용되며 재당첨 제한 10년, 전매 제한 3년, 거주의무 없음 조건입니다.",'',"🗓️ 청약 일정","특별공급은 9월 14~15일, 일반공급은 9월 16~17일이며 당첨자 발표는 10월 8일입니다. 신청 전 LH 모집공고문의 자격과 자금 일정을 다시 확인하세요.",'',"출처: $($article.source)",'',$hashtags) -join "`r`n"
  } elseif ([string]$article.title -match '의정부우정|A-2블록|공공주택지구') {
    $caption = @(
      "🏢 의정부우정 A-2블록, 내달 청약 시작",
      '',
      "📌 LH 공공분양 463세대",
      "의정부우정 공공주택지구 A-2블록 공공분양주택이 본청약 일정에 들어갑니다. 보도 기준 전체 463세대 중 사전청약 당첨자 278세대를 제외한 185세대가 특별공급·일반공급으로 나옵니다.",
      '',
      "🔢 숫자로 보면",
      "전용 59㎡ A·B 타입, 평균 분양가는 약 4억300만원으로 보도됐습니다. 전매제한은 3년, 거주의무는 없는 것으로 안내됐습니다.",
      '',
      "🗓️ 일정 체크",
      "사전청약 당첨자 본청약 9월 7~8일, 특별공급 9월 14~15일, 일반공급 9월 16~17일 순서입니다.",
      '',
      "✅ 확인할 것",
      "녹양역 접근성, GTX-C 의정부역 예정 효과, 청약자격과 제한사항은 입주자 모집공고문 기준으로 다시 확인하세요.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '지연된 PF 사업장|PF 사업장|청년·신혼부부|신혼부부 보금자리') {
    $caption = @(
      "🏗️ 멈춘 PF 사업장, 청년·신혼부부 주택으로 전환",
      '',
      "📌 국토교통부 공급 보완책",
      "지연된 PF 사업장을 LH 매입임대 방식으로 전환해 청년·신혼부부 보금자리 공급과 사업 정상화를 함께 추진하겠다는 내용입니다.",
      '',
      "🔎 핵심은",
      "공급이 지연된 사업장을 공공이 매입해 임대주택으로 활용하는 방식입니다. 신축뿐 아니라 기축 매입까지 함께 활용해 공급 속도를 보완하는 방향으로 보도됐습니다.",
      '',
      "✅ 확인할 것",
      "실제 전환 대상지, 입주자 모집 일정, 지역별 공급 물량은 후속 공고에서 확인해야 합니다. 정책 발표와 실제 입주 가능 시점은 구분해서 봐야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '기부채납') {
    $caption = @(
      "🏗️ 수도권 주택공급, 기부채납 부담 낮아진다",
      '',
      "📌 국토교통부, 주택건설사업 기부채납 부담 완화",
      "민간택지 주택건설사업에서 도로·공원 등 기반시설을 제공해야 하는 기부채납 부담을 한시적으로 낮춰 주택 공급을 촉진하겠다는 내용입니다.",
      '',
      "🔢 숫자로 보면",
      "수도권 주택건설사업은 사업계획 승인 시점에 따라 2027년까지 4%p, 2028년까지 2%p 완화됩니다. 일반 주택건설사업은 최대 8% 기준이 2027년까지 최대 4%, 2028년에는 최대 6%로 조정됩니다.",
      '',
      "✅ 확인할 것",
      "필수 기반시설은 완화 대상에서 제외될 수 있고, 실제 공급 효과는 사업계획 승인·인허가 속도와 사업성 개선 여부를 함께 봐야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '대구.?경북 광역철도|대구.?경북.*신공항|서대구.*의성') {
    $caption = @(
      "🚆 대구·경북 광역철도, 예타 통과",
      '',
      "📌 서대구~의성 70.06km 복선전철",
      "국토교통부는 대구·경북 광역철도 건설사업이 예비타당성조사를 통과했다고 밝혔습니다. 대구경북통합신공항 접근성을 높이고 대구와 경북을 하나의 생활권으로 연결하는 사업입니다.",
      '',
      "🔢 숫자로 보면",
      "총연장은 70.06km, 이 중 신설 노선은 64.97km입니다. 총사업비는 예타 기준 3조1813억원으로 보도됐습니다.",
      '',
      "⏱️ 달라지는 점",
      "서대구역에서 대구경북통합신공항까지 이동시간은 승용차 기준 62분에서 광역철도 이용 시 25분으로, 약 37분 단축될 전망입니다.",
      '',
      "✅ 확인할 것",
      "이번 단계는 예타 통과입니다. 실제 착공·개통 일정은 기본계획 수립, 타당성 평가, 기본·실시설계 등 후속 절차를 계속 확인해야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '사당동|남성역|사당로16길') {
    $caption = @(
      "🏙️ 남성역 도보권 사당동, 신통기획 확정",
      '',
      "📌 사당동 305-35 일대 신속통합기획",
      "서울시가 동작구 사당동 305-35 일대 신속통합기획을 확정했습니다. 7호선 남성역 도보 10분권 입지와 협소한 사당로16길 개선이 핵심 포인트입니다.",
      '',
      "🔢 숫자로 보면",
      "보도 기준 약 970세대, 최고 34층 규모 주거단지로 계획됐습니다. 제3종일반주거지역 상향과 사업성 보정계수 1.17 적용도 함께 언급됐습니다.",
      '',
      "🚶 달라지는 점",
      "사당로16길 단계적 확폭, 진출입구 2곳 분산, 공공보행통로 조성, 청소년수련시설 확충 등이 계획에 담겼습니다.",
      '',
      "✅ 확인할 것",
      "신통기획 확정은 중요한 진전이지만, 실제 사업 속도와 공급 시점은 정비구역 지정·사업시행인가 등 후속 절차를 계속 봐야 합니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  } elseif ([string]$article.title -match '신통기획|현장형 신통|현장 자문|노원구 재건축') {
    if ($index -eq 12 -or [string]$article.source -match '뉴스1') {
      $caption = @(
        "서울시 첫 현장형 신통기획 자문, 뭐가 달라졌을까",
        '',
        "▪ 중계그린·중계주공4단지에서 첫 현장 자문",
        "서울시가 노원구 중계그린과 중계주공4단지를 대상으로 신속통합기획 자문회의를 처음 현장에서 열었습니다. 기존처럼 도면과 서류만 보는 방식에서 벗어나 단지 여건과 기반시설을 현장에서 함께 확인했다는 점이 핵심입니다.",
        '',
        "▪ 숫자로 보면",
        "상계보람아파트는 기존 3,315세대에서 최고 45층, 4,483세대 규모 재건축을 추진 중입니다. 하계미성아파트는 기존 685세대에서 최고 49층, 1,020세대 규모로 계획됐습니다.",
        '',
        "▪ 확인할 것",
        "이번 자문은 사업기간 단축 기대를 키우는 절차지만, 단지별 물량과 계획은 정비구역 지정·정비계획 결정 등 후속 절차에서 다시 확인해야 합니다.",
        '',
        "출처: $($article.source)",
        '',
        $hashtags
      ) -join "`r`n"
    } else {
      $caption = @(
        "노원구 재건축, 현장형 신통기획 자문으로 속도 붙나",
        '',
        "▪ 서울시 첫 현장형 신속통합기획 자문",
        "노원구 중계그린과 중계주공4단지에서 서울시 최초의 현장형 신속통합기획 자문회의가 열렸습니다. 자문위원과 시·구 관계자가 현장을 찾아 단지 여건과 기반시설을 확인한 것이 기존 서류 중심 자문과 다른 점입니다.",
        '',
        "▪ 노원구 흐름",
        "상계보람아파트는 8월 19일 조합설립추진위원회 구성이 승인됐고, 하계미성아파트도 8월 31일 승인 및 9월 초 고시가 예정됐습니다. 노원구에서는 총 45개 단지가 재건축사업을 추진 중으로 보도됐습니다.",
        '',
        "▪ 확인할 것",
        "현장 자문은 정비계획의 완성도를 높이는 절차입니다. 실제 사업 속도와 공급 물량은 정비계획 결정, 인허가, 주민 동의 흐름까지 함께 봐야 합니다.",
        '',
        "출처: $($article.source)",
        '',
        $hashtags
      ) -join "`r`n"
    }
  } else {
    $caption = @(
      "$($article.region) $($article.title)",
      '',
      "▪ $($article.title)",
      "$(Short-Text $article.summary 160)",
      '',
      "▪ 확인할 것",
      "발표 내용과 실제 추진 일정은 구분해서 확인하세요.",
      "공급 물량, 위치, 교통 영향권은 후속 공고와 행정 절차에 따라 달라질 수 있습니다.",
      '',
      "출처: $($article.source)",
      '',
      $hashtags
    ) -join "`r`n"
  }
  Set-Content -LiteralPath (Join-Path $setDir 'caption.txt') -Value $caption -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $setDir 'hashtags.txt') -Value ($hashtagList -join "`r`n") -Encoding UTF8

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
    try {
      Remove-Item -LiteralPath $resolvedProfile -Recurse -Force -ErrorAction Stop
    } catch {
      Write-Warning "Could not remove temporary browser profile directory: $resolvedProfile / $($_.Exception.Message)"
    }
  }
}

Write-Host "카드뉴스 완료: 선택 $($indexes -join ', ') / 기사별 $($createdSets.Count)세트 / $outDir"
