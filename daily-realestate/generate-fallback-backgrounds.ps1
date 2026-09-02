param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][string]$Numbers,
  [string]$Model = $(if ($env:OPENAI_IMAGE_MODEL) { $env:OPENAI_IMAGE_MODEL } else { 'gpt-image-2' }),
  [string]$ApiBaseUrl = $(if ($env:OPENAI_API_BASE_URL) { $env:OPENAI_API_BASE_URL.TrimEnd('/') } else { 'https://api.openai.com/v1' }),
  [switch]$Force,
  [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root (Join-Path 'output' $Date)
$candidatePath = Join-Path $outDir 'candidates.json'
if (-not (Test-Path -LiteralPath $candidatePath)) { throw "Candidates not found: $candidatePath" }

$loadedCandidates = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$candidates = @($loadedCandidates | ForEach-Object { $_ })
$indexes = @($Numbers -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
if ($indexes.Count -eq 0) { throw 'No article numbers supplied.' }

$assetDir = Join-Path $root (Join-Path 'assets\article-backgrounds' $Date)
$outputBgDir = Join-Path $outDir 'article-backgrounds'
$reportPath = Join-Path $outDir 'image-generation-report.json'
$apiKey = [string]$env:OPENAI_API_KEY
$results = [System.Collections.ArrayList]::new()

function Find-ExistingBackground([string]$ArticleNumber) {
  foreach ($dir in @($outputBgDir, $assetDir)) {
    foreach ($ext in @('jpg','jpeg','png','webp')) {
      $path = Join-Path $dir ("article-$ArticleNumber-bg.$ext")
      if (Test-Path -LiteralPath $path) { return $path }
    }
  }
  return ''
}

function Get-VisualDirection($Article) {
  $category = [string]$Article.category
  $text = "$($Article.title) $($Article.summary)"
  if ($category -eq '교통·SOC' -or $text -match 'GTX|철도|지하철|노선|도로|교통|SOC') {
    return 'A clean aerial urban transportation infrastructure scene with rail lines, station architecture, roads, and surrounding apartment districts.'
  }
  if ($category -eq '재개발·재건축' -or $text -match '재개발|재건축|정비사업|모아타운|신속통합기획') {
    return 'A realistic contemporary Korean apartment redevelopment district seen from an elevated architectural perspective, with construction and completed residential towers.'
  }
  if ($category -eq '청약·분양' -or $text -match '청약|분양|입주자모집|특별공급') {
    return 'A realistic modern Korean apartment complex exterior and landscaped residential neighborhood, photographed from an elevated wide angle.'
  }
  if ($category -eq '신도시·택지' -or $text -match '신도시|택지|공공주택지구|도시개발') {
    return 'A realistic aerial view of a newly planned Korean residential district with apartment blocks, parks, roads, and public facilities.'
  }
  return 'A realistic Korean city housing landscape with modern apartment districts, construction cranes, public housing, and an urban skyline.'
}

function New-BackgroundPrompt($Article) {
  $direction = Get-VisualDirection $Article
  $topic = (([string]$Article.title -replace '\s+', ' ').Trim())
  if ($topic.Length -gt 160) { $topic = $topic.Substring(0,160) }
  return @"
Create a premium editorial background image for a Korean real-estate news Instagram carousel.
Article topic for visual context only: $topic
Visual direction: $direction
Portrait composition, 2:3 aspect ratio. Keep the center-left area calm and uncluttered for a dark overlay and Korean headline. Deep navy and cool blue atmosphere with restrained warm highlights, realistic photography or architectural visualization, credible Korean urban context.
Do not depict a specific unverified building design as factual. Do not include any people, faces, readable text, letters, numbers, logos, watermarks, signs, posters, documents, charts, captions, UI, or borders. Image only.
"@.Trim()
}

function Save-Report {
  $report = [ordered]@{
    generatedAt = (Get-Date -Format o)
    date = $Date
    model = $Model
    size = '1024x1536'
    quality = 'low'
    results = @($results)
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}

foreach ($index in $indexes) {
  if ($index -lt 1 -or $index -gt $candidates.Count) { throw "Invalid article number: $index" }
  $article = $candidates[$index - 1]
  $articleNumber = '{0:D2}' -f $index
  $existing = Find-ExistingBackground $articleNumber
  if ($existing -and -not $Force) {
    [void]$results.Add([ordered]@{ number=$index; status='skipped_existing'; path=$existing; title=[string]$article.title })
    Write-Host "Fallback image skipped: article $index already has a background."
    continue
  }

  if (-not $apiKey) {
    $message = 'OPENAI_API_KEY is not configured; continuing with the standard navy background.'
    [void]$results.Add([ordered]@{ number=$index; status='skipped_missing_api_key'; message=$message; title=[string]$article.title })
    Write-Warning "Article ${index}: $message"
    if ($Strict) { Save-Report; throw $message }
    continue
  }

  $prompt = New-BackgroundPrompt $article
  $destination = Join-Path $assetDir ("article-$articleNumber-bg.png")
  try {
    New-Item -ItemType Directory -Path $assetDir -Force | Out-Null
    $headers = @{ Authorization = "Bearer $apiKey"; 'Content-Type' = 'application/json' }
    $body = [ordered]@{
      model = $Model
      prompt = $prompt
      n = 1
      size = '1024x1536'
      quality = 'low'
      output_format = 'png'
    } | ConvertTo-Json -Depth 5
    $response = Invoke-RestMethod -Method Post -Uri "$ApiBaseUrl/images/generations" -Headers $headers -Body $body -TimeoutSec 300
    $encoded = [string]$response.data[0].b64_json
    if (-not $encoded) { throw 'Image API response did not contain data[0].b64_json.' }
    [IO.File]::WriteAllBytes($destination, [Convert]::FromBase64String($encoded))
    [void]$results.Add([ordered]@{ number=$index; status='generated'; path=$destination; model=$Model; prompt=$prompt; title=[string]$article.title })
    Write-Host "Fallback image generated: $destination"
  } catch {
    $message = $_.Exception.Message
    [void]$results.Add([ordered]@{ number=$index; status='failed'; message=$message; model=$Model; title=[string]$article.title })
    Write-Warning "Fallback image generation failed for article $index. Standard navy background will be used. $message"
    if ($Strict) { Save-Report; throw }
  }
}

Save-Report
