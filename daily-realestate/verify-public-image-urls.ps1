param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][string]$Numbers,
  [int]$Attempts = 6,
  [int]$DelaySeconds = 5
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root (Join-Path 'output' $Date)

if (-not (Test-Path -LiteralPath $outDir)) {
  throw "Output directory not found: $outDir"
}

function Test-PublicImageUrl([string]$Url) {
  try {
    $response = Invoke-WebRequest -Method Head -Uri $Url -TimeoutSec 20 -UseBasicParsing
  } catch {
    try {
      $response = Invoke-WebRequest -Method Get -Uri $Url -TimeoutSec 20 -UseBasicParsing
    } catch {
      return [pscustomobject]@{
        url = $Url
        ok = $false
        statusCode = $null
        contentType = ''
        error = $_.Exception.Message
      }
    }
  }

  $contentType = ''
  if ($response.Headers.'Content-Type') { $contentType = [string]$response.Headers.'Content-Type' }
  $statusCode = [int]$response.StatusCode
  $isImage = $contentType -match '^image/' -or $Url -match '\.(jpg|jpeg|png)(\?|$)'

  return [pscustomobject]@{
    url = $Url
    ok = ($statusCode -ge 200 -and $statusCode -lt 300 -and $isImage)
    statusCode = $statusCode
    contentType = $contentType
    error = ''
  }
}

$indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
if ($indexes.Count -eq 0) { throw "No article numbers provided." }

$allResults = @()
foreach ($index in $indexes) {
  $setName = 'article-{0:D2}-carousel' -f $index
  $setDir = Join-Path $outDir $setName
  $manifestPath = Join-Path $setDir 'publish-manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "publish-manifest.json not found: $manifestPath"
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $urls = @($manifest.imageUrls)
  if ($urls.Count -lt 2 -or $urls.Count -gt 10) {
    throw "Manifest must contain 2-10 image URLs: $manifestPath"
  }

  foreach ($url in $urls) {
    $final = $null
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
      $result = Test-PublicImageUrl $url
      $result | Add-Member -NotePropertyName set -NotePropertyValue $setName -Force
      $result | Add-Member -NotePropertyName attempt -NotePropertyValue $attempt -Force
      $final = $result
      if ($result.ok) { break }
      if ($attempt -lt $Attempts) { Start-Sleep -Seconds $DelaySeconds }
    }
    $allResults += $final
  }
}

$failed = @($allResults | Where-Object { -not $_.ok })
$report = [ordered]@{
  checkedAt = (Get-Date -Format o)
  date = $Date
  numbers = $indexes
  attempts = $Attempts
  delaySeconds = $DelaySeconds
  state = if ($failed.Count -gt 0) { 'invalid' } else { 'valid' }
  results = $allResults
}

$reportPath = Join-Path $outDir 'public-image-url-report.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$allResults | Select-Object set, ok, statusCode, contentType, url | Format-Table -AutoSize
Write-Host "Public image URL report: $reportPath"

if ($failed.Count -gt 0) {
  throw "Some public image URLs are not reachable or not image responses. Failed: $($failed.Count)"
}
