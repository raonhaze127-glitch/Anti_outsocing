param(
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
  [string]$Numbers = '1',
  [switch]$SkipCollect,
  [switch]$NoRender,
  [switch]$RequireMetaEnv
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root (Join-Path 'output' $Date)

function Invoke-Step([string]$Name, [scriptblock]$Block) {
  Write-Host "== $Name =="
  & $Block
}

if (-not $SkipCollect) {
  Invoke-Step 'Collect news candidates' {
    & (Join-Path $root 'run-daily.ps1') -Date $Date
  }
}

Invoke-Step 'Validate news candidates' {
  & (Join-Path $root 'validate-news-output.ps1') -Date $Date -MinCandidates 5
}

Invoke-Step 'Build selected article carousels' {
  if ($NoRender) {
    & (Join-Path $root 'build-selected.ps1') -Date $Date -Numbers $Numbers -NoRender
  } else {
    & (Join-Path $root 'build-selected.ps1') -Date $Date -Numbers $Numbers
  }
}

if (-not $NoRender) {
  Invoke-Step 'Prepare publish JPEG files' {
    $indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
    foreach ($index in $indexes) {
      $setName = 'article-{0:D2}-carousel' -f $index
      $carouselDir = Join-Path $outDir $setName
      $imageBaseUrl = "https://example.com/smoke/$Date/$setName"
      & (Join-Path $root 'publish-instagram-carousel.ps1') -CarouselDir $carouselDir -ImageBaseUrl $imageBaseUrl -PrepareJpeg -DryRun
    }
  }
}

Invoke-Step 'Validate carousel output' {
  if ($NoRender) {
    & (Join-Path $root 'validate-carousel-output.ps1') -Date $Date -Numbers $Numbers
  } else {
    & (Join-Path $root 'validate-carousel-output.ps1') -Date $Date -Numbers $Numbers -RequireJpeg
  }
}

Invoke-Step 'Check automation readiness' {
  if ($RequireMetaEnv) {
    & (Join-Path $root 'check-automation-readiness.ps1') -Date $Date -Numbers $Numbers -RequireMetaEnv
  } else {
    & (Join-Path $root 'check-automation-readiness.ps1') -Date $Date -Numbers $Numbers
  }
}

$report = [ordered]@{
  checkedAt = (Get-Date -Format o)
  date = $Date
  numbers = $Numbers
  skipCollect = [bool]$SkipCollect
  noRender = [bool]$NoRender
  state = 'passed'
}
$reportPath = Join-Path $outDir 'smoke-test-report.json'
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "Smoke test passed: $reportPath"

