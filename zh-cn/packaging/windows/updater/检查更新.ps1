<#
.SYNOPSIS
SolidCraft 中文版自动更新检查器。
.DESCRIPTION
从远程 GitHub 仓库 wodeya163/solidcraft 的 releases/latest 读取最新版本，
与本机 版本.json 比较；发现新版本时下载 solidcraft-windows-x64.msi，
用同一发行版的 SHA256SUMS.txt 校验 SHA-256，然后安装升级。
默认交互模式会先询问；-Silent 供启动器/计划任务无人值守调用；
-CheckOnly 只检查不安装。设置环境变量 SOLIDCRAFT_UPDATE_CHECK=0 可完全关闭。
#>
[CmdletBinding()]
param(
    [switch] $Silent,
    [switch] $CheckOnly,
    [switch] $Force
)
$ErrorActionPreference = 'Stop'

$Repo        = 'wodeya163/solidcraft'
$ApiUrl      = "https://api.github.com/repos/$Repo/releases/latest"
$ReleasePage = "https://github.com/$Repo/releases/latest"
$AssetName   = 'solidcraft-windows-x64.msi'
$SumsName    = 'SHA256SUMS.txt'
$InstallDir  = $PSScriptRoot
$VersionFile = Join-Path $InstallDir '版本.json'
$FeedFile    = Join-Path $InstallDir '更新清单.json'
$LogDir      = Join-Path $env:LOCALAPPDATA 'SolidCraft中文版'
$LogFile     = Join-Path $LogDir '自动更新日志.txt'

function Write-Log([string] $Text) {
    try {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text) -Encoding UTF8
    } catch { }
    if (-not $Silent) { Write-Host $Text }
}

function Show-Message([string] $Text, [string] $Title = 'SolidCraft 中文版 - 检查更新') {
    if ($Silent) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Text, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } catch { Write-Host $Text }
}

function Get-LocalVersion {
    if (Test-Path $VersionFile) {
        try { return (Get-Content $VersionFile -Raw -Encoding UTF8 | ConvertFrom-Json).版本 } catch { }
    }
    return '0.0.0'
}

function ConvertTo-Version([string] $Text) {
    $clean = ($Text -replace '^v', '') -replace '-.*$', ''
    try { return [version] $clean } catch { return [version] '0.0.0' }
}

try {
    if ($env:SOLIDCRAFT_UPDATE_CHECK -eq '0') { Write-Log '自动更新已被环境变量 SOLIDCRAFT_UPDATE_CHECK=0 关闭'; return }
    $local = Get-LocalVersion
    Write-Log "本机版本 $local，开始检查 $ReleasePage"

    $headers = @{ 'User-Agent' = 'SolidCraft-zh-CN-updater'; 'Accept' = 'application/vnd.github+json' }
    try {
        $release = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -TimeoutSec 20
        $remote = ($release.tag_name -replace '^v', '')
        $asset = @($release.assets | Where-Object { $_.name -eq $AssetName }) | Select-Object -First 1
        $sums  = @($release.assets | Where-Object { $_.name -eq $SumsName }) | Select-Object -First 1
    } catch {
        # 远程不可达时退回随包的更新清单（离线信息，不下载）
        if (Test-Path $FeedFile) {
            $feed = Get-Content $FeedFile -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Log "远程检查失败（$($_.Exception.Message)），使用随包更新清单：当前发布版本 $($feed.版本)"
        } else {
            Write-Log "远程检查失败：$($_.Exception.Message)"
        }
        if (-not $Silent) { Show-Message '暂时无法连接更新服务器，请稍后重试或访问发行页查看新版本。' }
        return
    }

    if (-not $asset) { Write-Log "最新发行版中没有找到 $AssetName，跳过"; return }
    $newer = (ConvertTo-Version $remote) -gt (ConvertTo-Version $local)
    if (-not $newer -and -not $Force) {
        Write-Log "已是最新版本（远程 $remote / 本机 $local）"
        if (-not $Silent -and -not $CheckOnly) { Show-Message "当前版本 $local 已是最新版本。" }
        return
    }

    Write-Log "发现新版本 $remote（本机 $local）"
    if ($CheckOnly) {
        if (-not $Silent) { Show-Message "发现新版本 $remote。`n请到发行页下载：$ReleasePage" }
        return
    }
    if (-not $Silent) {
        Add-Type -AssemblyName System.Windows.Forms
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "发现新版本 $remote（当前 $local）。`n是否现在下载并自动安装？",
            'SolidCraft 中文版 - 发现更新',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { Write-Log '用户选择暂不更新'; return }
    }

    if (Get-Process -Name 'solidcraft' -ErrorAction SilentlyContinue) {
        Write-Log 'SolidCraft 正在运行，推迟安装到下次检查（避免覆盖使用中的文件）'
        return
    }

    $tmp = Join-Path $env:TEMP ("SolidCraft-zh-CN-{0}.msi" -f $remote)
    Write-Log "下载 $($asset.browser_download_url)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -TimeoutSec 900

    if ($sums) {
        $sumsFile = Join-Path $env:TEMP 'SolidCraft-zh-CN-SHA256SUMS.txt'
        Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumsFile -UseBasicParsing -TimeoutSec 60
        $line = @(Get-Content $sumsFile | Where-Object { $_ -match [regex]::Escape($AssetName) }) | Select-Object -First 1
        if ($line) {
            $expected = ($line -split '\s+')[0].ToLowerInvariant()
            $actual = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expected -ne $actual) {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                throw "SHA-256 校验失败：期望 $expected，实际 $actual"
            }
            Write-Log 'SHA-256 校验通过'
        } else { Write-Log '校验表中没有该安装包条目，跳过校验' }
    }

    Write-Log "启动安装 $tmp"
    Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$tmp`" /passive /norestart" -Wait
    Write-Log "更新完成：$remote"

    if (Test-Path $VersionFile) {
        $v = Get-Content $VersionFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $v.版本 = $remote
        $v.发布日期 = (Get-Date -Format 'yyyy-MM-dd')
        $v | ConvertTo-Json -Depth 5 | Set-Content $VersionFile -Encoding UTF8
    }
    if (-not $Silent) { Show-Message "已更新到 $remote。" }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
} catch {
    Write-Log "更新失败：$($_.Exception.Message)"
    if (-not $Silent) { Show-Message "更新检查失败：$($_.Exception.Message)" 'SolidCraft 中文版 - 更新失败' }
}
