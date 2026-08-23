param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][string]$Numbers
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root (Join-Path 'output' $Date)
$candidatePath = Join-Path $outDir 'candidates.json'
if (-not (Test-Path -LiteralPath $candidatePath)) { throw "Candidates not found: $candidatePath" }

$loadedCandidates = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })
$manualOriginalUrls = @{}
$originalUrlPath = Join-Path $outDir 'original-urls.json'
if (Test-Path -LiteralPath $originalUrlPath) {
  $originalUrlConfig = Get-Content -LiteralPath $originalUrlPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($originalUrlConfig.urls) {
    foreach ($prop in $originalUrlConfig.urls.PSObject.Properties) {
      $manualOriginalUrls[$prop.Name] = [string]$prop.Value
    }
  }
}
$indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
if ($indexes.Count -eq 0) { throw "No article numbers supplied." }

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

function Get-ImageCandidates([string]$html, [string]$baseUrl) {
  $candidates = [System.Collections.ArrayList]::new()
  $ogImage = Get-MetaContent $html 'og:image'
  if ($ogImage) {
    $ogUsage = if ($ogImage -match 'googleusercontent\.com|gstatic\.com|google\.com') { 'do_not_use' } else { 'needs_user_confirmation' }
    [void]$candidates.Add([pscustomobject]@{ url=$ogImage; source='og:image'; alt=''; officialMaterialLikely=$false; usage=$ogUsage })
  }

  $imgMatches = [regex]::Matches($html, '<img[^>]+>', 'IgnoreCase')
  foreach ($m in $imgMatches) {
    $tag = $m.Value
    $srcMatch = [regex]::Match($tag, '(?:src|data-src)=[''"]([^''"]+)[''"]', 'IgnoreCase')
    if (-not $srcMatch.Success) { continue }
    $src = [System.Net.WebUtility]::HtmlDecode($srcMatch.Groups[1].Value.Trim())
    if (-not $src -or $src -match '^(data:|about:|#)') { continue }
    try {
      $absolute = ([System.Uri]::new([System.Uri]::new($baseUrl), $src)).AbsoluteUri
    } catch {
      $absolute = $src
    }
    $altMatch = [regex]::Match($tag, 'alt=[''"]([^''"]*)[''"]', 'IgnoreCase')
    $alt = if ($altMatch.Success) { [System.Net.WebUtility]::HtmlDecode($altMatch.Groups[1].Value.Trim()) } else { '' }
    $context = "$absolute $alt"
    $official = $context -match '조감도|위치도|구역도|노선도|배치도|투시도|계획도|제공|국토교통부|서울시|LH|SH|인천도시공사|도시공사'
    $usage = if ($absolute -match 'googleusercontent\.com|gstatic\.com|google\.com') { 'do_not_use' } elseif ($official) { 'candidate_official_material_confirm_before_use' } else { 'do_not_use' }
    [void]$candidates.Add([pscustomobject]@{ url=$absolute; source='img'; alt=$alt; officialMaterialLikely=$official; usage=$usage })
  }

  return @($candidates | Sort-Object url -Unique | Select-Object -First 12)
}

foreach ($index in $indexes) {
  if ($index -lt 1 -or $index -gt $candidates.Count) { throw "Invalid article number: $index" }
  $article = $candidates[$index - 1]
  $manualOriginalUrl = if ($manualOriginalUrls.ContainsKey([string]$index)) { [string]$manualOriginalUrls[[string]$index] } else { '' }
  $fetchUrl = if ($manualOriginalUrl) { $manualOriginalUrl } else { [string]$article.url }
  $setDir = Join-Path $outDir ('article-{0:D2}-carousel' -f $index)
  New-Item -ItemType Directory -Path $setDir -Force | Out-Null

  $detail = [ordered]@{
    number = $index
    collectedAt = (Get-Date -Format o)
    title = [string]$article.title
    source = [string]$article.source
    sourceUrl = [string]$article.sourceUrl
    manualOriginalUrl = $manualOriginalUrl
    googleNewsUrl = [string]$article.url
    fetchedUrl = $fetchUrl
    resolvedUrl = ''
    fetchStatus = 'not_attempted'
    metaTitle = ''
    metaDescription = ''
    bodyExcerpt = ''
    imageCandidates = @()
    imagePolicy = 'Use only article-contained renderings, location maps, district maps, layout maps, or route maps that appear to be official-source materials. If unclear, ask user before use.'
    contextWarnings = @()
  }

  try {
    $headers = @{ 'User-Agent' = 'Mozilla/5.0 (compatible; RealEstateDaily/1.0)' }
    $response = Invoke-WebRequest -Uri $fetchUrl -MaximumRedirection 5 -TimeoutSec 20 -UseBasicParsing -Headers $headers
    $detail.fetchStatus = "http_$($response.StatusCode)"
    if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
      $detail.resolvedUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
    }
    $html = [string]$response.Content
    $detail.metaTitle = Get-MetaContent $html 'og:title'
    $detail.metaDescription = Get-MetaContent $html 'og:description'
    $clean = Clean-Text $html
    if ($clean.Length -gt 900) { $clean = $clean.Substring(0, 900).Trim() + '…' }
    $detail.bodyExcerpt = $clean
    $detail.imageCandidates = @(Get-ImageCandidates $html $fetchUrl)

    if (-not $manualOriginalUrl -and $detail.resolvedUrl -match 'news\.google\.com') {
      $detail.contextWarnings += 'Google News intermediary page only. Original article body was not available from this URL.'
    }
    if ($manualOriginalUrl) {
      $detail.contextWarnings += 'Manual original URL was used for article extraction. Verify it matches the selected article.'
    }
    if (-not $detail.metaDescription -and -not $detail.bodyExcerpt) {
      $detail.contextWarnings += 'No reliable article text extracted. Use RSS title/summary only and verify manually.'
    }
    if (@($detail.imageCandidates | Where-Object { $_.officialMaterialLikely }).Count -eq 0) {
      $detail.contextWarnings += 'No clearly official rendering/map/plan image candidate detected. Do not use images automatically.'
    }
  } catch {
    $detail.fetchStatus = 'fetch_failed'
    $detail.contextWarnings += "Fetch failed: $($_.Exception.Message)"
    $detail.contextWarnings += 'Use RSS title/summary only and verify manually.'
  }

  $detail | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $setDir 'article-detail.json') -Encoding UTF8
  Write-Host "Detail written: article-$('{0:D2}' -f $index)-carousel/article-detail.json"
}





