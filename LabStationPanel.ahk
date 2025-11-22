; ============================================================================
; Lab Station Panel Launcher
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn Unreachable, Off  ; Disable warning for intentional unreachable code in compiled version

;@Ahk2Exe-SetMainIcon img\favicon.ico

; Embed logo for compiled builds so the GUI can find it.
TryExtractLogo() {
    if (!A_IsCompiled)
        return
    targetDir := A_ScriptDir "\img"
    target := targetDir "\DecentraLabs.png"
    try DirCreate(targetDir)
    if (FileExist(target))
        return
    ; Note: FileInstall disabled - logo distributed separately in img/ folder
    ; The GUI will find it at runtime via the distributed img/DecentraLabs.png
    ; try {
    ;     FileInstall "img\DecentraLabs.png", target, true
    ; }
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

;@Ahk2Exe-IgnoreBegin
; This code only exists in the .ahk script, not in compiled .exe
TryLaunch()
return  ; End of auto-execute section for .ahk
;@Ahk2Exe-IgnoreEnd

; This code only exists in the compiled .exe
TryLaunch()
