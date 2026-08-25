param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][string]$Numbers,
  [switch]$RequireJpeg
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root (Join-Path 'output' $Date)
if (-not (Test-Path -LiteralPath $outDir)) { throw "Output directory not found: $outDir" }

$indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
if ($indexes.Count -eq 0) { throw "No article numbers supplied." }

Add-Type -AssemblyName System.Drawing
$results = @()

foreach ($index in $indexes) {
  $setName = 'article-{0:D2}-carousel' -f $index
  $setDir = Join-Path $outDir $setName
  if (-not (Test-Path -LiteralPath $setDir)) { throw "Carousel directory not found: $setDir" }

  $pngs = @(Get-ChildItem -LiteralPath $setDir -Filter '*.png' | Sort-Object Name)
  if ($pngs.Count -lt 5 -or $pngs.Count -gt 8) {
    throw "$setName must have 5-8 PNG slides. Found: $($pngs.Count)"
  }

  foreach ($png in $pngs) {
    $img = [System.Drawing.Image]::FromFile($png.FullName)
    try {
      if ($img.Width -ne 1080 -or $img.Height -ne 1350) {
        throw "$setName/$($png.Name) must be 1080x1350. Found: $($img.Width)x$($img.Height)"
      }
    } finally {
      $img.Dispose()
    }
  }

  foreach ($required in @('REVIEW.md', 'caption.txt', 'article-detail.json')) {
    $path = Join-Path $setDir $required
    if (-not (Test-Path -LiteralPath $path)) { throw "$setName missing required file: $required" }
  }

  $captionPath = Join-Path $setDir 'caption.txt'
  $caption = Get-Content -LiteralPath $captionPath -Raw -Encoding UTF8
  $blockedCaptionPatterns = @(
    'https?://',
    'news\.google\.com',
    '원문 기준으로 다시 봐야 합니다',
    '단계, 일정, 수치가 확정인지 검토인지',
    '이미지는 기사 내 공식',
    'Use only',
    'fetch_failed',
    '원격 서버',
    '확인 전',
    '게시보류',
    '조감도 사용 조건'
  )
  foreach ($pattern in $blockedCaptionPatterns) {
    if ($caption -match $pattern) {
      throw "$setName caption contains blocked publish text or URL pattern: $pattern"
    }
  }

  $detail = Get-Content -LiteralPath (Join-Path $setDir 'article-detail.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $detail.title -or -not $detail.source) { throw "$setName article-detail.json missing title/source." }

  $jpegCount = 0
  $publishDir = Join-Path $setDir '_publish'
  if (Test-Path -LiteralPath $publishDir) {
    $jpgs = @(Get-ChildItem -LiteralPath $publishDir -Filter '*.jpg' | Sort-Object Name)
    $jpegCount = $jpgs.Count
    if ($RequireJpeg -and ($jpgs.Count -lt 2 -or $jpgs.Count -gt 10)) {
      throw "$setName must have 2-10 publish JPEG files. Found: $($jpgs.Count)"
    }
  } elseif ($RequireJpeg) {
    throw "$setName missing _publish JPEG directory."
  }

  $results += [pscustomobject]@{
    set = $setName
    slides = $pngs.Count
    size = '1080x1350'
    review = $true
    detail = $true
    publishJpegs = $jpegCount
  }
}

$report = [ordered]@{
  checkedAt = (Get-Date -Format o)
  date = $Date
  numbers = $indexes
  requireJpeg = [bool]$RequireJpeg
  state = 'valid'
  sets = $results
}

$reportPath = Join-Path $outDir 'validation-report.json'
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
$results | Format-Table -AutoSize
Write-Host "Validation passed: $reportPath"

