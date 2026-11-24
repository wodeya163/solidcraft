<#
.SYNOPSIS
注册 / 删除「SolidCraft 中文版每日自动更新」计划任务。
.DESCRIPTION
默认每天 10:00 静默检查远程发行版（只记录日志，不自动安装）；
加 -AutoInstall 则在发现新版本且程序未运行时自动下载、校验并安装。
需要以管理员身份运行；-Remove 删除任务。
#>
[CmdletBinding()]
param(
    [switch] $AutoInstall,
    [switch] $Remove,
    [string] $Time = '10:00'
)
$ErrorActionPreference = 'Stop'
$TaskName = 'SolidCraft中文版自动更新'
$Updater  = Join-Path $PSScriptRoot '检查更新.ps1'

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "已删除计划任务：$TaskName"
    return
}
if (-not (Test-Path $Updater)) { throw "找不到更新器：$Updater" }

$argList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Updater`" -Silent"
if (-not $AutoInstall) { $argList += ' -CheckOnly' }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argList
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Description 'SolidCraft 中文版：每日检查 wodeya163/solidcraft 的最新发行版' -Force | Out-Null

if ($AutoInstall) {
    Write-Host "已注册：每天 $Time 自动检查并安装新版本（程序运行时会自动推迟）。"
} else {
    Write-Host "已注册：每天 $Time 静默检查新版本（记录日志，不自动安装）。"
}
Write-Host "日志位置：%LOCALAPPDATA%\SolidCraft中文版\自动更新日志.txt"
