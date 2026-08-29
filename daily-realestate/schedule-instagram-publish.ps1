param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][int]$Number,
  [Parameter(Mandatory=$true)][string]$PublishAt,
  [string]$Id = '',
  [string]$QueuePath = '',
  [string]$CandidatesRoot = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $QueuePath) { $QueuePath = Join-Path $root 'scheduled-publish-queue.json' }
if (-not $CandidatesRoot) { $CandidatesRoot = Join-Path $root 'output' }
$candidatePath = Join-Path $CandidatesRoot (Join-Path $Date 'candidates.json')
if (-not (Test-Path -LiteralPath $queuePath)) { throw "Schedule queue not found: $queuePath" }
if (-not (Test-Path -LiteralPath $candidatePath)) { throw "Candidates not found: $candidatePath" }

$publishTime = [datetimeoffset]::Parse($PublishAt)
if ($publishTime.Offset -eq [timespan]::Zero -and $PublishAt -notmatch '(Z|[+-]\d{2}:\d{2})$') {
  throw 'PublishAt must include an explicit timezone offset, for example 2026-08-29T19:10:00+09:00.'
}

$loadedCandidates = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })
if ($Number -lt 1 -or $Number -gt $candidates.Count) { throw "Invalid article number: $Number" }
$article = $candidates[$Number - 1]

$queue = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $queue.jobs) { $queue | Add-Member -NotePropertyName jobs -NotePropertyValue @() -Force }
if (-not $Id) { $Id = "$Date-article-$Number-$($publishTime.ToString('yyyyMMddHHmm'))" }
if (@($queue.jobs | Where-Object { [string]$_.id -eq $Id }).Count -gt 0) { throw "Duplicate schedule id: $Id" }
if (@($queue.jobs | Where-Object { $_.enabled -eq $true -and [string]$_.status -eq 'pending' -and [string]$_.date -eq $Date -and [int]$_.number -eq $Number }).Count -gt 0) {
  throw "A pending schedule already exists for $Date article $Number."
}

$job = [pscustomobject][ordered]@{
  id = $Id
  enabled = $true
  status = 'pending'
  publish_at = $publishTime.ToString('o')
  date = $Date
  number = $Number
  title = [string]$article.title
  source = [string]$article.source
  created_at = [datetimeoffset]::Now.ToString('o')
}
$queue.jobs = @($queue.jobs) + @($job)
$queue | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $queuePath -Encoding UTF8
Write-Host "Scheduled: $Id"
Write-Host "Publish at: $($publishTime.ToString('o'))"
Write-Host "Article: $Number. $($article.title) | $($article.source)"
