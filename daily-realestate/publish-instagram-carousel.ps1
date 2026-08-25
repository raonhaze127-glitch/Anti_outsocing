param(
  [Parameter(Mandatory=$true)][string]$CarouselDir,
  [Parameter(Mandatory=$true)][string]$ImageBaseUrl,
  [string]$CaptionPath = '',
  [string]$GraphVersion = $(if ($env:META_GRAPH_VERSION) { $env:META_GRAPH_VERSION } else { 'v25.0' }),
  [string]$IgUserId = $env:META_IG_USER_ID,
  [string]$AccessToken = $env:META_IG_ACCESS_TOKEN,
  [string]$HostUrl = $(if ($env:META_GRAPH_HOST) { $env:META_GRAPH_HOST } else { 'https://graph.instagram.com' }),
  [string]$AltTextPrefix = $(if ($env:META_ALT_TEXT_PREFIX) { $env:META_ALT_TEXT_PREFIX } else { '부동산 공급 뉴스 카드뉴스' }),
  [bool]$IsAiGenerated = $(if ($env:META_IS_AI_GENERATED) { [System.Convert]::ToBoolean($env:META_IS_AI_GENERATED) } else { $true }),
  [switch]$PrepareJpeg,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CarouselDir)) { throw "CarouselDir not found: $CarouselDir" }
$resolvedCarouselDir = (Resolve-Path -LiteralPath $CarouselDir).Path

if (-not $CaptionPath) { $CaptionPath = Join-Path $resolvedCarouselDir 'caption.txt' }
$caption = ''
if (Test-Path -LiteralPath $CaptionPath) {
  $caption = Get-Content -LiteralPath $CaptionPath -Raw -Encoding UTF8
}

$publishDir = Join-Path $resolvedCarouselDir '_publish'
if ($PrepareJpeg) {
  New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
  Add-Type -AssemblyName System.Drawing
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
  $encoder = [System.Drawing.Imaging.Encoder]::Quality
  $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters 1
  $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]92)

  Get-ChildItem -LiteralPath $resolvedCarouselDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
    $image = [System.Drawing.Image]::FromFile($_.FullName)
    try {
      $jpgPath = Join-Path $publishDir ([System.IO.Path]::GetFileNameWithoutExtension($_.Name) + '.jpg')
      $image.Save($jpgPath, $codec, $encoderParams)
    } finally {
      $image.Dispose()
    }
  }
}

$localJpegs = @()
if (Test-Path -LiteralPath $publishDir) {
  $localJpegs = @(Get-ChildItem -LiteralPath $publishDir -Filter '*.jpg' | Sort-Object Name)
}

if ($localJpegs.Count -eq 0) {
  $localJpegs = @(Get-ChildItem -LiteralPath $resolvedCarouselDir -Filter '*.jpg' | Sort-Object Name)
}

if ($localJpegs.Count -lt 2 -or $localJpegs.Count -gt 10) {
  throw "Instagram carousel publishing needs 2-10 JPEG images. Found: $($localJpegs.Count)"
}

$base = $ImageBaseUrl.TrimEnd('/')
$imageUrls = @($localJpegs | ForEach-Object { "$base/$($_.Name)" })

$manifest = [ordered]@{
  carouselDir = $resolvedCarouselDir
  generatedAt = (Get-Date -Format o)
  graphVersion = $GraphVersion
  hostUrl = $HostUrl
  imageUrls = $imageUrls
  captionPath = $CaptionPath
  isAiGenerated = $IsAiGenerated
  altTextPrefix = $AltTextPrefix
  readyToPublish = (-not $DryRun)
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedCarouselDir 'publish-manifest.json') -Encoding UTF8

if ($DryRun) {
  Write-Host "Dry run complete. JPEG/public URL manifest written:"
  Write-Host (Join-Path $resolvedCarouselDir 'publish-manifest.json')
  exit 0
}

if (-not $IgUserId) { throw "META_IG_USER_ID is required." }
if (-not $AccessToken) { throw "META_IG_ACCESS_TOKEN is required." }

$apiRoot = "$($HostUrl.TrimEnd('/'))/$GraphVersion/$IgUserId"

try {
  $limit = Invoke-RestMethod -Method Get -Uri "$apiRoot/content_publishing_limit" -Body @{ access_token = $AccessToken }
  $limit | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedCarouselDir 'content-publishing-limit.json') -Encoding UTF8
} catch {
  Write-Warning "Could not check content publishing limit: $($_.Exception.Message)"
}

$childContainerIds = @()
for ($i = 0; $i -lt $imageUrls.Count; $i++) {
  $imageUrl = $imageUrls[$i]
  $body = @{
    image_url = $imageUrl
    is_carousel_item = 'true'
    alt_text = "$AltTextPrefix $($i + 1)장"
    access_token = $AccessToken
  }
  $item = Invoke-RestMethod -Method Post -Uri "$apiRoot/media" -Body $body
  $childContainerIds += [string]$item.id
}

$carouselBody = @{
  media_type = 'CAROUSEL'
  children = ($childContainerIds -join ',')
  caption = $caption
  is_ai_generated = ([string]$IsAiGenerated).ToLowerInvariant()
  access_token = $AccessToken
}
$carousel = Invoke-RestMethod -Method Post -Uri "$apiRoot/media" -Body $carouselBody
$carouselId = [string]$carousel.id

$finished = $false
for ($attempt = 1; $attempt -le 5; $attempt++) {
  $status = Invoke-RestMethod -Method Get -Uri "$($HostUrl.TrimEnd('/'))/$GraphVersion/$carouselId" -Body @{ fields = 'status_code'; access_token = $AccessToken }
  $status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedCarouselDir 'publish-container-status.json') -Encoding UTF8
  if ($status.status_code -eq 'FINISHED') {
    $finished = $true
    break
  }
  if ($status.status_code -eq 'ERROR' -or $status.status_code -eq 'EXPIRED') {
    throw "Instagram carousel container status is $($status.status_code). See publish-container-status.json."
  }
  if ($attempt -lt 5) { Start-Sleep -Seconds 60 }
}

if (-not $finished) {
  throw "Instagram carousel container was not ready after 5 status checks. See publish-container-status.json."
}

$published = Invoke-RestMethod -Method Post -Uri "$apiRoot/media_publish" -Body @{
  creation_id = $carouselId
  access_token = $AccessToken
}

$result = [ordered]@{
  publishedAt = (Get-Date -Format o)
  instagramMediaId = [string]$published.id
  carouselContainerId = $carouselId
  childContainerIds = $childContainerIds
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $resolvedCarouselDir 'publish-result.json') -Encoding UTF8

Write-Host "Published Instagram carousel: $($published.id)"

