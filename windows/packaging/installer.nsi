Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
!ifndef APPDIR
  !error "APPDIR is required"
!endif
!ifndef OUTPUT
  !error "OUTPUT is required"
!endif
!ifndef VERSION
  !error "VERSION is required"
!endif
!ifndef RUNTIME
  !error "RUNTIME is required"
!endif
!ifndef FILELIST
  !error "FILELIST is required"
!endif

Name "KeepMyMacAwake · Windows 开发预览"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\KeepMyMacAwake"
RequestExecutionLevel user
SetCompressor /SOLID lzma
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "让已经启动的长任务继续运行。\r\n\r\n此开发预览仅支持接电、开盖，未开放合盖或电池保活，没有应用热保护。\r\n\r\n只为当前用户安装，无需管理员权限；不安装系统服务，不修改合盖设置。"
!define MUI_FINISHPAGE_RUN "$INSTDIR\KeepMyMacAwake.Windows.exe"
!define MUI_FINISHPAGE_RUN_TEXT "打开 KeepMyMacAwake（保持待机）"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "../../LICENSE"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"

Function .onInit
  SetShellVarContext current
  ${IfNot} ${AtLeastWin11}
    MessageBox MB_ICONSTOP "此开发预览需要 Windows 11。"
    Abort
  ${EndIf}
!if "${RUNTIME}" == "win-arm64"
  ${IfNot} ${IsNativeARM64}
    MessageBox MB_ICONSTOP "此 ARM64 包需要 Windows on ARM。x64 电脑请下载 x64 包。"
    Abort
  ${EndIf}
!endif
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "此安装包需要 64 位 Windows。"
    Abort
  ${EndIf}
  ; Keep one installation and refuse architecture changes that would mix files.
  ReadRegStr $0 HKCU "Software\KeepMyMacAwake.Windows" "Runtime"
  ${If} $0 != ""
  ${AndIf} $0 != "${RUNTIME}"
    MessageBox MB_ICONSTOP "已安装另一架构。请先通过系统设置卸载，再安装此包。"
    Abort
  ${EndIf}
FunctionEnd

Section "安装"
  IfFileExists "$INSTDIR\KeepMyMacAwake.Windows.exe" 0 ready
    ClearErrors
    ExecWait '"$INSTDIR\KeepMyMacAwake.Windows.exe" --prepare-update' $0
    IfErrors failed
    ${If} $0 != 0
      failed:
      MessageBox MB_ICONSTOP "尚未确认旧应用已停止。请打开应用恢复并退出，然后重试安装。"
      Abort
    ${EndIf}
  ready:
  SetOutPath "$INSTDIR"
  File /r "${APPDIR}/*"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateDirectory "$SMPROGRAMS\KeepMyMacAwake"
  CreateShortcut "$SMPROGRAMS\KeepMyMacAwake\KeepMyMacAwake.lnk" "$INSTDIR\KeepMyMacAwake.Windows.exe"
  CreateShortcut "$SMPROGRAMS\KeepMyMacAwake\卸载.lnk" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\KeepMyMacAwake.Windows" "Runtime" "${RUNTIME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "DisplayName" "KeepMyMacAwake · Windows 开发预览"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "UninstallString" '$\"$INSTDIR\uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows" "NoRepair" 1
SectionEnd

Function un.onInit
  SetShellVarContext current
FunctionEnd

Section "Uninstall"
  IfFileExists "$INSTDIR\KeepMyMacAwake.Windows.exe" 0 stopped
    ClearErrors
    ExecWait '"$INSTDIR\KeepMyMacAwake.Windows.exe" --prepare-update' $0
    IfErrors failed
    ${If} $0 != 0
      failed:
      MessageBox MB_ICONSTOP "尚未确认保活已停止。请打开应用恢复并退出，然后重试卸载。"
      Abort
    ${EndIf}
  stopped:
  ; Remove only a startup entry belonging to this installation.
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "KeepMyMacAwake.Windows"
  ${If} $0 == '$\"$INSTDIR\KeepMyMacAwake.Windows.exe$\" --startup'
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "KeepMyMacAwake.Windows"
  ${EndIf}
  Delete "$SMPROGRAMS\KeepMyMacAwake\KeepMyMacAwake.lnk"
  Delete "$SMPROGRAMS\KeepMyMacAwake\卸载.lnk"
  RMDir "$SMPROGRAMS\KeepMyMacAwake"
  ; Only packaged files are removed. Never recursively delete user-created files.
  !include "${FILELIST}"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\KeepMyMacAwake.Windows"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows"
SectionEnd
