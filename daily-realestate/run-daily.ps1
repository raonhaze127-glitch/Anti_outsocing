param(
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
  [switch]$NoRender,
  [switch]$OpenReview
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$outDir = Join-Path $root (Join-Path 'output' $Date)
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Clean-Text([string]$value) {
  if (-not $value) { return '' }
  $decoded = [System.Net.WebUtility]::HtmlDecode($value)
  return (($decoded -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

function Html([string]$value) { return [System.Net.WebUtility]::HtmlEncode($value) }

function Test-RailPriority([string]$title) {
  $rail = $title -match '광역철도|도시철도|지하철|전철|철도|GTX|경전철|경강선|경춘선|경의중앙선|신분당선|신안산선|서해선|인덕원동탄선|동탄인덕원선|신림선|우이신설선|[0-9]+호선'
  $progress = $title -match '연장|신설|노선|예타|예비타당성|기본계획|기본 계획|승인|고시|착공|개통|역세권|신설역|사업비|공사|수혜'
  $noise = $title -match '기념|주년|공모|여행|축제|채용|슈퍼카|그래픽|보일러|화재|사고'
  return ($rail -and $progress -and -not $noise)
}

function Get-Score([string]$text) {
  $score = 0
  foreach ($prop in $config.priorityKeywords.PSObject.Properties) {
    foreach ($word in $prop.Value) { if ($text -match [regex]::Escape($word)) { $score += [int]$prop.Name } }
  }
  foreach ($word in $config.excludeKeywords) { if ($text -match [regex]::Escape($word)) { $score -= 20 } }
  foreach ($word in $config.authorityKeywords) { if ($text -match [regex]::Escape($word)) { $score += 12 } }
  return $score
}

function Get-Category([string]$text) {
  if (Test-RailPriority $text) { return '교통·SOC' }
  $rules = [ordered]@{
    '재개발·재건축' = '재개발|재건축|정비사업|모아타운|신속통합기획'
    '청약·분양' = '청약|분양|입주자모집|특별공급'
    '교통·SOC' = 'GTX|철도|지하철|도로|교통|SOC'
    '신도시·택지' = '신도시|택지|공공주택지구|도시개발'
  }
  foreach ($item in $rules.GetEnumerator()) { if ($text -match $item.Value) { return $item.Key } }
  return '주택공급'
}

function Get-ClusterKey([string]$title, [string]$summary) {
  $text = Clean-Text "$title $summary"
  $lower = $text.ToLowerInvariant()

  if ($text -match '용산공원|용산 공원') {
    if ($text -match '공공주택|주택공급|주택 공급') { return 'issue:yongsan-park-public-housing' }
  }
  if ($text -match '신통기획|신속통합기획|현장형 신통|현장 자문') {
    if ($text -match '노원|중계|상계|하계') { return 'issue:nowon-fast-track-reconstruction' }
    return 'issue:fast-track-reconstruction'
  }
  if ($text -match '기부채납') { return 'issue:contribution-burden-relief' }
  if ($text -match '신축매입|신축 매입') {
    if ($text -match 'LH|한국토지주택공사') { return 'issue:lh-new-build-purchase' }
  }

  $normalized = $lower
  $normalized = $normalized -replace '\s*-\s*[^-]{2,30}$', ''
  $normalized = $normalized -replace '[`"“”‘’''\[\]\(\),.·…％%]', ' '
  $normalized = $normalized -replace '\b\d+(?:\.\d+)?\b', ' '
  $normalized = $normalized -replace '\s+', ' '
  $tokens = @($normalized.Trim().Split(' ') | Where-Object { $_.Length -ge 2 } | Select-Object -First 8)
  if ($tokens.Count -eq 0) { return "title:$lower" }
  return 'title:' + ($tokens -join '-')
}

function Get-KoreaPublishedAt([string]$published) {
  if (-not $published) { return $null }
  try {
    $dt = [datetimeoffset]::Parse($published, [Globalization.CultureInfo]::InvariantCulture)
    $kst = [System.TimeZoneInfo]::FindSystemTimeZoneById('Korea Standard Time')
    return [System.TimeZoneInfo]::ConvertTime($dt, $kst)
  } catch {
    return $null
  }
}

function Get-KoreaPublishedDate([string]$published) {
  $kst = Get-KoreaPublishedAt $published
  if (-not $kst) { return '' }
  return $kst.ToString('yyyy-MM-dd')
}

function Get-KoreaPublishedText([string]$published) {
  $kst = Get-KoreaPublishedAt $published
  if (-not $kst) { return '' }
  return $kst.ToString('yyyy-MM-dd HH:mm')
}

$headers = @{ 'User-Agent' = 'Mozilla/5.0 (compatible; RealEstateDaily/1.0)' }
$items = @()
foreach ($query in $config.queries) {
  $encoded = [uri]::EscapeDataString("$query when:1d")
  $url = "https://news.google.com/rss/search?q=$encoded&hl=ko&gl=KR&ceid=KR:ko"
  try {
    [xml]$feed = (Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 20 -UseBasicParsing).Content
    foreach ($entry in $feed.rss.channel.item) {
      $title = Clean-Text ([string]$entry.title)
      $description = Clean-Text ([string]$entry.description)
      $source = if ($entry.source) { Clean-Text ([string]$entry.source.'#text') } else { '' }
      $sourceUrl = if ($entry.source -and $entry.source.url) { [string]$entry.source.url } else { '' }
      if ($source -and $title.EndsWith(" - $source")) { $title = $title.Substring(0, $title.Length - $source.Length - 3).Trim() }
      $combined = "$title $description $source"
      $region = @($config.regions | Where-Object { $combined -match [regex]::Escape($_) } | Select-Object -First 1)
      $items += [pscustomobject]@{
        title=$title; summary=$description; source=$source; sourceUrl=$sourceUrl; url=[string]$entry.link
        published=[string]$entry.pubDate; score=(Get-Score $combined)
        publishedKst=(Get-KoreaPublishedText ([string]$entry.pubDate))
        publishedKstDate=(Get-KoreaPublishedDate ([string]$entry.pubDate))
        category=(Get-Category $combined); region=if($region){$region[0]}else{'전국'}
        clusterKey=(Get-ClusterKey $title $description)
        railPriority=(Test-RailPriority $title)
      }
    }
  } catch {
    Add-Content -LiteralPath (Join-Path $outDir 'errors.log') -Value "[$(Get-Date -Format s)] $query :: $($_.Exception.Message)" -Encoding UTF8
  }
}

$minimumYear = ([int]$Date.Substring(0,4)) - 1
$blockedPattern = (($config.blockedSources | ForEach-Object {[regex]::Escape($_)}) -join '|')
$kstZone = [System.TimeZoneInfo]::FindSystemTimeZoneById('Korea Standard Time')
$nowKst = [System.TimeZoneInfo]::ConvertTime([datetimeoffset]::UtcNow, $kstZone)
$targetDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$isToday = $targetDate.Date -eq $nowKst.Date
$windowStart = $nowKst.AddHours(-24)
$candidates = @($items | Where-Object {
  $publishedAt = Get-KoreaPublishedAt ([string]$_.published)
  $inCollectionWindow = if ($isToday) {
    $publishedAt -and $publishedAt -ge $windowStart -and $publishedAt -le $nowKst
  } else {
    $_.publishedKstDate -eq $Date
  }
  $_.score -gt 0 -and
  $inCollectionWindow -and
  (-not $blockedPattern -or $_.source -notmatch $blockedPattern) -and
  $_.title -notmatch "\b(19|20)\d{2}\b.*\b(19|20)\d{2}\b" -and
  $_.title -notmatch "\([A-Za-z0-9_-]{8,}\)" -and
  -not ($_.title -match '\b(20\d{2})[./-]' -and [int]$Matches[1] -lt $minimumYear)
} | Sort-Object score -Descending | Group-Object clusterKey | ForEach-Object { $_.Group[0] } | Sort-Object score -Descending)
# Keep rail-project coverage within the cap, then order the displayed topic groups.
$railSlots = if ($config.railPrioritySlots) { [int]$config.railPrioritySlots } else { 5 }
$railFirst = @($candidates | Where-Object railPriority | Select-Object -First $railSlots)
$railKeys = @($railFirst | ForEach-Object { $_.clusterKey })
$remaining = @($candidates | Where-Object { $_.clusterKey -notin $railKeys })
$candidates = @(($railFirst + $remaining) | Select-Object -First $config.maxCandidates)
$candidates = @($candidates | Sort-Object @{Expression={
  if ($_.category -in @('주택공급','청약·분양')) { 0 }
  elseif ($_.category -eq '교통·SOC') { 1 }
  else { 2 }
}}, @{Expression={ $_.score }; Descending=$true})
$selectedList = [System.Collections.ArrayList]::new()
foreach ($category in @('재개발·재건축','청약·분양','교통·SOC','신도시·택지','주택공급')) {
  $pick = $candidates | Where-Object category -eq $category | Select-Object -First 1
  if ($pick -and $selectedList.Count -lt $config.publishCount) { [void]$selectedList.Add($pick) }
}
foreach ($pick in $candidates) {
  if ($selectedList.Count -ge $config.publishCount) { break }
  if (-not ($selectedList.title -contains $pick.title)) { [void]$selectedList.Add($pick) }
}
$selected = @($selectedList)
$candidates | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'candidates.json') -Encoding UTF8

$windowLabel = if ($isToday) { '최근 24시간' } else { $Date }
$articleMd = @("# $Date 부동산 공급 기사 후보", '', "> 수집 범위: $windowLabel / 최대 $($config.maxCandidates)건", '> 카드뉴스로 만들 기사 번호를 확인한 뒤 `selection.txt`에 쉼표로 구분해 입력하세요. 예: `1,3,7`', '')
$articleTxt = @("[$Date 부동산 공급 기사 후보]", "수집 범위: $windowLabel / 최대 $($config.maxCandidates)건", '')
for ($i=0; $i -lt $candidates.Count; $i++) {
  $n = $i + 1; $x = $candidates[$i]
  $articleMd += "## $n. $($x.title)"
  $articleMd += "- 분류/지역: $($x.category) / $($x.region)"
  $articleMd += "- 출처: $($x.source)"
  if ($x.publishedKst) { $articleMd += "- 발행: $($x.publishedKst) KST" }
  if ($x.sourceUrl) { $articleMd += "- 출처 사이트: $($x.sourceUrl)" }
  $articleMd += "- 링크: $($x.url)"
  $articleMd += ''
  $articleTxt += "$n. $($x.title)"
  $articleTxt += "   [$($x.category) / $($x.region)] $($x.source)"
  if ($x.sourceUrl) { $articleTxt += "   출처 사이트: $($x.sourceUrl)" }
  $articleTxt += "   $($x.url)"
  $articleTxt += ''
}
$articleMd -join "`r`n" | Set-Content -LiteralPath (Join-Path $outDir 'ARTICLES.md') -Encoding UTF8
$articleTxt -join "`r`n" | Set-Content -LiteralPath (Join-Path $outDir 'articles.txt') -Encoding UTF8
$selectionPath = Join-Path $outDir 'selection.txt'
if (-not (Test-Path -LiteralPath $selectionPath)) {
  "# 선택할 기사 번호를 입력하세요. 예: 1,3,7`r`n" | Set-Content -LiteralPath $selectionPath -Encoding UTF8
}
$originalUrlPath = Join-Path $outDir 'original-urls.json'
if (-not (Test-Path -LiteralPath $originalUrlPath)) {
  [ordered]@{
    note = '선택 기사 원문 URL을 알고 있으면 아래처럼 번호별로 입력하세요. 예: "1": "https://media.example.com/article"'
    urls = [ordered]@{}
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $originalUrlPath -Encoding UTF8
}
$collectStatus = [ordered]@{ runAt=(Get-Date -Format o); date=$Date; fetched=$items.Count; candidates=$candidates.Count; selected=0; slides=0; rendered=$false; state='awaiting_selection' }
$collectStatus | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outDir 'status.json') -Encoding UTF8
Write-Host "수집 완료: 후보 $($candidates.Count)건. ARTICLES.md에서 번호를 확인하고 selection.txt에 선택 번호를 입력하세요."
exit 0

