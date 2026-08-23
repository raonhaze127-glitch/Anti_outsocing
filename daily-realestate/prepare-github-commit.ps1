param(
  [string]$Message = 'Add real-estate news automation',
  [string]$UserName = 'Codex Automation',
  [string]$UserEmail = 'codex-automation@users.noreply.github.com',
  [switch]$Commit,
  [switch]$Push,
  [switch]$IncludeSampleOutput
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $root

function Invoke-Git([string[]]$Arguments) {
  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git command failed: git $($Arguments -join ' ')"
  }
}

function Add-IfExists([string[]]$Paths) {
  foreach ($path in $Paths) {
    $fullPath = Join-Path $repoRoot $path
    if (Test-Path -LiteralPath $fullPath) {
      Invoke-Git @('-C', $repoRoot, 'add', '--', $path)
    }
  }
}

function Ensure-LocalGitIdentity {
  $name = ''
  $email = ''
  try { $name = (& git -C $repoRoot config user.name) } catch { $name = '' }
  try { $email = (& git -C $repoRoot config user.email) } catch { $email = '' }

  if ([string]::IsNullOrWhiteSpace($name)) {
    Invoke-Git @('-C', $repoRoot, 'config', 'user.name', $UserName)
  }
  if ([string]::IsNullOrWhiteSpace($email)) {
    Invoke-Git @('-C', $repoRoot, 'config', 'user.email', $UserEmail)
  }
}

$sourceFiles = @(
  '.gitignore',
  '.github/workflows/daily-realestate-news.yml',
  '.github/workflows/build-selected-carousels.yml',
  '.github/workflows/publish-selected-instagram.yml',
  'daily-realestate/config.json',
  'daily-realestate/run-daily.ps1',
  'daily-realestate/build-selected.ps1',
  'daily-realestate/enrich-selected.ps1',
  'daily-realestate/publish-instagram-carousel.ps1',
  'daily-realestate/verify-public-image-urls.ps1',
  'daily-realestate/validate-news-output.ps1',
  'daily-realestate/validate-carousel-output.ps1',
  'daily-realestate/check-automation-readiness.ps1',
  'daily-realestate/run-smoke-test.ps1',
  'daily-realestate/prepare-github-commit.ps1',
  'daily-realestate/install-schedule.ps1',
  'daily-realestate/README.md',
  'daily-realestate/WORKFLOW.md',
  'daily-realestate/GITHUB_SETUP.md',
  'daily-realestate/PROJECT_STATUS.md',
  'daily-realestate/LAUNCH_CHECKLIST.md'
)

if ($IncludeSampleOutput) {
  $sampleFiles = @(
    'daily-realestate/output/2026-08-23/ARTICLES.md',
    'daily-realestate/output/2026-08-23/articles.txt',
    'daily-realestate/output/2026-08-23/candidates.json',
    'daily-realestate/output/2026-08-23/selection.txt',
    'daily-realestate/output/2026-08-23/original-urls.json',
    'daily-realestate/output/2026-08-23/status.json',
    'daily-realestate/output/2026-08-23/collection-validation-report.json',
    'daily-realestate/output/2026-08-23/validation-report.json',
    'daily-realestate/output/2026-08-23/smoke-test-report.json'
  )
}

$plannedFiles = [System.Collections.ArrayList]::new()
foreach ($path in $sourceFiles) {
  $fullPath = Join-Path $repoRoot $path
  if (Test-Path -LiteralPath $fullPath) { [void]$plannedFiles.Add($path) }
}
if ($IncludeSampleOutput) {
  foreach ($path in $sampleFiles) {
    $fullPath = Join-Path $repoRoot $path
    if (Test-Path -LiteralPath $fullPath) { [void]$plannedFiles.Add($path) }
  }
}

if (-not $Commit) {
  Write-Host 'Planned automation files for commit:'
  $plannedFiles | ForEach-Object { Write-Host "  $_" }
  Write-Host ''
  Write-Host 'Dry run only. Git index was not modified.'
  Write-Host 'Re-run with -Commit to stage these files and create a local commit.'
  Write-Host 'Use -Push only after you confirm the planned file list.'
  exit 0
}

Add-IfExists ([string[]]$plannedFiles)

Write-Host 'Staged files:'
Invoke-Git @('-C', $repoRoot, 'diff', '--cached', '--name-status')

$staged = & git -C $repoRoot diff --cached --name-only
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged files.' }
if (-not $staged) {
  Write-Host 'No staged automation changes to commit.'
  exit 0
}

Ensure-LocalGitIdentity
Invoke-Git @('-C', $repoRoot, 'commit', '-m', $Message)

if ($Push) {
  Invoke-Git @('-C', $repoRoot, 'push')
} else {
  Write-Host ''
  Write-Host 'Committed locally. Re-run with -Push, or run git push manually, when ready.'
}
