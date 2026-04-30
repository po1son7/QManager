#Requires -Version 5.1
<#
.SYNOPSIS
  上游合并 → 推 GitHub/Gitee → 按 package.json 版本打 tag →（可选）本机打包 → 同步 GitHub Release 到 Gitee。

.DESCRIPTION
  - 版本号：自动从仓库根目录 package.json 的 "version" 读取（须为 vX.Y.Z），无需手填。
  - 路由器 / OpenWRT 安装：本脚本**不修改** qmanager-installer.sh、mirror.sh、opkg 等；设备端仍走你已配置的大陆源（默认 Gitee OTA 等）。
  - 仅在你本机执行 bun/npm 时：若设置环境变量 QM_USE_CN_DEV_MIRROR=1，且你**尚未**配置
    npm_config_registry / BUN_INSTALL_MIRROR，则**仅对本进程**设置常见 npmmirror（不写入全局），
    避免覆盖你自己已有的大陆加速配置。

.PARAMETER RepoRoot
  仓库绝对路径；默认为本脚本上一级目录。

.PARAMETER NoWait
  不暂停等待「GitHub Release 已有附件」；适合 CI 或你已确认发包完成。

.PARAMETER SkipTag
  不创建 / 推送 tag（只做上游合并与双远端推送 + 可选 Gitee Release 同步）。

.PARAMETER SkipGiteeReleaseSync
  不调用 sync-github-releases-to-gitee.ps1。

.PARAMETER RunLocalPackage
  合并并推送 main 后，在本机执行 bun install + bun run package（用于无 GitHub Actions 发包）。
  与大陆镜像：`QM_USE_CN_DEV_MIRROR=1` 时对 bun/npm 可选加速，见上文。

.NOTES
  若合并 upstream 时改动了大陆镜像相关 shell，请以你的 fork 为准解决冲突——那是 git 合并行为，与本脚本无关。
#>
param(
    [string]$RepoRoot = "",
    [switch]$NoWait,
    [switch]$SkipTag,
    [switch]$SkipGiteeReleaseSync,
    [switch]$RunLocalPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

function Read-PackageVersion {
    param([string]$Root)
    $pj = Join-Path $Root "package.json"
    if (-not (Test-Path -LiteralPath $pj)) {
        throw "package.json not found: $pj"
    }
    $j = Get-Content -LiteralPath $pj -Raw -Encoding UTF8 | ConvertFrom-Json
    $v = [string]$j.version
    if ([string]::IsNullOrWhiteSpace($v)) {
        throw 'package.json missing non-empty "version"'
    }
    $v = $v.Trim()
    if ($v -notmatch '^v\d') {
        throw "package.json version must look like v0.1.23, got: $v"
    }
    return $v
}

function Invoke-Git {
    param([string[]]$Args)
    $old = $global:ErrorActionPreference
    $global:ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $RepoRoot @Args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host ($out | Out-String)
            throw "git $($Args -join ' ') exit $LASTEXITCODE"
        }
    } finally {
        $global:ErrorActionPreference = $old
    }
}

function Test-TagExistsOnRemote {
    param([string]$Remote, [string]$Tag)
    $ref = & git -C $RepoRoot ls-remote --tags $Remote "refs/tags/$Tag" 2>$null
    return -not [string]::IsNullOrWhiteSpace($ref)
}

# --- 可选：仅本进程、且不覆盖已有环境变量的大陆开发镜像 ---
if ($env:QM_USE_CN_DEV_MIRROR -eq '1') {
    if (-not $env:npm_config_registry) {
        $env:npm_config_registry = 'https://registry.npmmirror.com'
    }
    if (-not $env:BUN_INSTALL_MIRROR) {
        $env:BUN_INSTALL_MIRROR = 'https://npmmirror.com/mirrors/bun'
    }
    Write-Host "[QM_USE_CN_DEV_MIRROR] npm_config_registry=$($env:npm_config_registry)" -ForegroundColor DarkGray
    Write-Host "[QM_USE_CN_DEV_MIRROR] BUN_INSTALL_MIRROR=$($env:BUN_INSTALL_MIRROR)" -ForegroundColor DarkGray
}

Set-Location $RepoRoot

$version = Read-PackageVersion -Root $RepoRoot
Write-Host "package.json version (used as git tag): $version" -ForegroundColor Cyan

Write-Host "`n--- 1) merge upstream into main ---" -ForegroundColor Green
Invoke-Git @("checkout", "main")
Invoke-Git @("pull", "origin", "main")
Invoke-Git @("fetch", "upstream", "--tags")
Invoke-Git @("merge", "upstream/main", "--no-edit")

Write-Host "`n--- 2) push main to origin + gitee ---" -ForegroundColor Green
Invoke-Git @("push", "origin", "main")
Invoke-Git @("push", "gitee", "main")

# 合并后若上游改过 package.json，重新读一次版本
$version = Read-PackageVersion -Root $RepoRoot
Write-Host "version after merge: $version" -ForegroundColor Cyan

if ($RunLocalPackage) {
    Write-Host "`n--- 2b) local bun install + package ---" -ForegroundColor Green
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        throw "bun not found in PATH; install Bun or omit -RunLocalPackage"
    }
    Push-Location $RepoRoot
    try {
        & bun install
        if ($LASTEXITCODE -ne 0) { throw "bun install failed" }
        & bun run package
        if ($LASTEXITCODE -ne 0) { throw "bun run package failed" }
    } finally {
        Pop-Location
    }
    Write-Host "Artifacts under qmanager-build/ + staging per build.sh — upload to GitHub Release if needed." -ForegroundColor Yellow
}

if (-not $SkipTag) {
    Write-Host "`n--- 3) tag + push tag ---" -ForegroundColor Green
    $onOrigin = Test-TagExistsOnRemote -Remote "origin" -Tag $version
    $onGiteeRemote = Test-TagExistsOnRemote -Remote "gitee" -Tag $version

    if (-not $onOrigin) {
        $hasLocal = & git -C $RepoRoot tag -l $version
        if (-not [string]::IsNullOrWhiteSpace($hasLocal)) {
            Invoke-Git @("tag", "-d", $version)
        }
        Invoke-Git @("tag", "-a", $version, "-m", $version)
        Invoke-Git @("push", "origin", $version)
    } else {
        Write-Host "Tag $version already on origin — skip create/push to origin." -ForegroundColor Yellow
    }

    if (-not $onGiteeRemote) {
        Invoke-Git @("push", "gitee", $version)
    } else {
        Write-Host "Tag $version already on gitee." -ForegroundColor DarkGray
    }
} else {
    Write-Host "`n--- 3) skip tag (--SkipTag) ---" -ForegroundColor Yellow
}

if (-not $NoWait -and -not $SkipGiteeReleaseSync) {
    Write-Host "`n请确认 GitHub Release 上已有 $version 的 qmanager.tar.gz / sha256sum.txt（或先开 CI 再回车）…" -ForegroundColor Yellow
    Read-Host | Out-Null
}

if (-not $SkipGiteeReleaseSync) {
    Write-Host "`n--- 4) sync GitHub Releases → Gitee ---" -ForegroundColor Green
    $sync = Join-Path $PSScriptRoot "sync-github-releases-to-gitee.ps1"
    if (-not (Test-Path -LiteralPath $sync)) {
        throw "Missing $sync"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sync
} else {
    Write-Host "`n--- 4) skip Gitee release sync (--SkipGiteeReleaseSync) ---" -ForegroundColor Yellow
}

Write-Host "`nDone. Version=$version" -ForegroundColor Green
