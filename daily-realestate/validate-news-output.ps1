param(
  [Parameter(Mandatory=$true)][string]$Date,
  [int]$MinCandidates = 5,
  [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$outDir = Join-Path $root (Join-Path 'output' $Date)
if (-not (Test-Path -LiteralPath $outDir)) { throw "Output directory not found: $outDir" }

$requiredFiles = @('ARTICLES.md', 'articles.txt', 'candidates.json', 'selection.txt', 'original-urls.json', 'status.json')
$missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $outDir $_)) })
if ($missingFiles.Count -gt 0) { throw "Missing collection files: $($missingFiles -join ', ')" }

$loadedCandidates = Get-Content -LiteralPath (Join-Path $outDir 'candidates.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })
if ($candidates.Count -lt $MinCandidates) {
  throw "Too few news candidates. Found $($candidates.Count), expected at least $MinCandidates."
}

$blockedSources = @($config.blockedSources | ForEach-Object { [string]$_ })
$excludeKeywords = @($config.excludeKeywords | ForEach-Object { [string]$_ })

$blockedHits = @()
$keywordHits = @()
$missingSourceUrl = @()

for ($i = 0; $i -lt $candidates.Count; $i++) {
  $candidate = $candidates[$i]
  $number = $i + 1
  $source = [string]$candidate.source
  $text = "$($candidate.title) $($candidate.summary) $($candidate.source)"

  foreach ($blocked in $blockedSources) {
    if ($blocked -and $source -match [regex]::Escape($blocked)) {
      $blockedHits += [pscustomobject]@{ number=$number; title=$candidate.title; source=$source; blockedSource=$blocked }
    }
  }

  foreach ($keyword in $excludeKeywords) {
    if ($keyword -and $text -match [regex]::Escape($keyword)) {
      $keywordHits += [pscustomobject]@{ number=$number; title=$candidate.title; source=$source; keyword=$keyword }
    }
  }

  if (-not $candidate.sourceUrl) {
    $missingSourceUrl += [pscustomobject]@{ number=$number; title=$candidate.title; source=$source }
  }
}

if ($blockedHits.Count -gt 0) {
  throw "Blocked sources found in candidates: $($blockedHits.Count)"
}

if ($Strict -and $keywordHits.Count -gt 0) {
  throw "Excluded keywords found in candidates: $($keywordHits.Count)"
}

$articleMd = Get-Content -LiteralPath (Join-Path $outDir 'ARTICLES.md') -Raw -Encoding UTF8
if ($articleMd -notmatch '##\s+1\.') { throw "ARTICLES.md does not contain numbered candidates." }

$state = if ($keywordHits.Count -gt 0 -or $missingSourceUrl.Count -gt 0) { 'valid_with_warnings' } else { 'valid' }
$report = [ordered]@{
  checkedAt = (Get-Date -Format o)
  date = $Date
  state = $state
  candidates = $candidates.Count
  minCandidates = $MinCandidates
  blockedSourceHits = $blockedHits
  excludedKeywordHits = $keywordHits
  missingSourceUrl = $missingSourceUrl
  strict = [bool]$Strict
}

$reportPath = Join-Path $outDir 'collection-validation-report.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

[pscustomobject]@{
  Date = $Date
  State = $state
  Candidates = $candidates.Count
  BlockedSourceHits = $blockedHits.Count
  ExcludedKeywordHits = $keywordHits.Count
  MissingSourceUrl = $missingSourceUrl.Count
} | Format-Table -AutoSize
Write-Host "Collection validation report: $reportPath"


