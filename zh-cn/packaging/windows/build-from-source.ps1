<#
.SYNOPSIS
  从本仓库源码编译并打包 SolidCraft 中文版 Windows exe 安装程序。

.DESCRIPTION
  完整流程（本机或 GitHub Actions 均可跑）：
    1) cargo build 主程序 + CLI（MSVC x64，静态 CRT，不需要 VC++ 运行库）
    2) 调用 package-zh-cn.ps1 产出中文 MSI / 便携 zip / 中文增强文件
    3) 复制出官方形态的单文件 exe：SolidCraft-<版本>-windows-x64.exe
    4) NSIS 编译免管理员中文安装向导：SolidCraft-<版本>-zh-cn-setup.exe
    5) 生成 SHA256SUMS.txt 与 latest.json

  第 5 步是关键：程序内置更新器下载资产后，必须在 Release 的
  SHA256SUMS.txt 里查到该资产名的哈希，否则拒绝安装（install.rs:235）。
  因此三种安装形态对应的资产都必须列进校验表：
    WindowsMsi       -> solidcraft-windows-x64.msi
    WindowsPortable  -> solidcraft-windows-x64-portable.zip   （NSIS 安装器属于这一形态）
    WindowsExe       -> SolidCraft-<版本>-windows-x64.exe

.EXAMPLE
  pwsh zh-cn/packaging/windows/build-from-source.ps1 -Version 0.49.0
#>
[CmdletBinding()]
param(
    [string] $Version = '0.49.0',
    [string] $Dist = '',
    [switch] $SkipBuild,
    [switch] $SkipInstaller
)
$ErrorActionPreference = 'Stop'

$Root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Target = 'x86_64-pc-windows-msvc'
$BinDir = Join-Path $Root "target\$Target\release"
if (-not $Dist) { $Dist = Join-Path $Root 'dist\release' }
New-Item -ItemType Directory -Path $Dist -Force | Out-Null
$Dist = (Resolve-Path $Dist).Path

Write-Host "==> SolidCraft 中文版 $Version，源码：$Root"

# ---- 1) 从源码编译 ------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "==> 编译主程序与 CLI（$Target，静态 CRT）"
    $flagVar = 'CARGO_TARGET_' + ($Target.ToUpper() -replace '-', '_') + '_RUSTFLAGS'
    [Environment]::SetEnvironmentVariable($flagVar, '-C target-feature=+crt-static')
    & cargo build --release --locked -p solidcraft --target $Target
    if ($LASTEXITCODE -ne 0) { throw "cargo build 主程序失败，退出码 $LASTEXITCODE" }
    & cargo build --release --locked -p solidcraft-cli --target $Target
    if ($LASTEXITCODE -ne 0) { throw "cargo build CLI 失败，退出码 $LASTEXITCODE" }
} else {
    Write-Host '==> 跳过编译，使用已有二进制'
}
foreach ($f in 'solidcraft.exe', 'solidcraft-cli.exe') {
    if (-not (Test-Path (Join-Path $BinDir $f))) { throw "缺少二进制：$(Join-Path $BinDir $f)" }
}

# ---- 2) 中文 MSI 与便携包 ------------------------------------------------------
Write-Host '==> 打包中文 MSI / 便携版'
& (Join-Path $PSScriptRoot 'package-zh-cn.ps1') `
    -Version $Version -UpstreamVersion $Version -BinDir $BinDir -Dist $Dist

$stage = Get-ChildItem -LiteralPath $Dist -Directory -Filter 'stage-*' |
    Sort-Object CreationTime -Descending | Select-Object -First 1
if (-not $stage) { throw '找不到 package-zh-cn.ps1 生成的 stage 目录' }
$stageBin = Join-Path $stage.FullName 'bin'

# ---- 3) 单文件 exe（内置更新器 WindowsExe 形态用） -----------------------------
$plainName = "SolidCraft-$Version-windows-x64.exe"
$plainExe  = Join-Path $Dist $plainName
Copy-Item (Join-Path $stageBin 'solidcraft.exe') $plainExe -Force
Write-Host "    单文件 exe：$plainName"

# ---- 4) NSIS 中文 exe 安装程序 -------------------------------------------------
$setupName = "SolidCraft-$Version-zh-cn-setup.exe"
$setupExe  = Join-Path $Dist $setupName
if (-not $SkipInstaller) {
    Write-Host '==> NSIS 编译中文 exe 安装程序'
    $makensis = Get-Command makensis -ErrorAction Stop
    $nsi  = Join-Path $PSScriptRoot 'installer.nsi'
    $icon = Join-Path $Root 'assets\icons\app\windows\exports\solidcraft.ico'
    if (-not (Test-Path $icon)) { throw "找不到程序图标：$icon" }
    & $makensis.Source "/DVERSION=$Version" "/DSTAGE_DIR=$stageBin" `
        "/DICON_FILE=$icon" "/DOUT_FILE=$setupExe" $nsi
    if ($LASTEXITCODE -ne 0) { throw "NSIS 编译失败，退出码 $LASTEXITCODE" }
    Write-Host "    安装程序：$setupName"
}

# ---- 5) 校验表与中文更新清单 ---------------------------------------------------
Write-Host '==> 生成 SHA256SUMS.txt 与 latest.json'
$assets = @(
    'solidcraft-windows-x64.msi',
    'solidcraft-windows-x64-portable.zip',
    $plainName
)
if (Test-Path $setupExe) { $assets += $setupName }
$sums = @()
foreach ($n in $assets) {
    $p = Join-Path $Dist $n
    if (-not (Test-Path $p)) { throw "缺少发布资产：$n" }
    $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
    $sums += "$h  $n"
}
Set-Content -LiteralPath (Join-Path $Dist 'SHA256SUMS.txt') -Value $sums -Encoding ASCII

$Repo    = 'wodeya163/solidcraft'
$BaseUrl = "https://github.com/$Repo/releases/latest/download"
$feed = [ordered]@{
    '产品'       = 'SolidCraft 中文版'
    '版本'       = $Version
    '标签'       = "v$Version"
    '发布日期'   = Get-Date -Format 'yyyy-MM-dd'
    '源码仓库'   = "https://github.com/$Repo"
    '构建方式'   = '由本仓库源码经 GitHub Actions 编译，未使用上游二进制'
    '更新仓库'   = $Repo
    '更新接口'   = "https://api.github.com/repos/$Repo/releases/latest"
    '发行页'     = "https://github.com/$Repo/releases/latest"
    '校验表'     = "$BaseUrl/SHA256SUMS.txt"
    'EXE安装程序' = [ordered]@{
        '名称'     = $setupName
        '下载地址' = "$BaseUrl/$setupName"
        '说明'     = '免管理员、中文安装向导；安装后自动按便携形态更新'
    }
    '单文件EXE'  = [ordered]@{
        '名称'     = $plainName
        '下载地址' = "$BaseUrl/$plainName"
        '说明'     = '免安装直接运行；内置更新器按同名格式替换自身'
    }
    'MSI'        = [ordered]@{ '名称' = 'solidcraft-windows-x64.msi'; '下载地址' = "$BaseUrl/solidcraft-windows-x64.msi" }
    '便携版'     = [ordered]@{ '名称' = 'solidcraft-windows-x64-portable.zip'; '下载地址' = "$BaseUrl/solidcraft-windows-x64-portable.zip" }
    '说明'       = '程序内置「检查更新」指向本仓库 releases/latest，按安装形态下载对应资产，用 SHA256SUMS.txt 校验后原地更新'
} | ConvertTo-Json -Depth 6
Set-Content -LiteralPath (Join-Path $Dist 'latest.json') -Value $feed -Encoding UTF8
Set-Content -LiteralPath (Join-Path $Dist '更新清单.json') -Value $feed -Encoding UTF8

Write-Host ''
Write-Host '==> 发布资产：'
Get-ChildItem -LiteralPath $Dist -File |
    Where-Object { $_.Extension -in @('.msi', '.zip', '.exe', '.txt', '.json') } |
    Select-Object Name, @{N = 'MB'; E = { [math]::Round($_.Length / 1MB, 1) } } |
    Format-Table -AutoSize
