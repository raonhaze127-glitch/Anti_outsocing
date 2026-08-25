param(
  [string]$Date = '',
  [string]$Numbers = '',
  [switch]$RequireMetaEnv
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $root

function New-Check([string]$Name, [bool]$Passed, [string]$Detail, [string]$Severity = 'error') {
  [pscustomobject]@{
    name = $Name
    passed = $Passed
    severity = $Severity
    detail = $Detail
  }
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

  return ''
}

$checks = [System.Collections.ArrayList]::new()

$requiredScripts = @(
  'run-daily.ps1',
  'build-selected.ps1',
  'enrich-selected.ps1',
  'publish-instagram-carousel.ps1',
  'verify-public-image-urls.ps1',
  'validate-news-output.ps1',
  'validate-carousel-output.ps1',
  'run-smoke-test.ps1',
  'prepare-github-commit.ps1',
  'check-automation-readiness.ps1'
)

foreach ($script in $requiredScripts) {
  $path = Join-Path $root $script
  [void]$checks.Add((New-Check "script:$script" (Test-Path -LiteralPath $path) $path))
}

$requiredWorkflows = @(
  '.github/workflows/daily-realestate-news.yml',
  '.github/workflows/build-selected-carousels.yml',
  '.github/workflows/publish-selected-instagram.yml'
)

foreach ($workflow in $requiredWorkflows) {
  $path = Join-Path $repoRoot ($workflow -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  [void]$checks.Add((New-Check "workflow:$workflow" (Test-Path -LiteralPath $path) $path))
}

$requiredDocs = @(
  'README.md',
  'WORKFLOW.md',
  'GITHUB_SETUP.md',
  'CAROUSEL_STYLE_REFERENCE.md',
  'PROJECT_STATUS.md',
  'LAUNCH_CHECKLIST.md'
)

foreach ($doc in $requiredDocs) {
  $path = Join-Path $root $doc
  [void]$checks.Add((New-Check "doc:$doc" (Test-Path -LiteralPath $path) $path 'warning'))
}

$gitignorePath = Join-Path $repoRoot '.gitignore'
$gitignoreOk = $false
if (Test-Path -LiteralPath $gitignorePath) {
  $gitignore = Get-Content -LiteralPath $gitignorePath -Raw
  $gitignoreOk = $gitignore -match 'daily-realestate/output/\*\*/\*\.png' -and $gitignore -match 'daily-realestate/output/\*\*/_publish/'
}
[void]$checks.Add((New-Check 'gitignore:large-artifacts' $gitignoreOk 'PNG/JPEG/HTML output files should be ignored.'))

$browserPath = Find-BrowserExecutable
[void]$checks.Add((New-Check 'local-browser' (-not [string]::IsNullOrWhiteSpace($browserPath)) $browserPath 'warning'))

$remote = ''
try {
  $remote = (git -C $repoRoot remote get-url origin 2>$null)
} catch {
  $remote = ''
}
[void]$checks.Add((New-Check 'git-remote-origin' (-not [string]::IsNullOrWhiteSpace($remote)) $remote 'warning'))

$metaUser = [string]$env:META_IG_USER_ID
$metaToken = [string]$env:META_IG_ACCESS_TOKEN
$metaOk = -not [string]::IsNullOrWhiteSpace($metaUser) -and -not [string]::IsNullOrWhiteSpace($metaToken)
$metaSeverity = if ($RequireMetaEnv) { 'error' } else { 'warning' }
[void]$checks.Add((New-Check 'meta-env-vars' $metaOk 'META_IG_USER_ID and META_IG_ACCESS_TOKEN are needed for real publishing.' $metaSeverity))

if ($Date) {
  $outDir = Join-Path $root (Join-Path 'output' $Date)
  [void]$checks.Add((New-Check "output:$Date" (Test-Path -LiteralPath $outDir) $outDir))

  if (Test-Path -LiteralPath $outDir) {
    $collectionReport = Join-Path $outDir 'collection-validation-report.json'
    [void]$checks.Add((New-Check 'collection-validation-report' (Test-Path -LiteralPath $collectionReport) $collectionReport 'warning'))

    if ($Numbers) {
      $carouselReport = Join-Path $outDir 'validation-report.json'
      [void]$checks.Add((New-Check 'carousel-validation-report' (Test-Path -LiteralPath $carouselReport) $carouselReport 'warning'))

      $indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
      foreach ($index in $indexes) {
        $setName = 'article-{0:D2}-carousel' -f $index
        $setDir = Join-Path $outDir $setName
        $hasSet = Test-Path -LiteralPath $setDir
        [void]$checks.Add((New-Check "carousel:$setName" $hasSet $setDir))
        if ($hasSet) {
          foreach ($file in @('REVIEW.md', 'caption.txt', 'article-detail.json', 'publish-manifest.json')) {
            $filePath = Join-Path $setDir $file
            [void]$checks.Add((New-Check "$setName/$file" (Test-Path -LiteralPath $filePath) $filePath 'warning'))
          }
        }
      }
    }
  }
}

$failedErrors = @($checks | Where-Object { -not $_.passed -and $_.severity -eq 'error' })
$failedWarnings = @($checks | Where-Object { -not $_.passed -and $_.severity -eq 'warning' })
$state = if ($failedErrors.Count -gt 0) { 'not_ready' } elseif ($failedWarnings.Count -gt 0) { 'ready_with_warnings' } else { 'ready' }

$report = [ordered]@{
  checkedAt = (Get-Date -Format o)
  state = $state
  date = $Date
  numbers = $Numbers
  checks = $checks
}

$reportPath = Join-Path $root 'readiness-report.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$checks | Sort-Object passed, severity, name | Format-Table name, passed, severity, detail -AutoSize
Write-Host "Readiness state: $state"
Write-Host "Readiness report: $reportPath"

if ($failedErrors.Count -gt 0) {
  exit 2
}


