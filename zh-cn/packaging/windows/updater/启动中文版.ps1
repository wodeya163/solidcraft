<#
.SYNOPSIS
SolidCraft 中文版启动器：预置中文界面 → 启动主程序 → 后台检查远程更新。
.DESCRIPTION
开始菜单的「SolidCraft 中文版」快捷方式指向本脚本，以隐藏窗口运行。
更新检查失败会静默重试，不会阻塞或影响主程序启动。
#>
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$exe  = Join-Path $here 'solidcraft.exe'

try { & (Join-Path $here '写入中文配置.ps1') } catch { }

if (Test-Path $exe) {
    Start-Process -FilePath $exe -WorkingDirectory $here
} else {
    Write-Host "找不到主程序：$exe"
}

if ($env:SOLIDCRAFT_UPDATE_CHECK -ne '0') {
    $updater = Join-Path $here '检查更新.ps1'
    if (Test-Path $updater) {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
            '-File', "`"$updater`"", '-Silent'
        )
    }
}
