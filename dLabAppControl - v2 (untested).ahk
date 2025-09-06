#SingleInstance Force
; #Requires AutoHotkey v2.0
; ProcessSetPriority "High"

if (A_Args.Length < 2) {
    MsgBox "Use: ControlApp.ahk [window ahk_class] [C:\path\to\app.exe]"
    ExitApp
}

windowClass := A_Args[1]
appPath     := A_Args[2]

; Configuration constants
POLL_INTERVAL_MS := 5000  ; Monitoring interval in milliseconds
STARTUP_TIMEOUT  := 6     ; Startup timeout in seconds

; Precise window identification - handle both executables and scripts
SplitPath(appPath, &exeName, , &ext)
if (StrLower(ext) = "exe") {
    target := "ahk_class " . windowClass . " ahk_exe " . exeName
} else {
    ; For non-exe files (scripts, batch, etc.), use only class name
    ; as the actual process name might be different (cmd.exe, java.exe, etc.)
    target := "ahk_class " . windowClass
}

; --- App launch/activation ---
if !WinExist(target) {
    ; Validate that the application file exists before trying to run it
    if !FileExist(appPath) {
        Log("ERROR: Application file not found: " . appPath)
        MsgBox "Application file not found: " . appPath
        ExitApp
    }
    
    Log("Launching app: " . appPath)
    Run(appPath)
    if !WinWait(target, , STARTUP_TIMEOUT) {
        MsgBox "Couldn't open lab app at: " appPath
        ExitApp
    }
}

; Ensure foreground and maximized
WinActivate(target)
WinMaximize(target)

; Remove minimize and close (keep title bar)
WinSetStyle("-0x20000", target) ; WS_MINIMIZEBOX
WinSetStyle("-0x80000", target) ; WS_SYSMENU (removes close button and system menu)

; Block Alt+F4 on the lab window
#HotIf WinActive(target)
!F4::return
#HotIf

; --- Monitoring RDP events (24/40 by default) ---
CloseOnEventIds := [24, 40]   ; Adjust here (e.g., add 23 for logoff, 25 for reconnect)
last := GetLatestRdpEventRecord(CloseOnEventIds) ; [RecordId, EventId]
lastId := last[1]

SetTimer(CheckSessionEvents, POLL_INTERVAL_MS)
return  ; End of auto-execute section

; ------------ FUNCTIONS ------------

; Logging function for auditing and support
Log(msg) {
    FileAppend(
        FormatTime("yyyy-MM-dd HH:mm:ss", A_Now) . " - " . msg . "`n",
        A_Temp "\dLabAppControl.log",
        "UTF-8"
    )
}

; Returns [EventRecordID, EventID] of the latest events
; Receives the list of IDs and builds the XPath dynamically
GetLatestRdpEventRecord(ids := [24, 40]) {
    log := "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
    tmp := A_Temp "\rdp_event.xml"
    cond := ""
    for id in ids
        cond .= (cond ? " or " : "") . "EventID=" . id
    xpath := "*[System[(" . cond . ")]]"
    cmd := 'wevtutil qe "' . log . '" /q:"' . xpath . '" /c:1 /f:xml /rd:true > "' . tmp . '"'
    RunWait(A_ComSpec . ' /C ' . cmd, , "Hide")

    try {
        xml := FileRead(tmp, "UTF-8")
        ; Clean up temporary file after reading
        FileDelete(tmp)
    } catch {
        ; Clean up temporary file even if reading failed
        try FileDelete(tmp)
        return [0, 0]
    }

    recId := 0, evId := 0
    if RegExMatch(xml, "<EventRecordID>(\d+)</EventRecordID>", &m1)
        recId := Integer(m1[1])
    if RegExMatch(xml, "<EventID>(\d+)</EventID>", &m2)
        evId := Integer(m2[1])
    return [recId, evId]
}

; Check for new RDP session events
CheckSessionEvents(*) {
    global lastId, CloseOnEventIds, target

    rec := GetLatestRdpEventRecord(CloseOnEventIds) ; [RecordId, EventId]
    current := rec[1], evId := rec[2]

    ; New relevant event -> close the app and exit
    if (current > 0 && current != lastId && CloseOnEventIds.IndexOf(evId)) {
        lastId := current
        Log("Closing due to event ID: " . evId . " (RecordId " . current . ")")
        ForceCloseWindow(target, 3) ; wait ~3s after each attempt before escalating
        ExitApp
    }
}

; Graceful → forced: WinClose → SC_CLOSE → Alt+F4 → kill
ForceCloseWindow(target, graceSec := 3) {
    ; 1) Gentle close
    if WinExist(target) {
        WinClose(target)
        if WinWaitClose(target, , graceSec)
            return true
    }
    ; 2) System message (WM_SYSCOMMAND / SC_CLOSE)
    if WinExist(target) {
        PostMessage(0x0112, 0xF060, 0, , target)  ; SC_CLOSE
        if WinWaitClose(target, , graceSec)
            return true
    }
    ; 3) Simulate Alt+F4
    if WinExist(target) {
        WinActivate(target)
        Sleep(100)
        Send("!{F4}")
        if WinWaitClose(target, , graceSec)
            return true
    }
    ; 4) Kill process (hard)
    if WinExist(target) {
        pid := WinGetPID(target)
        try {
            ProcessClose(pid)
            ProcessWaitClose(pid, 3)  ; Wait explicitly for process to die
        } catch {
            RunWait(A_ComSpec . ' /C taskkill /PID ' . pid . ' /T /F', , 'Hide')
            try ProcessWaitClose(pid, 3)
        }
        return !WinExist(target)
    }
    return true
}