; SolidCraft 中文版 —— Windows 免管理员 exe 安装程序（NSIS，Unicode）
;
; 由 zh-cn/packaging/windows/build-from-source.ps1 调用：
;   makensis /DVERSION=0.49.0 /DSTAGE_DIR=<stage\bin> /DOUT_FILE=<输出 exe> installer.nsi
;
; 设计要点（与程序内置更新器强相关）：
;   1) 安装到 %LOCALAPPDATA%\Programs\SolidCraft中文版，RequestExecutionLevel=user，
;      不需要管理员权限，也绕开 msiexec；
;   2) 同目录保留 solidcraft-cli.exe —— 内置更新器据此判定为「便携安装」形态，
;      自动从 wodeya163/solidcraft/releases/latest 下载
;      solidcraft-windows-x64-portable.zip 并原地替换 exe，实现全自动更新；
;   3) 绝对不写 HKLM\Software\SolidCraft\InstallDir —— 那个键会让更新器误判为 MSI 安装，
;      转而去下载 MSI（本仓库也发布 MSI，但免管理员体验会退化）。

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!ifndef VERSION
  !define VERSION "0.49.0"
!endif
!ifndef STAGE_DIR
  !error "请用 /DSTAGE_DIR=<stage\bin> 指定已编译好的二进制目录"
!endif
!ifndef OUT_FILE
  !error "请用 /DOUT_FILE=<输出 exe> 指定安装程序路径"
!endif
!ifndef ICON_FILE
  !error "请用 /DICON_FILE=<solidcraft.ico> 指定程序图标"
!endif

!define APPNAME "SolidCraft 中文版"
!define REGKEY "Software\SolidCraft中文版"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\SolidCraft中文版"

Name "${APPNAME} ${VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\SolidCraft中文版"
InstallDirRegKey HKCU "${REGKEY}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 64
ManifestDPIAware true

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=2052 "ProductName" "${APPNAME}"
VIAddVersionKey /LANG=2052 "CompanyName" "wodeya163"
VIAddVersionKey /LANG=2052 "FileDescription" "SolidCraft 中文版安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=2052 "LegalCopyright" "MIT OR Apache-2.0"

!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_WELCOMEPAGE_TITLE "欢迎安装 ${APPNAME} ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "本程序由您自己的 GitHub 仓库 wodeya163/solidcraft 源码编译而成。$\r$\n$\r$\n安装后，程序内的「检查更新」会自动连接该仓库的 releases/latest，下载并校验新版安装包后原地更新。$\r$\n$\r$\n安装不需要管理员权限，文件放在当前用户目录下。"
!define MUI_FINISHPAGE_TITLE "安装完成"
!define MUI_FINISHPAGE_TEXT "${APPNAME} 已安装到：$\r$\n$INSTDIR$\r$\n$\r$\n首次启动即为简体中文界面。以后在程序里点「帮助 → 检查更新」即可升级。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\solidcraft.exe"
!define MUI_FINISHPAGE_RUN_TEXT "立即启动 SolidCraft 中文版"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\SolidCraft中文版说明.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "查看中文使用与自动更新说明"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

Section "主程序" SEC_MAIN
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; 便携包全部内容：主程序、CLI、许可证、中文增强脚本、中文语言包、版本/更新清单
  File /r "${STAGE_DIR}\*.*"
  ; 程序图标（来自源码 assets/icons/app/windows/exports/solidcraft.ico）
  File "/oname=solidcraft.ico" "${ICON_FILE}"

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\solidcraft.exe" "" "$INSTDIR\solidcraft.ico" 0
  CreateShortCut "$SMPROGRAMS\${APPNAME}\检查更新.lnk" \
    "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" \
    "-NoProfile -ExecutionPolicy Bypass -File $\"$INSTDIR\检查更新.ps1$\"" \
    "$INSTDIR\solidcraft.ico" 0
  CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\solidcraft.exe" "" "$INSTDIR\solidcraft.ico" 0

  WriteRegStr HKCU "${REGKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${REGKEY}" "Version" "${VERSION}"
  WriteRegStr HKCU "${REGKEY}" "更新仓库" "wodeya163/solidcraft"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME} ${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "wodeya163"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\solidcraft.ico"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" "$\"$INSTDIR\卸载.exe$\""
  WriteRegStr HKCU "${UNINSTKEY}" "URLInfoAbout" "https://github.com/wodeya163/solidcraft/releases/latest"
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
  WriteUninstaller "$INSTDIR\卸载.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\卸载.exe"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\检查更新.lnk"
  RMDir "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegKey HKCU "${REGKEY}"
SectionEnd
