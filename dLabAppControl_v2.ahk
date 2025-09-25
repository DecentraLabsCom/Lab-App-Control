#SingleInstance Force
; #Requires AutoHotkey v2.0
; ProcessSetPriority "High"

if (A_Args.Length < 2) {
    MsgBox "Use: ControlApp.ahk [window_ahk_class] [C:\path\to\app.exe] [optional: close_control_ClassNN or X Y coordinates]"
    . "`n`nExamples:"
    . "`n- ControlApp.ahk `"Notepad`" `"notepad.exe`""
    . "`n- ControlApp.ahk `"LVDChild`" `"myVI.exe`" 330 484"
    . "`n- ControlApp.ahk `"MyAppClass`" `"C:\myapp.exe`" `"Button2`""
    . "`n`nCoordinate Guidelines (use WindowSpy):"
    . "`n- Use CLIENT coordinates (not Screen or Window)"
    . "`n- Example: Client 330,484 means 330 pixels right, 484 down from client area"
    . "`n- CLIENT coordinates should be most reliable for LabVIEW/custom apps"
    . "`n`nTEST MODE: Set TEST_MODE=true in script to test coordinates after 5s"
    ExitApp
}

windowClass := A_Args[1]
appPath     := A_Args[2]
customCloseControl := (A_Args.Length == 3) ? A_Args[3] : ""
customCloseX := (A_Args.Length == 4) ? Integer(A_Args[3]) : 0
customCloseY := (A_Args.Length == 4) ? Integer(A_Args[4]) : 0

; Configuration constants
POLL_INTERVAL_MS := 2000  ; Monitoring interval in milliseconds
STARTUP_TIMEOUT  := 6     ; Startup timeout in seconds
VERBOSE_LOGGING  := true  ; Set to true for detailed polling logs, false for events only
TEST_MODE        := false ; Set to true to test custom close method after 5s (for debugging coordinates/control)

; Custom graceful close button configuration (works with any desktop application)
; Determine method based on parameters provided
if (customCloseControl != "") {
    ; 3rd parameter provided - use control method
    CUSTOM_CLOSE_METHOD := "control"
    Log("Using custom close control from parameter: " . customCloseControl)
} else if (A_Args.Length == 4 && customCloseX > 0 && customCloseY > 0) {
    ; 3rd and 4th parameters provided - use coordinates method
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

; --- Monitoring RDP events (24/40 by default) ---
CloseOnEventIds := [23, 24, 40]   ; Adjust here if needed (e.g., remove 23 for no logoff, add 25 for reconnect)
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
    WinActivate(target)
    Sleep(200)  ; Ensure window is active
    
    ; Use configured method for graceful close
    switch CUSTOM_CLOSE_METHOD {
        case "control":
            try {
                Log("Attempting control click in disconnected session")
                WinActivate(target)
                Sleep(300)
                
                ControlClick(customCloseControl, target)
                Log("Clicked custom close button via control: " . customCloseControl)
                
                ; Verify click worked, try alternative method if not
                Sleep(1000)
                if WinExist(target) {
                    Log("Control click may not have worked - trying PostMessage")
                    ControlSend("{Enter}", customCloseControl, target)  ; Alternative approach
                }
                
                if WinWaitClose(target, , timeoutSec) {
                    return true
                }
            }
        
        case "coordinates":
            try {                
                if (TEST_MODE) {
                    Log("TEST MODE ENABLED - Input coordinates: " . customCloseX . "," . customCloseY)
                }

                ; Ensure session is unlocked and window is accessible
                Log("Preparing for click in disconnected session - activating window")
                
                ; Force window to foreground (works even in disconnected sessions)
                WinActivate(target)
                WinRestore(target)  ; In case it's minimized
                Sleep(500)  ; Give time for window to become active
                
                ; Try to unlock screen if locked (common in disconnected RDP)
                DllCall("user32.dll\SystemParametersInfo", "UInt", 0x0014, "UInt", 0, "Ptr", 0, "UInt", 0) ; SPI_SETSCREENSAVEACTIVE
                
                Log("Clicking at coordinates: " . customCloseX . "," . customCloseY)
                Click(customCloseX, customCloseY)
                
                ; Additional verification click if first didn't work
                Sleep(1000)
                if WinExist(target) {
                    Log("First click may not have worked - trying again")
                    Click(customCloseX, customCloseY)
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

; Graceful → forced: App Stop → WinClose → SC_CLOSE → Alt+F4 → kill
ForceCloseWindow(target, graceSec := 3) {
    ; 0) Try custom graceful close first (only if method is configured)
    if WinExist(target) && (CUSTOM_CLOSE_METHOD != "none") {
        if TryCustomGracefulClose(target, graceSec) {
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