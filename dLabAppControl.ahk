#SingleInstance Force
; #Requires AutoHotkey v2.0
; ProcessSetPriority "High"

if (A_Args.Length < 2) {
    MsgBox "Use: ControlApp.ahk [window_ahk_class] [C:\path\to\app.exe] [optional: close_control_ClassNN or X Y coordinates] [optional: test]"
    . "`n`nExamples:"
    . "`n- ControlApp.ahk `"Notepad`" `"notepad.exe`""
    . "`n- ControlApp.ahk `"LVDChild`" `"myVI.exe`" 330 484"
    . "`n- ControlApp.ahk `"MyAppClass`" `"C:\myapp.exe`" `"ButtonClass`""
    . "`n- ControlApp.ahk `"LVDChild`" `"myVI.exe`" 330 484 test"
    . "`n`nCoordinate Guidelines (use WindowSpy):"
    . "`n- Use CLIENT coordinates (not Screen or Window)"
    . "`n- Example: Client 330,484 means 330 pixels right, 484 down from client area"
    . "`n- CLIENT coordinates should be most reliable for LabVIEW/custom apps"
    . "`n`nTEST MODE: Add 'test' as last parameter to test graceful close after 5s"
    ExitApp
}

windowClass := A_Args[1]
appPath     := A_Args[2]

; Check if last argument is "test" for TEST_MODE
lastArg := (A_Args.Length > 0) ? StrLower(A_Args[A_Args.Length]) : ""
TEST_MODE := (lastArg = "test")
Log("Command line args: " . A_Args.Length . " | Last arg: '" . lastArg . "' | TEST_MODE: " . TEST_MODE)

; Determine custom close parameters (adjust for TEST_MODE parameter)
if (TEST_MODE && A_Args.Length == 3) {
    ; 3rd parameter is "test" - no custom close method
    customCloseControl := ""
    customCloseX := 0
    customCloseY := 0
} else if (!TEST_MODE && A_Args.Length == 3) {
    ; 3rd parameter is control method
    customCloseControl := A_Args[3]
    customCloseX := 0
    customCloseY := 0
} else if (TEST_MODE && A_Args.Length == 5) {
    ; 3rd and 4th are coordinates, 5th is "test"
    customCloseControl := ""
    customCloseX := Integer(A_Args[3])
    customCloseY := Integer(A_Args[4])
} else if (!TEST_MODE && A_Args.Length == 4) {
    ; 3rd and 4th are coordinates, no test
    customCloseControl := ""
    customCloseX := Integer(A_Args[3])
    customCloseY := Integer(A_Args[4])
} else if (TEST_MODE && A_Args.Length == 4) {
    ; 3rd is control, 4th is "test"
    customCloseControl := A_Args[3]
    customCloseX := 0
    customCloseY := 0
} else {
    ; No custom close method specified
    customCloseControl := ""
    customCloseX := 0
    customCloseY := 0
}

; Configuration constants
POLL_INTERVAL_MS := 5000  ; Monitoring interval in milliseconds
STARTUP_TIMEOUT  := 6     ; Startup timeout in seconds
VERBOSE_LOGGING  := true  ; Set to true for detailed polling logs, false for events only

; Custom graceful close button configuration (works with any desktop application)
; Determine method based on parameters provided
if (customCloseControl != "") {
    ; Control method specified
    CUSTOM_CLOSE_METHOD := "control"
    Log("Using custom close control from parameter: " . customCloseControl)
} else if (customCloseX > 0 && customCloseY > 0) {
    ; Coordinates method specified
    CUSTOM_CLOSE_METHOD := "coordinates"
    Log("Using custom close coordinates from parameters: " . customCloseX . ", " . customCloseY)
} else {
    ; No custom close method specified
    CUSTOM_CLOSE_METHOD := "none"
    Log("No custom close method specified - will use standard cascade")
}

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
Log("Target window specification: " . target)
if !WinExist(target) {
    Log("Target window not found, attempting to launch application...")
    ; Validate that the application file exists before trying to run it
    if !FileExist(appPath) {
        Log("ERROR: Application file not found: " . appPath)
        MsgBox "Application file not found: " . appPath
        ExitApp
    }
    
    Log("Launching app: " . appPath)
    startTime := A_TickCount
    Run(appPath)
    Log("Waiting for window to appear (timeout: " . STARTUP_TIMEOUT . "s)...")
    if !WinWait(target, , STARTUP_TIMEOUT) {
        elapsedTime := (A_TickCount - startTime) / 1000
        Log("ERROR: Window did not appear within timeout (waited " . Format("{:.1f}", elapsedTime) . "s)")
        MsgBox "Couldn't open lab app at: " appPath
        ExitApp
    }
    elapsedTime := (A_TickCount - startTime) / 1000
    Log("Window appeared successfully after " . Format("{:.1f}", elapsedTime) . "s")
} else {
    Log("Target window already exists, activating it")
}

; Ensure foreground and maximized
WinActivate(target)
WinMaximize(target)

; Remove minimize and close buttons (but keep title bar)
WinSetStyle("-0x20000", target) ; WS_MINIMIZEBOX
WinSetStyle("-0x80000", target) ; WS_SYSMENU (removes close button and system menu)

; Block Alt+F4 on the lab window
#HotIf WinActive(target)
!F4::return
#HotIf

; --- Session-change notifications (early trigger before UI dies) ---
; 0 = NOTIFY_FOR_THIS_SESSION
if DllCall("Wtsapi32\WTSRegisterSessionNotification", "ptr", A_ScriptHwnd, "uint", 0, "int")
{
    OnMessage(0x02B1, OnSessionChange)  ; WM_WTSSESSION_CHANGE
    ; Backup: also listen for WM_QUERYENDSESSION (logoff/shutdown)
    OnMessage(0x0011, OnQueryEndSession) ; WM_QUERYENDSESSION
    OnExit( (*) => (
        DllCall("Wtsapi32\WTSUnRegisterSessionNotification", "ptr", A_ScriptHwnd),
        OnMessage(0x02B1, OnSessionChange, 0),
        OnMessage(0x0011, OnQueryEndSession, 0)
    ))
    Log("Registered for WM_WTSSESSION_CHANGE / WM_QUERYENDSESSION notifications")
}
else {
    Log("WARNING: Could not register for session notifications")
}

; --- Monitoring RDP events ---
CloseOnEventIds := [23, 24, 39, 40]
last := GetLatestRdpEventRecord(CloseOnEventIds) ; [RecordId, EventId]
lastId := last[1]

SetTimer(CheckSessionEvents, POLL_INTERVAL_MS)

; TEST MODE: Simulate custom close after 5 seconds (for coordinate testing)
if (TEST_MODE && CUSTOM_CLOSE_METHOD != "none") {
    Log("TEST MODE ENABLED - Will test custom close in 5 seconds...")
    SetTimer(TestCustomClose, 5000, -1)  ; Run once after 5 seconds
}

return  ; End of auto-execute section


; ------------ FUNCTIONS ------------

; TEST FUNCTION: Test custom close coordinates/control
TestCustomClose() {
    global target, CUSTOM_CLOSE_METHOD
    
    Log("TEST MODE: Testing custom close method: " . CUSTOM_CLOSE_METHOD)
    
    if !WinExist(target) {
        Log("TEST MODE: Target window no longer exists - cannot test")
        return
    }
    
    ; Try the custom close method
    if TryCustomGracefulClose(target, 3) {
        Log("TEST MODE: ✅ Custom close SUCCESSFUL - coordinates/control work correctly!")
        ExitApp  ; Exit after successful test
    } else {
        Log("TEST MODE: ❌ Custom close FAILED - check coordinates/control name")
        ; Don't exit, let user see the result
    }
}

; Universal graceful close for any desktop application with custom close buttons
TryCustomGracefulClose(target, timeoutSec := 3) {
    global CUSTOM_CLOSE_METHOD, customCloseControl, customCloseX, customCloseY

    if !WinExist(target) {
        return false
    }
    
    Log("Attempting custom graceful close using method: " . CUSTOM_CLOSE_METHOD)
    
    ; Use configured method for graceful close
    switch CUSTOM_CLOSE_METHOD {
        case "control":
            try {
                Log("Attempting control click in (pre)disconnected session")

                
                ControlClick(customCloseControl, target)
                Log("Clicked custom close button via control: " . customCloseControl)
                
                ; Verify click worked, try alternative method if not
                Sleep(500)
                if WinExist(target) {
                    Log("Control click may not have worked - trying ControlSend {Enter}")
                    ControlSend("{Enter}", customCloseControl, target)
                }
                
                if WinWaitClose(target, , timeoutSec) {
                    return true
                }
            }
        
        case "coordinates":
            try {                
                ; Ensure session is unlocked and window is accessible
                Log("Attempting X,Y click in (pre)disconnected session")
                WinActivate(target)
                Sleep(300)

                Click(customCloseX, customCloseY)
                Log("Clicked at coordinates: " . customCloseX . "," . customCloseY)
                
                ; Verify click worked, try alternative method if not
                if WinExist(target) {
                    Log("First click may not have worked - trying PostMessage click")
                    PostMessage(0x0201, 0, (customCloseY << 16) | customCloseX, , target) ; WM_LBUTTONDOWN
                    PostMessage(0x0202, 0, (customCloseY << 16) | customCloseX, , target) ; WM_LBUTTONUP
                }
                
                if WinWaitClose(target, , timeoutSec) {
                    return true
                }
            }
    }
    
    Log("Custom graceful close failed, will use standard closing methods")
    return false
}

; Logging function for auditing and support
Log(msg) {
    ; Save log in the same directory as the script for easy access
    logFile := A_ScriptDir "\dLabAppControl.log"
    timestamp := FormatTime("yyyy-MM-dd HH:mm:ss", A_Now)
    logEntry := timestamp . " - " . msg . "`n"
    
    FileAppend(logEntry, logFile, "UTF-8")
    
    OutputDebug(timestamp . " - dLabAppControl: " . msg)
}

; Returns [EventRecordID, EventID] of the latest events
; Receives the list of IDs and builds the XPath dynamically
GetLatestRdpEventRecord(ids := [23, 24, 39, 40]) {
    log := "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
    tmp := A_Temp "\rdp_event.xml"
    cond := ""
    for id in ids
        cond .= (cond ? " or " : "") . "EventID=" . id
    xpath := "*[System[(" . cond . ")]]"

    ; If the process AHK is 32-bit on 64-bit OS, use Sysnative to bypass redirection to SysWOW64
    wevt := (A_PtrSize = 8) ? (A_WinDir "\System32\wevtutil.exe")
                            : (A_WinDir "\Sysnative\wevtutil.exe")
    if !FileExist(wevt)  ; Fallback in case running in 32-bit/32-bit
        wevt := "wevtutil.exe"

    ; Command with properly quoted arguments and redirection handled by cmd
    fullCmd := Format('"{1}" qe "{2}" /q:"{3}" /c:1 /f:xml /rd:true > "{4}"'
                    , wevt, log, xpath, tmp)
    exitCode := RunWait(Format('"{1}" /C {2}', A_ComSpec, fullCmd), , "Hide")

    if (exitCode != 0) {
        Log("wevtutil failed. ExitCode=" . exitCode . " | Cmd=" . fullCmd)
        return [0, 0]
    }

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

; Check for new RDP session events (fallback/back-up)
CheckSessionEvents(*) {
    global lastId, CloseOnEventIds, target, VERBOSE_LOGGING

    rec := GetLatestRdpEventRecord(CloseOnEventIds) ; [RecordId, EventId]
    current := rec[1], evId := rec[2]
    
    ; Only log polling details if verbose logging is enabled
    if (VERBOSE_LOGGING) {
        Log("Event check - Current RecordId: " . current . ", Last RecordId: " . lastId . ", EventId: " . evId)
    }

    ; New relevant event -> close the app and exit
    ; If we got a valid event (current > 0) and it's different from last one,
    ; it means it's already one of our target events (filtered by GetLatestRdpEventRecord)
    if (current > 0 && current != lastId && evId > 0) {
        lastId := current
        Log("NEW EVENT DETECTED! Closing due to event ID: " . evId . " (RecordId " . current . ")")
        ForceCloseWindow(target, 3) ; wait ~3s after each attempt before escalating
        ExitApp
    }
}

; Graceful → forced: App Stop → WinClose → SC_CLOSE → WM_CLOSE → kill
ForceCloseWindow(target, graceSec := 3) {
    global CUSTOM_CLOSE_METHOD
    ; 0) Try custom graceful close first (only if method is configured)
    if WinExist(target) && (CUSTOM_CLOSE_METHOD != "none") {
        if TryCustomGracefulClose(target, graceSec) {
            Log("Custom graceful close succeeded")
            return true  ; Successfully closed via custom method
        }
    }
    
    ; 1) Gentle close
    if WinExist(target) {
        WinClose(target)
        if WinWaitClose(target, , graceSec)
            return true
    }
    ; 2) System command message (WM_SYSCOMMAND / SC_CLOSE)
    if WinExist(target) {
        PostMessage(0x0112, 0xF060, 0, , target)  ; WM_SYSCOMMAND with SC_CLOSE
        if WinWaitClose(target, , graceSec)
            return true
    }
    ; 3) Direct close message (WM_CLOSE)
    if WinExist(target) {
        PostMessage(0x0010, 0, 0, , target)  ; WM_CLOSE
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

; --- Early session-change handler (pre-disconnect) ---
OnSessionChange(wParam, lParam, msg, hwnd) {
    static WTS_SESSION_CONSOLE_CONNECT := 0x1
    static WTS_SESSION_REMOTE_CONNECT  := 0x3
    static WTS_SESSION_REMOTE_DISCONNECT := 0x4
    static WTS_SESSION_DISCONNECT := 0x5
    static WTS_SESSION_LOGOFF := 0x6
    static WTS_SESSION_LOCK := 0x7
    static WTS_SESSION_UNLOCK := 0x8

    global target

    if (wParam = WTS_SESSION_DISCONNECT
     || wParam = WTS_SESSION_REMOTE_DISCONNECT
     || wParam = WTS_SESSION_LOGOFF
     || wParam = WTS_SESSION_LOCK) 
    {
        Log("WM_WTSSESSION_CHANGE: early close on wParam=" . wParam . " (pre-disconnect)")
        ForceCloseWindow(target, 2)
        ExitApp
    }
}

; --- Backup for logoff/shutdown (not for simple disconnect) ---
OnQueryEndSession(wParam, lParam, msg, hwnd) {
    global target
    Log("WM_QUERYENDSESSION received: attempting early close")
    ForceCloseWindow(target, 2)
    ExitApp
}