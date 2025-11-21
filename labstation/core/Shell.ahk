; ============================================================================
; Lab Station - Shell helpers
; ============================================================================
#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Logger.ahk

LS_RunPowerShell(script, description := "PowerShell command") {
    tempScript := A_Temp "\LabStation-" . A_TickCount . ".ps1"
    try {
        FileDelete(tempScript)
    } catch {
    }
    try {
        FileAppend(script, tempScript, "UTF-8")
    } catch as e {
        LS_LogError("Cannot write temporary PowerShell script: " . e.Message)
        return -1
    }

    command := Format('powershell -NoProfile -ExecutionPolicy Bypass -File "{1}"', tempScript)
    LS_LogInfo("Executing PowerShell - " . description)
    exitCode := RunWait(command, , "Hide")
    try FileDelete(tempScript)
    return exitCode
}

LS_RunCommand(command, description := "command") {
    LS_LogInfo("Executing command - " . description)
    return RunWait(command, , "Hide")
}
