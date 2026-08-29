param(
  [string]$QueuePath = '',
  [string]$CandidatesRoot = '',
  [datetimeoffset]$Now = [datetimeoffset]::UtcNow
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $QueuePath) { $QueuePath = Join-Path $root 'scheduled-publish-queue.json' }
if (-not $CandidatesRoot) { $CandidatesRoot = Join-Path $root 'output' }

function Write-ActionOutput([string]$Name, [string]$Value) {
  if ($env:GITHUB_OUTPUT) {
    "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
  }
  Write-Host "$Name=$Value"
}

if (-not (Test-Path -LiteralPath $QueuePath)) { throw "Schedule queue not found: $QueuePath" }
$queue = Get-Content -LiteralPath $QueuePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $queue.jobs) { $queue | Add-Member -NotePropertyName jobs -NotePropertyValue @() -Force }

$dueJobs = @($queue.jobs | Where-Object {
  $_.enabled -eq $true -and [string]$_.status -eq 'pending' -and $_.publish_at -and ([datetimeoffset]::Parse([string]$_.publish_at) -le $Now)
} | Sort-Object { [datetimeoffset]::Parse([string]$_.publish_at) })

if ($dueJobs.Count -eq 0) {
  Write-ActionOutput 'dispatched' 'false'
  Write-ActionOutput 'reason' 'no_due_jobs'
  exit 0
}

$job = $dueJobs[0]
foreach ($required in @('id','date','number','title','source','publish_at')) {
  if (-not $job.$required) { throw "Scheduled job is missing '$required': $($job.id)" }
}

$number = [int]$job.number
$candidatePath = Join-Path $CandidatesRoot (Join-Path ([string]$job.date) 'candidates.json')
if (-not (Test-Path -LiteralPath $candidatePath)) { throw "Candidates not found: $candidatePath" }
$loadedCandidates = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })
if ($number -lt 1 -or $number -gt $candidates.Count) { throw "Invalid article number $number for $($job.date)" }

$normalize = { param([string]$Value) (($Value -replace '\s+', ' ').Trim()) }
$actual = $candidates[$number - 1]
$actualTitle = & $normalize ([string]$actual.title)
$actualSource = & $normalize ([string]$actual.source)
$expectedTitle = & $normalize ([string]$job.title)
$expectedSource = & $normalize ([string]$job.source)
if ($actualTitle -ne $expectedTitle -or $actualSource -ne $expectedSource) {
  throw "Scheduled mapping mismatch for $number. Expected '$expectedTitle' / '$expectedSource'; actual '$actualTitle' / '$actualSource'."
}

$job.status = 'dispatched'
$job.enabled = $false
if ($job.PSObject.Properties.Name -contains 'dispatched_at') {
  $job.dispatched_at = $Now.ToString('o')
} else {
  $job | Add-Member -NotePropertyName dispatched_at -NotePropertyValue $Now.ToString('o')
}
$queue | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $QueuePath -Encoding UTF8

Write-ActionOutput 'dispatched' 'true'
Write-ActionOutput 'job_id' ([string]$job.id)
Write-ActionOutput 'date' ([string]$job.date)
Write-ActionOutput 'number' ([string]$number)
Write-ActionOutput 'title' $expectedTitle
Write-ActionOutput 'source' $expectedSource
