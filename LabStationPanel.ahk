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
        LS_LaunchElevated(exePath, "gui")
        ExitApp
    }

    ; Fallback to source script if running from repo
    if (FileExist(scriptPath)) {
        args := Format('"{1}" gui', scriptPath)
        LS_LaunchElevated(A_AhkPath, args)
        ExitApp
    }

    MsgBox "LabStation executable or script was not found. Expected at:`n" exePath "`nor`n" scriptPath, "Lab Station Panel", "OK Iconx"
}

LS_LaunchElevated(target, args := "") {
    try {
        if (A_IsAdmin) {
            Run Format('"{1}" {2}', target, args)
            return
        }
        shell := ComObject("Shell.Application")
        shell.ShellExecute(target, args, A_WorkingDir, "runas", 1)
    } catch as e {
        MsgBox "Unable to launch Lab Station with elevation: " . e.Message, "Lab Station Panel", "OK Iconx"
    }
}

TryLaunch()
