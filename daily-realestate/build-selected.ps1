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

  if ($text -match '검암역 푸르지오 프라베뉴') {
    foreach ($tag in @('인천청약','검암역세권','검암역푸르지오프라베뉴','공공분양','청약일정','분양정보','분양가상한제','전매제한','재당첨제한','인천부동산','검암동')) {
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

  if ([string]$article.title -match '검암역 푸르지오 프라베뉴') {
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
      [pscustomobject]@{ type='cover'; kicker='주택공급 정책'; title="기부채납 완화`n공급 속도 빨라질까"; body='8.13 주택 신속공급 방안 중 민간택지 사업 부담 완화 핵심 정리' },
      [pscustomobject]@{ type='table'; kicker='무엇이 문제였나'; title='사업부지 일부를 내야 했다'; body="기부채납|도로·공원 등 기반시설 부지 제공`n현행 부담|사업부지 최대 8~25%`n영향|사업비 부담 증가`n쟁점|민간택지 공급 지연 요인" },
      [pscustomobject]@{ type='table'; kicker='완화 방향'; title='수도권 한시 완화'; body="적용 대상|수도권 주택건설사업`n2027년까지|사업계획 승인 시 4%p 완화`n2028년까지|사업계획 승인 시 2%p 완화`n예외|필수 기반시설은 현 기준 적용" },
      [pscustomobject]@{ type='table'; kicker='일반 사업'; title='8%에서 4%까지'; body="현행|최대 8%`n2027년까지|최대 4%`n2028년|최대 6%`n친환경 인증|괄호 기준 별도 적용" },
      [pscustomobject]@{ type='table'; kicker='용도지역 변경'; title='변경 사업도 완화'; body="용도지역 내 변경|18% → 14% → 16%`n용도지역 간 변경|25% → 21% → 23%`n기준 시점|사업계획 승인 연도`n확인|세부 적용은 지침 기준" },
      [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='공급 관점 체크'; body="1. 기부채납 부담을 낮춰 사업성 개선 유도`n2. 수도권은 승인 시점에 따라 완화 폭 차등`n3. 일반 사업은 2027년까지 최대 4%로 완화`n4. 실제 공급 효과는 인허가·사업성 개선 속도 확인" }
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
    [pscustomobject]@{ type='table'; kicker='아직 봐야 할 것'; title='확정과 검토를 나눠보세요'; body="단계|원문 기준 확인`n일정|변경 가능성 체크`n수치|기사 기준일 확인`n이미지|공식 자료만 사용" },
    [pscustomobject]@{ type='summary'; kicker='핵심 요약'; title='저장 전 체크'; body="1. 발표인지 확정인지 구분`n2. 공급 물량·위치 다시 확인`n3. 일정은 원문 링크에서 재확인`n4. 애매한 내용은 제외" }
  )
}

$baseCss = @'
*{box-sizing:border-box}html,body{margin:0;width:1080px;height:1350px;overflow:hidden;font-family:Pretendard,"Noto Sans KR","Malgun Gothic",sans-serif;background:#081426;color:#fff}.slide{width:1080px;height:1350px;position:relative;padding:150px 92px 94px;display:flex;flex-direction:column;justify-content:flex-start;align-items:flex-start;overflow:hidden;background:radial-gradient(circle at 16% 18%,rgba(31,90,219,.30),transparent 27%),radial-gradient(circle at 84% 82%,rgba(245,166,35,.16),transparent 24%),linear-gradient(160deg,#102A43 0%,#0A1726 46%,#050910 100%)}.slide:before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(255,255,255,.055) 1px,transparent 1px),linear-gradient(0deg,rgba(255,255,255,.035) 1px,transparent 1px);background-size:96px 96px;mask-image:linear-gradient(180deg,rgba(0,0,0,.72),rgba(0,0,0,.18));opacity:.58}.slide:after{content:"";position:absolute;left:0;top:0;bottom:0;width:18px;background:linear-gradient(180deg,#1F5ADB,#F5A623 58%,transparent)}.inner{position:relative;z-index:2;width:100%;height:100%;display:flex;flex-direction:column;padding-top:118px}.count{position:absolute;z-index:3;left:92px;top:72px;color:rgba(255,255,255,.72);font-size:25px;font-weight:850;letter-spacing:.8px}.count:before{content:"SLIDE ";color:#F5A623}.kicker{align-self:flex-start;background:rgba(31,90,219,.92);color:#fff;border-radius:12px;padding:13px 22px;font-size:25px;font-weight:950;margin-bottom:32px;text-align:center;max-width:780px;box-shadow:0 12px 36px rgba(31,90,219,.22)}.title{font-size:62px;line-height:1.22;letter-spacing:-2.4px;font-weight:950;word-break:keep-all;max-width:880px;text-align:left;white-space:pre-line;text-shadow:0 3px 18px rgba(0,0,0,.35)}.body{font-size:31px;line-height:1.65;color:rgba(255,255,255,.76);margin-top:34px;text-align:left;white-space:pre-line;font-weight:650;word-break:keep-all;max-width:880px}.accent{width:168px;height:10px;border-radius:0;background:linear-gradient(90deg,#F5A623,#1F5ADB);margin:34px 0 24px}.footer{position:absolute;z-index:3;left:92px;right:92px;bottom:52px;display:flex;justify-content:space-between;gap:24px;border-top:1px solid rgba(255,255,255,.18);padding-top:26px;font-size:22px;color:rgba(255,255,255,.60)}.footer span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rows{width:100%;margin-top:34px;display:grid;grid-template-columns:1fr 1fr;gap:18px}.row{min-height:138px;border:1px solid rgba(255,255,255,.17);border-radius:22px;padding:24px 24px;background:linear-gradient(180deg,rgba(255,255,255,.085),rgba(255,255,255,.035));display:flex;flex-direction:column;justify-content:space-between}.row .label{font-size:24px;font-weight:900;color:rgba(255,255,255,.68)}.row .value{font-size:31px;line-height:1.32;font-weight:950;color:#F5A623;text-align:left;word-break:keep-all}.cover .inner{justify-content:center;padding-top:0;padding-bottom:58px}.cover .kicker{position:absolute;top:180px;left:0;background:rgba(245,166,35,.95);color:#09111F}.cover .title{font-size:68px;max-width:780px}.cover .body{font-size:30px;color:rgba(255,255,255,.72);max-width:830px}.table .title{font-size:58px;margin-bottom:10px}.number .kicker{background:rgba(255,255,255,.10);color:#F5A623;border:1px solid rgba(245,166,35,.32);padding:12px 20px;margin-bottom:26px}.number .title{font-size:80px;color:#F5A623;letter-spacing:-2px}.number .body{font-size:34px;color:#fff;line-height:1.55;max-width:860px;background:rgba(255,255,255,.07);border-radius:26px;padding:28px 32px}.summary .kicker{background:rgba(255,255,255,.10);color:#F5A623;border:1px solid rgba(245,166,35,.32)}.summary .title{font-size:64px}.summary .body{font-size:36px;color:#fff;line-height:1.72;border-left:0;padding-left:0;background:rgba(255,255,255,.075);border-radius:28px;padding:34px 38px}
.photo-bg{position:absolute;inset:0;z-index:0;background-size:cover;background-position:center;opacity:.74;filter:saturate(.92) contrast(1.08);pointer-events:none}.photo-bg:after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(5,10,18,.88) 0%,rgba(6,13,24,.76) 42%,rgba(6,13,24,.48) 100%),linear-gradient(180deg,rgba(8,20,38,.28),rgba(0,0,0,.78));}.cover .photo-bg{opacity:.82}.table .photo-bg{opacity:.66}.summary .photo-bg{opacity:.70}
'@

$brand = if ($config.account) { $config.account } else { '@landbrief.daily' }
$displayDate = try { ([datetime]::Parse($Date)).ToString('yyyy.MM.dd') } catch { $Date }
$photoBgPath = Join-Path $root 'assets\photoreal-urban-transit-bg-v1.png'
$photoBgCss = ''
if (Test-Path -LiteralPath $photoBgPath) {
  $photoBgUrl = 'file:///' + ($photoBgPath -replace '\\', '/')
  $photoBgCss = ".photo-bg{background-image:url('$photoBgUrl')}"
}
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
    $bodyHtml = "<div class='body'>$safeBody</div>"
    if ($slide.type -eq 'table') {
      $rows = @()
      foreach ($line in ([string]$slide.body -split "`n")) {
        $parts = $line -split '\|', 2
        if ($parts.Count -eq 2) {
          $rows += "<div class='row'><div class='label'>$(Html $parts[0])</div><div class='value'>$(Html $parts[1])</div></div>"
        }
      }
      $bodyHtml = "<div class='rows'>$($rows -join '')</div>"
    }
    $accent = if ($slide.type -eq 'cover') { "<div class='accent'></div>" } else { '' }
    $doc = "<!doctype html><html lang='ko'><head><meta charset='utf-8'><style>$baseCss$photoBgCss</style></head><body><main class='slide $($slide.type)'><div class='photo-bg'></div><div class='count'>$($i+1)/$($slides.Count)</div><div class='inner'><div class='kicker'>$(Html $slide.kicker)</div><div class='title'>$safeTitle</div>$accent$bodyHtml</div><div class='footer'><span>출처: $(Html $article.source) ($displayDate)</span><span>$(Html $brand)</span></div></main></body></html>"
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
  if ([string]$article.title -match '검암역 푸르지오 프라베뉴') {
    $caption = @(
      "인천 검암역 푸르지오 프라베뉴 청약 체크",
      '',
      "▪ 검암역세권 B1블록 첫 공공분양",
      "[핵심]",
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
  } elseif ([string]$article.title -match '기부채납') {
    $caption = @(
      "수도권 주택공급, 기부채납 부담 낮아진다",
      '',
      "▪ 국토교통부, 주택건설사업 기부채납 부담 완화",
      "[핵심]",
      "민간택지 주택건설사업에서 도로·공원 등 기반시설을 제공해야 하는 기부채납 부담을 한시적으로 낮춰 주택 공급을 촉진하겠다는 내용입니다.",
      '',
      "▪ 숫자로 보면",
      "수도권 주택건설사업은 사업계획 승인 시점에 따라 2027년까지 4%p, 2028년까지 2%p 완화됩니다. 일반 주택건설사업은 최대 8% 기준이 2027년까지 최대 4%, 2028년에는 최대 6%로 조정됩니다.",
      '',
      "▪ 확인할 것",
      "필수 기반시설은 완화 대상에서 제외될 수 있고, 실제 공급 효과는 사업계획 승인·인허가 속도와 사업성 개선 여부를 함께 봐야 합니다.",
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
        "[핵심]",
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
        "[핵심]",
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
      "[핵심]",
      "$(Short-Text $article.summary 160)",
      '',
      "▪ 확인할 것",
      "단계, 일정, 수치가 확정인지 검토인지 원문 기준으로 다시 봐야 합니다.",
      "이미지는 기사 내 공식 조감도·위치도·구역도·노선도만 사용합니다.",
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






