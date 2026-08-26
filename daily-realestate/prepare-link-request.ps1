param(
  [string]$RequestPath = '',
  [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RequestPath) { $RequestPath = Join-Path $root 'link-request.json' }
if (-not (Test-Path -LiteralPath $RequestPath)) { throw "Link request not found: $RequestPath" }

function U([string]$value) { return [regex]::Unescape($value) }

function Clean-Text([string]$value) {
  if (-not $value) { return '' }
  $decoded = [System.Net.WebUtility]::HtmlDecode($value)
  return (($decoded -replace '<script[\s\S]*?</script>', ' ' -replace '<style[\s\S]*?</style>', ' ' -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

function Get-MetaContent([string]$html, [string]$name) {
  if (-not $html) { return '' }
  $escaped = [regex]::Escape($name)
  $patterns = @(
    "<meta[^>]+(?:property|name)=['""]$escaped['""][^>]+content=['""]([^'""]+)['""][^>]*>",
    "<meta[^>]+content=['""]([^'""]+)['""][^>]+(?:property|name)=['""]$escaped['""][^>]*>"
  )
  foreach ($pattern in $patterns) {
    $match = [regex]::Match($html, $pattern, 'IgnoreCase')
    if ($match.Success) { return [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value.Trim()) }
  }
  return ''
}

function Get-Category([string]$text) {
  $rules = @(
    @{ name=(U '\uC7AC\uAC1C\uBC1C\u00B7\uC7AC\uAC74\uCD95'); pattern='\uC7AC\uAC1C\uBC1C|\uC7AC\uAC74\uCD95|\uC815\uBE44\uC0AC\uC5C5|\uBAA8\uC544\uD0C0\uC6B4|\uC2E0\uC18D\uD1B5\uD569\uAE30\uD68D|\uC2E0\uD1B5\uAE30\uD68D' },
    @{ name=(U '\uCCAD\uC57D\u00B7\uBD84\uC591'); pattern='\uCCAD\uC57D|\uBD84\uC591|\uC785\uC8FC\uC790\uBAA8\uC9D1|\uD2B9\uBCC4\uACF5\uAE09|\uACF5\uACF5\uBD84\uC591' },
    @{ name=(U '\uAD50\uD1B5\u00B7SOC'); pattern='GTX|\uCCA0\uB3C4|\uC9C0\uD558\uCCA0|\uB3C4\uC2DC\uCCA0\uB3C4|\uB178\uC120|\uB3C4\uB85C|\uAD50\uD1B5|SOC|\uC5F0\uC7A5|\uAE30\uBCF8\uACC4\uD68D' },
    @{ name=(U '\uC2E0\uB3C4\uC2DC\u00B7\uD0DD\uC9C0'); pattern='\uC2E0\uB3C4\uC2DC|\uD0DD\uC9C0|\uACF5\uACF5\uC8FC\uD0DD\uC9C0\uAD6C|\uB3C4\uC2DC\uAC1C\uBC1C' }
  )
  foreach ($rule in $rules) {
    if ($text -match (U $rule.pattern)) { return $rule.name }
  }
  return (U '\uC8FC\uD0DD\uACF5\uAE09')
}

function Get-Region([string]$text) {
  $regions = @(
    '\uC11C\uC6B8','\uC778\uCC9C','\uACBD\uAE30','\uAE40\uD3EC','\uAC80\uB2E8','\uC758\uC815\uBD80','\uACE0\uC591','\uBD80\uCC9C','\uD558\uB0A8','\uB0A8\uC591\uC8FC','\uC218\uC6D0','\uC6A9\uC778','\uC131\uB0A8','\uC548\uC591','\uB3D9\uC791\uAD6C','\uB178\uC6D0\uAD6C','\uAC15\uB0A8\uAD6C','\uC11C\uCD08\uAD6C','\uC1A1\uD30C\uAD6C'
  ) | ForEach-Object { U $_ }
  foreach ($region in $regions) {
    if ($text -match [regex]::Escape($region)) { return $region }
  }
  return (U '\uC804\uAD6D')
}

function Get-HostSource([string]$url) {
  try {
    $host = ([uri]$url).Host -replace '^www\.', ''
    if ($host -match 'yna\.co\.kr') { return (U '\uC5F0\uD569\uB274\uC2A4') }
    if ($host -match 'molit\.go\.kr') { return (U '\uAD6D\uD1A0\uAD50\uD1B5\uBD80') }
    if ($host -match 'gg\.go\.kr') { return (U '\uACBD\uAE30\uB3C4') }
    if ($host -match 'seoul\.go\.kr') { return (U '\uC11C\uC6B8\uC2DC') }
    if ($host -match 'lh\.or\.kr') { return 'LH' }
    return $host
  } catch {
    return 'manual link'
  }
}

function Get-ImageCandidates([string]$html, [string]$baseUrl) {
  $candidates = [System.Collections.ArrayList]::new()
  $ogImage = Get-MetaContent $html 'og:image'
  if ($ogImage) {
    [void]$candidates.Add([pscustomobject]@{ url=$ogImage; source='og:image'; alt=''; usage='needs_user_confirmation' })
  }
  foreach ($m in [regex]::Matches($html, '<img[^>]+>', 'IgnoreCase')) {
    $tag = $m.Value
    $srcMatch = [regex]::Match($tag, '(?:src|data-src)=[''"]([^''"]+)[''"]', 'IgnoreCase')
    if (-not $srcMatch.Success) { continue }
    $src = [System.Net.WebUtility]::HtmlDecode($srcMatch.Groups[1].Value.Trim())
    if (-not $src -or $src -match '^(data:|about:|#)') { continue }
    try { $absolute = ([System.Uri]::new([System.Uri]::new($baseUrl), $src)).AbsoluteUri } catch { $absolute = $src }
    $altMatch = [regex]::Match($tag, 'alt=[''"]([^''"]*)[''"]', 'IgnoreCase')
    $alt = if ($altMatch.Success) { [System.Net.WebUtility]::HtmlDecode($altMatch.Groups[1].Value.Trim()) } else { '' }
    $officialWords = U '\uC870\uAC10\uB3C4|\uC704\uCE58\uB3C4|\uAD6C\uC5ED\uB3C4|\uB178\uC120\uB3C4|\uBC30\uCE58\uB3C4|\uD22C\uC2DC\uB3C4|\uACC4\uD68D\uB3C4|\uC81C\uACF5|\uAD6D\uD1A0\uAD50\uD1B5\uBD80|\uC11C\uC6B8\uC2DC|\uACBD\uAE30\uB3C4|LH|SH|\uB3C4\uC2DC\uACF5\uC0AC'
    $usage = if ("$absolute $alt" -match $officialWords) { 'official_material_review_required' } else { 'do_not_use' }
    [void]$candidates.Add([pscustomobject]@{ url=$absolute; source='img'; alt=$alt; usage=$usage })
  }
  return @($candidates | Sort-Object url -Unique | Select-Object -First 12)
}

$request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$enabled = if ($null -ne $request.enabled) { [bool]$request.enabled } else { $true }
if (-not $enabled) {
  Write-Host 'link-request.json is disabled. Nothing to prepare.'
  exit 0
}

$date = if ($request.date) { [string]$request.date } else { (Get-Date -Format 'yyyy-MM-dd') }
$outDir = Join-Path $root (Join-Path 'output' $date)
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$articles = @()
if ($request.articles) {
  $articles = @($request.articles | Where-Object { $_.url })
} elseif ($request.urls) {
  $articles = @($request.urls | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ url=[string]$_ } })
} elseif ($request.url) {
  $articles = @([pscustomobject]@{ url=[string]$request.url })
}
if ($articles.Count -eq 0) { throw 'link-request.json must include url, urls, or articles.' }

$manualDetails = [System.Collections.ArrayList]::new()
$candidates = [System.Collections.ArrayList]::new()
$headers = @{ 'User-Agent' = 'Mozilla/5.0 (compatible; RealEstateDaily/1.0)' }

for ($i = 0; $i -lt $articles.Count; $i++) {
  $item = $articles[$i]
  $url = [string]$item.url

  $metaTitle = ''
  $metaDescription = ''
  $bodyExcerpt = ''
  $source = if ($item.source) { [string]$item.source } else { Get-HostSource $url }
  $resolvedUrl = $url
  $fetchStatus = 'not_attempted'
  $imageCandidates = @()

  if (-not $NoFetch) {
    try {
      $response = Invoke-WebRequest -Uri $url -MaximumRedirection 5 -TimeoutSec 25 -UseBasicParsing -Headers $headers
      $fetchStatus = "http_$($response.StatusCode)"
      if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) { $resolvedUrl = $response.BaseResponse.ResponseUri.AbsoluteUri }
      $html = [string]$response.Content
      $metaTitle = Get-MetaContent $html 'og:title'
      $metaDescription = Get-MetaContent $html 'og:description'
      if (-not $metaTitle) { $metaTitle = Get-MetaContent $html 'twitter:title' }
      if (-not $metaDescription) { $metaDescription = Get-MetaContent $html 'twitter:description' }
      $clean = Clean-Text $html
      if ($clean.Length -gt 900) { $clean = $clean.Substring(0, 900).Trim() + '...' }
      $bodyExcerpt = $clean
      $imageCandidates = @(Get-ImageCandidates $html $url)
    } catch {
      $fetchStatus = 'fetch_failed'
      $bodyExcerpt = "Fetch failed: $($_.Exception.Message)"
    }
  }

  $title = if ($item.title) { [string]$item.title } elseif ($metaTitle) { Clean-Text $metaTitle } else { $url }
  $summary = if ($item.summary) { [string]$item.summary } elseif ($metaDescription) { Clean-Text $metaDescription } elseif ($bodyExcerpt -and $bodyExcerpt -notmatch '^Fetch failed:') { $bodyExcerpt } else { 'Manual article link. Please verify source context before publishing.' }
  if ($title -match '\s+-\s+.+$') { $title = ($title -replace '\s+-\s+.+$', '').Trim() }
  $combined = "$title $summary"
  $category = if ($item.category) { [string]$item.category } else { Get-Category $combined }
  $region = if ($item.region) { [string]$item.region } else { Get-Region $combined }

  [void]$candidates.Add([pscustomobject]@{
    title = $title
    summary = $summary
    source = $source
    sourceUrl = ''
    url = $url
    published = ''
    score = 999
    publishedKst = ''
    publishedKstDate = $date
    category = $category
    region = $region
    clusterKey = "manual-link:$($i + 1):$url"
    manual = $true
  })

  [void]$manualDetails.Add([ordered]@{
    number = $i + 1
    collectedAt = (Get-Date -Format o)
    title = $title
    source = $source
    sourceUrl = ''
    manualOriginalUrl = $url
    googleNewsUrl = ''
    fetchedUrl = $url
    resolvedUrl = $resolvedUrl
    fetchStatus = $fetchStatus
    metaTitle = $metaTitle
    metaDescription = $metaDescription
    bodyExcerpt = $bodyExcerpt
    imageCandidates = $imageCandidates
    imagePolicy = 'Use only article-contained official renderings, maps, plans, district maps, layout maps, or route maps. If unclear, ask user before use.'
    contextWarnings = @('Manual link request. Verify article context, numbers, dates, project stage, and image usage before publishing.')
  })
}

$candidates | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outDir 'candidates.json') -Encoding UTF8

$originalUrls = [ordered]@{ note='Manual link request original URLs'; urls=[ordered]@{} }
for ($i = 0; $i -lt $articles.Count; $i++) {
  $originalUrls.urls[[string]($i + 1)] = [string]$articles[$i].url
}
$originalUrls | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'original-urls.json') -Encoding UTF8

foreach ($detail in $manualDetails) {
  $setDir = Join-Path $outDir ('article-{0:D2}-carousel' -f $detail.number)
  New-Item -ItemType Directory -Path $setDir -Force | Out-Null
  $detail | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $setDir 'article-detail.json') -Encoding UTF8
}

$numbers = (1..$articles.Count) -join ','
$articleMd = @("# $date confirmed manual link articles", '', "> Generated from link-request.json. Direct-publish numbers: $numbers", '')
for ($i = 0; $i -lt $candidates.Count; $i++) {
  $n = $i + 1
  $x = $candidates[$i]
  $articleMd += "## $n. $($x.title)"
  $articleMd += "- Category/region: $($x.category) / $($x.region)"
  $articleMd += "- Source: $($x.source)"
  $articleMd += "- URL: $($x.url)"
  $articleMd += ''
}
$articleMd -join "`r`n" | Set-Content -LiteralPath (Join-Path $outDir 'ARTICLES.md') -Encoding UTF8
$numbers | Set-Content -LiteralPath (Join-Path $outDir 'selection.txt') -Encoding UTF8

[ordered]@{
  runAt = (Get-Date -Format o)
  date = $date
  numbers = $numbers
  articles = $candidates.Count
  state = 'confirmed_manual_link_articles_created'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'link-request-status.json') -Encoding UTF8

Write-Host "Confirmed manual link articles prepared: date=$date numbers=$numbers"
