# Sync published GitHub Releases (assets) to Gitee for the same repo tags.
# Requires: git remote `gitee` with URL https://USER:TOKEN@gitee.com/... OR env GITEE_TOKEN.
# Usage: run from repo root: powershell -ExecutionPolicy Bypass -File tools/sync-github-releases-to-gitee.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$GitHubOwnerRepo = "po1son7/QManager"
$GiteeOwner = "aowu2048"
$GiteeRepo = "QManager"
$ApiBase = "https://gitee.com/api/v5/repos/$GiteeOwner/$GiteeRepo"

function Normalize-GiteeReleasePayload {
  param($Payload)
  if ($null -eq $Payload) { return $null }
  if ($Payload -is [string] -and ($Payload.Trim().ToLower() -eq 'null')) { return $null }
  try {
    $id = $Payload.id
    if (-not $id) { return $null }
  } catch { return $null }
  return $Payload
}

$token = $env:GITEE_TOKEN
if (-not $token) {
  $giteeUrl = (& git config --get remote.gitee.url 2>$null)
  if ($giteeUrl -match 'https://[^:]+:([^@]+)@') {
    $token = [uri]::UnescapeDataString($Matches[1])
  }
}
if (-not $token) {
  Write-Error "Set GITEE_TOKEN or configure remote.gitee.url with embedded token."
}

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "qm-gitee-sync-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
try {
  Write-Host "Pushing git tags to Gitee..."
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  Set-Location $repoRoot
  cmd /c "git fetch origin --tags 2>nul"
  cmd /c "git push gitee --tags 2>nul"
  Write-Host "git tags push finished."

  $ghHeaders = @{
    "User-Agent" = "QManager-Release-Sync"
    "Accept" = "application/vnd.github+json"
  }
  $releases = New-Object System.Collections.Generic.List[object]
  $page = 1
  while ($true) {
    $url = "https://api.github.com/repos/$GitHubOwnerRepo/releases?per_page=100&page=$page"
    $batch = Invoke-RestMethod -Uri $url -Headers $ghHeaders -TimeoutSec 120
    $arr = @($batch)
    if ($arr.Count -eq 0) { break }
    foreach ($r in $arr) { $releases.Add($r) | Out-Null }
    $page++
  }
  Write-Host "Found $($releases.Count) GitHub releases."

  foreach ($r in $releases) {
    if ($r.draft) {
      Write-Host "Skip draft $($r.tag_name)"
      continue
    }
    $tag = $r.tag_name
    Write-Host "=== $tag ==="

    $existing = $null
    try {
      $rawExisting = Invoke-RestMethod -Uri "$ApiBase/releases/tags/$([uri]::EscapeDataString($tag))?access_token=$token" -TimeoutSec 60
      $existing = Normalize-GiteeReleasePayload $rawExisting
    } catch {
      $existing = $null
    }

    $releaseId = $null
    if (-not $existing) {
      $bodyObj = [ordered]@{
        tag_name = $tag
        name = $r.name
        body = $r.body
        prerelease = [bool]$r.prerelease
        target_commitish = "main"
      }
      $json = $bodyObj | ConvertTo-Json -Depth 8 -Compress
      try {
        $created = Invoke-RestMethod -Method Post -Uri "$ApiBase/releases?access_token=$token" `
          -Body ([System.Text.UTF8Encoding]::UTF8.GetBytes($json)) `
          -ContentType "application/json; charset=utf-8" -TimeoutSec 120
        $releaseId = $created.id
        Write-Host "Created Gitee release id=$releaseId"
      } catch {
        Write-Warning "Create release failed for $tag : $_"
        continue
      }
    } else {
      $releaseId = $existing.id
      Write-Host "Gitee release exists id=$releaseId"
    }

    $have = @{}
    try {
      $files = Invoke-RestMethod -Uri "$ApiBase/releases/$releaseId/attach_files?access_token=$token&page=1&per_page=100" -TimeoutSec 60
      foreach ($f in @($files)) {
        if ($f.name) { $have[$f.name] = $true }
      }
    } catch { }

    foreach ($asset in @($r.assets)) {
      $name = $asset.name
      if ($have.ContainsKey($name)) {
        Write-Host "  skip $name (already on Gitee)"
        continue
      }
      $dl = $asset.browser_download_url
      $out = Join-Path $tmpRoot "$tag-$name"
      Write-Host "  download $name ..."
      Invoke-WebRequest -Uri $dl -Headers $ghHeaders -OutFile $out -TimeoutSec 600
      Write-Host "  upload $name ..."
      $curlBody = Join-Path $tmpRoot "upload-body-$name.json"
      $httpCode = & curl.exe -sS -g --max-time 600 -o $curlBody -w "%{http_code}" -X POST `
        "$ApiBase/releases/$releaseId/attach_files?access_token=$token" `
        -H "User-Agent: QManager-Release-Sync" `
        -F "file=@$out"
      Remove-Item -Force $out -ErrorAction SilentlyContinue
      if ($httpCode -lt 200 -or $httpCode -ge 300) {
        Write-Warning "  upload HTTP $httpCode for $name : $(Get-Content $curlBody -Raw -ErrorAction SilentlyContinue)"
      } else {
        Remove-Item -Force $curlBody -ErrorAction SilentlyContinue
        Write-Host "  uploaded $name (HTTP $httpCode)"
      }
    }
  }

  Write-Host "Done."
} finally {
  Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
}
