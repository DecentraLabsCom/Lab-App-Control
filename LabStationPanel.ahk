; ============================================================================
; Lab Station Panel Launcher
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

TryLaunch() {
    exePath := A_ScriptDir "\LabStation.exe"
    scriptPath := A_ScriptDir "\labstation\LabStation.ahk"

    ; Prefer compiled LabStation next to this launcher
    if (FileExist(exePath)) {
        Run Format('"{1}" gui', exePath)
        ExitApp
    }

    ; Fallback to source script if running from repo
    if (FileExist(scriptPath)) {
        Run Format('"{1}" "{2}" gui', A_AhkPath, scriptPath)
        ExitApp
    }

    MsgBox "LabStation executable or script was not found. Expected at:`n" exePath "`nor`n" scriptPath, "Lab Station Panel", "OK Iconx"
}

TryLaunch()
