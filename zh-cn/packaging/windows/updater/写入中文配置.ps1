<#
.SYNOPSIS
把 SolidCraft 中文版的用户界面语言预置为简体中文（zh）。
.DESCRIPTION
SolidCraft 的偏好保存在 %APPDATA%\SolidCraft\data\app.ron（eframe 的 RON 键值存储），
键为 solidcraft.prefs，值是 JSON 字符串。仅在首次运行（文件不存在）时写入完整偏好；
若已存在且仍是「跟随系统」，只把 language 改成 zh；用户已经选过其它语言则不改动。
#>
[CmdletBinding()]
param([switch] $Force)
$ErrorActionPreference = 'Stop'

$dir  = Join-Path $env:APPDATA 'SolidCraft\data'
$file = Join-Path $dir 'app.ron'

if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

if (-not (Test-Path $file) -or $Force) {
    # RON 的 map 语法；字符串值里的双引号用 \" 转义
    $content = @'
{
    "solidcraft.prefs": "{\"language\":\"zh\"}",
}
'@
    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host '已写入简体中文界面偏好（首次运行）。'
    return
}

$text = Get-Content -Path $file -Raw -Encoding UTF8
if ($text -match 'language') {
    if ($text -match '\\"language\\":\\"system\\"') {
        $text = $text -replace '\\"language\\":\\"system\\"', '\"language\":\"zh\"'
        Set-Content -Path $file -Value $text -Encoding UTF8 -NoNewline
        Write-Host '已把界面语言由「跟随系统」改为简体中文。'
    } else {
        Write-Host '用户已自行设置界面语言，保持不变。'
    }
} else {
    Write-Host '已有偏好文件但不含语言字段，保持不变（程序默认简体中文）。'
}
