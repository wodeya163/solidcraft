<#
.SYNOPSIS
构建 SolidCraft 中文版 Windows 本地安装版（MSI + 便携版 + 校验表 + 更新清单）。
.DESCRIPTION
输入是已编译好的 Windows x64 二进制（官方便携版 zip 或本地 cargo 构建目录），
因此不需要在本机安装 Rust/MSVC 就能出中文安装包；若使用仓库自带 CI 构建，
把 -BinDir 指向 target\x86_64-pc-windows-msvc\release 即可。

产物（$Dist 下）：
  SolidCraft-<版本>-zh-cn-windows-x64.msi      中文安装向导 MSI
  solidcraft-windows-x64.msi                   稳定名副本（内置更新器按名字识别）
  solidcraft-<版本>-zh-cn-windows-x64-portable.zip
  solidcraft-windows-x64-portable.zip           稳定名副本
  SHA256SUMS.txt                               发行校验表
  latest.json                                  中文更新清单（自动更新源）
.EXAMPLE
pwsh zh-cn/packaging/windows/package-zh-cn.ps1 -PortableZip dist/upstream-windows-x64-portable.zip
#>
[CmdletBinding()]
param(
    [string] $Version = '0.48.2',
    [string] $UpstreamVersion = '0.48.1',
    [string] $PortableZip = '',
    [string] $BinDir = '',
    [string] $Dist = '',
    [switch] $SkipWix,
    [switch] $SkipPortable
)
$ErrorActionPreference = 'Stop'

$Root    = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$ZhDir   = Join-Path $Root 'zh-cn'
$Updater = Join-Path $ZhDir 'packaging\windows\updater'
$Wxs     = Join-Path $PSScriptRoot 'solidcraft.zh-cn.wxs'
$Wxl     = Join-Path $PSScriptRoot 'solidcraft.zh-cn.wxl'
$Icon    = Join-Path $Root 'assets\icons\app\windows\exports\solidcraft.ico'
if (-not $Dist) { $Dist = Join-Path $Root 'dist\release' }
if (-not (Test-Path $Dist)) { New-Item -ItemType Directory -Path $Dist -Force | Out-Null }
$Dist = (Resolve-Path $Dist).Path

$Tag      = "v$Version"
$Repo     = 'wodeya163/solidcraft'
$BaseUrl  = "https://github.com/$Repo/releases/latest/download"
$ApiUrl   = "https://api.github.com/repos/$Repo/releases/latest"
$AssetMsi = 'solidcraft-windows-x64.msi'
$AssetZip = 'solidcraft-windows-x64-portable.zip'
$Date     = Get-Date -Format 'yyyy-MM-dd'

# 每次构建使用全新 stage，避免删除动作影响已有产物
$StageRoot = Join-Path $Dist ("stage-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Stage     = Join-Path $StageRoot 'bin'
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
Write-Host "==> 准备二进制：$Stage"

if ($BinDir) {
    foreach ($f in 'solidcraft.exe', 'solidcraft-cli.exe') {
        $src = Join-Path $BinDir $f
        if (-not (Test-Path $src)) { throw "缺少二进制：$src" }
        Copy-Item $src $Stage
    }
} elseif ($PortableZip) {
    if (-not (Test-Path $PortableZip)) { throw "找不到官方便携版：$PortableZip" }
    $expand = Join-Path $StageRoot 'upstream'
    Expand-Archive -Path $PortableZip -DestinationPath $expand -Force
    $inner = @(Get-ChildItem -Path $expand -Directory | Select-Object -First 1)
    $srcDir = if ($inner.Count -gt 0) { $inner[0].FullName } else { $expand }
    Get-ChildItem -Path $srcDir -File | ForEach-Object { Copy-Item $_.FullName $Stage }
} else {
    throw '请提供 -PortableZip（官方便携版 zip）或 -BinDir（已编译二进制目录）'
}

foreach ($f in 'solidcraft.exe', 'solidcraft-cli.exe') {
    if (-not (Test-Path (Join-Path $Stage $f))) { throw "stage 中缺少 $f" }
}
# 许可证与第三方声明（本地 cargo 构建时补上）
foreach ($f in 'LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE', 'THIRD-PARTY-LICENSES.txt', 'README.md') {
    $src = Join-Path $Root $f
    if (-not (Test-Path (Join-Path $Stage $f)) -and (Test-Path $src)) { Copy-Item $src $Stage }
}

# ---- 中文增强文件 ------------------------------------------------------------
Write-Host '==> 复制中文增强文件'
foreach ($f in '检查更新.ps1', '写入中文配置.ps1', '启动中文版.ps1', '注册每日自动更新.ps1') {
    Copy-Item (Join-Path $Updater $f) $Stage
}
$readme = Join-Path $ZhDir 'docs\安装与自动更新.zh-CN.md'
if (Test-Path $readme) { Copy-Item $readme (Join-Path $Stage 'SolidCraft中文版说明.md') }
$i18n = Join-Path $ZhDir 'i18n\zh-CN.json'
if (Test-Path $i18n) { Copy-Item $i18n (Join-Path $Stage '中文语言包.json') }

$versionJson = [ordered]@{
    '产品'     = 'SolidCraft 中文版'
    '版本'     = $Version
    '基于上游' = $UpstreamVersion
    '发布日期' = $Date
    '更新仓库' = $Repo
    '更新接口' = $ApiUrl
    '安装包资产' = $AssetMsi
} | ConvertTo-Json -Depth 5
Set-Content -Path (Join-Path $Stage '版本.json') -Value $versionJson -Encoding UTF8

# 更新清单必须在 WiX 构建之前就位（wxs 会把它打进 MSI）。
# 清单不写 MSI 自身的 SHA-256：包内文件无法包含自己的哈希，
# 校验一律以同一发行版的 SHA256SUMS.txt 为准。
$feed = [ordered]@{
    '产品'       = 'SolidCraft 中文版'
    '版本'       = $Version
    '标签'       = $Tag
    '发布日期'   = $Date
    '基于上游'   = $UpstreamVersion
    '更新仓库'   = $Repo
    '更新接口'   = $ApiUrl
    '发行页'     = "https://github.com/$Repo/releases/latest"
    '校验表'     = "$BaseUrl/SHA256SUMS.txt"
    '安装包'     = [ordered]@{
        '名称'     = $AssetMsi
        '下载地址' = "$BaseUrl/$AssetMsi"
    }
    '便携版'     = [ordered]@{
        '名称'     = $AssetZip
        '下载地址' = "$BaseUrl/$AssetZip"
    }
    '说明'       = '中文界面（简体中文默认）｜中文安装向导｜自动更新关联 wodeya163/solidcraft releases/latest'
} | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path $Stage '更新清单.json') -Value $feed -Encoding UTF8
Set-Content -Path (Join-Path $Dist '更新清单.json') -Value $feed -Encoding UTF8
Set-Content -Path (Join-Path $Dist 'latest.json') -Value $feed -Encoding UTF8

# ---- MSI ----------------------------------------------------------------------
$Msi = Join-Path $Dist "SolidCraft-$Version-zh-cn-windows-x64.msi"
if (-not $SkipWix) {
    Write-Host '==> WiX v5 构建中文 MSI'
    $MsiVersion = ($Version -split '-')[0]
    $wix = Get-Command wix -ErrorAction Stop
    & $wix.Source build $Wxs -arch x64 `
        -ext WixToolset.UI.wixext -ext WixToolset.Util.wixext `
        -culture en-US -loc $Wxl `
        -d "Version=$MsiVersion" -d "DisplayVersion=$Version" `
        -d "BinDir=$Stage" -d "IconPath=$Icon" -o $Msi
    if ($LASTEXITCODE -ne 0) { throw "WiX 构建失败，退出码 $LASTEXITCODE" }
    $pdb = [IO.Path]::ChangeExtension($Msi, '.wixpdb')
    if (Test-Path $pdb) { Remove-Item $pdb -Force -ErrorAction SilentlyContinue }
    Write-Host "    MSI：$([math]::Round((Get-Item $Msi).Length / 1MB, 1)) MB"
}

# ---- 便携版 -------------------------------------------------------------------
$Zip = Join-Path $Dist "solidcraft-$Version-zh-cn-windows-x64-portable.zip"
if (-not $SkipPortable) {
    Write-Host '==> 打包中文便携版'
    Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $Zip -CompressionLevel Optimal -Force
    Write-Host "    ZIP：$([math]::Round((Get-Item $Zip).Length / 1MB, 1)) MB"
}

# ---- 稳定名副本、校验表、更新清单 ----------------------------------------------
Write-Host '==> 生成发布资产'
$publish = @()
if (Test-Path $Msi) {
    Copy-Item $Msi (Join-Path $Dist $AssetMsi) -Force
    $publish += @($AssetMsi, [IO.Path]::GetFileName($Msi))
}
if (Test-Path $Zip) {
    Copy-Item $Zip (Join-Path $Dist $AssetZip) -Force
    $publish += @($AssetZip, [IO.Path]::GetFileName($Zip))
}

$sums = @()
foreach ($name in $publish) {
    $hash = (Get-FileHash -Path (Join-Path $Dist $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    $sums += "$hash  $name"
}
Set-Content -Path (Join-Path $Dist 'SHA256SUMS.txt') -Value $sums -Encoding ASCII

Write-Host ''
Write-Host '==> 完成，发布资产：'
Get-ChildItem -Path $Dist -File | Where-Object { $_.Name -notin @('stage-*') } |
    Select-Object Name, @{N = 'MB'; E = { [math]::Round($_.Length / 1MB, 1) } } |
    Format-Table -AutoSize
