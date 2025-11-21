; ============================================================================
; Lab Station Panel Launcher
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

; Embed logo for compiled builds so the GUI can find it.
TryExtractLogo() {
    if (!A_IsCompiled)
        return
    target := A_ScriptDir "\DecentraLabs.png"
    if (FileExist(target))
        return
    try {
        ; Copies the embedded PNG next to the EXE.
        FileInstall "img\DecentraLabs.png", target, true
    }
}

TryLaunch() {
    exePath := A_ScriptDir "\LabStation.exe"
    scriptPath := A_ScriptDir "\labstation\LabStation.ahk"

    ; Ensure the logo is available for the GUI
    TryExtractLogo()

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
