; ============================================================================
; RdpMonitoring.ahk - RDP Event Monitoring
; ============================================================================
; Functions for monitoring RDP session events and triggering application closure
; ============================================================================

; Returns [EventRecordID, EventID] of the latest RDP events
GetLatestRdpEventRecord(ids := [23, 24, 39, 40]) {
    static wevtutilErrorLogged := false
    
    eventLog := "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
    tmp := A_Temp "\rdp_event.xml"
    cond := ""
    for id in ids
        cond .= (cond ? " or " : "") . "EventID=" . id
    xpath := "*[System[(" . cond . ")]]"

    ; Try to find wevtutil.exe
    wevt := ""
    if FileExist(A_WinDir "\System32\wevtutil.exe")
        wevt := A_WinDir "\System32\wevtutil.exe"
    if (!wevt && FileExist(A_WinDir "\Sysnative\wevtutil.exe"))
        wevt := A_WinDir "\Sysnative\wevtutil.exe"
    if (!wevt)
        wevt := "wevtutil.exe"

    fullCmd := Format('"{1}" qe "{2}" /q:"{3}" /c:1 /f:xml /rd:true > "{4}"'
                    , wevt, eventLog, xpath, tmp)
    
    try {
        exitCode := RunWait(Format('"{1}" /C {2}', A_ComSpec, fullCmd), , "Hide")
        if (exitCode != 0) {
            if (!wevtutilErrorLogged) {
                Log("wevtutil failed (ExitCode=" . exitCode . ") - This is normal if WTS notifications work.")
                wevtutilErrorLogged := true
            }
            return [0, 0]
        }
    } catch as e {
        if (!wevtutilErrorLogged) {
            errMsg := (Type(e) = "Error") ? e.message : String(e)
            Log("wevtutil execution failed: " . errMsg . " - This is normal if WTS notifications work.")
            wevtutilErrorLogged := true
        }
        return [0, 0]
    }

    try {
        xml := FileRead(tmp, "UTF-8")
        FileDelete(tmp)
    } catch {
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

; Check for new RDP session events (fallback polling)
CheckSessionEvents(*) {
    global lastId, CloseOnEventIds, target, containerHwnd, VERBOSE_LOGGING, DUAL_APP_MODE

    rec := GetLatestRdpEventRecord(CloseOnEventIds)
    current := rec[1], evId := rec[2]
    
    if (VERBOSE_LOGGING) {
        modeStr := DUAL_APP_MODE ? " (Container)" : ""
        Log("Event check" . modeStr . " - Current RecordId: " . current . ", Last RecordId: " . lastId . ", EventId: " . evId)
    }

    if (current > 0 && current != lastId && evId > 0) {
        lastId := current
        
        if (DUAL_APP_MODE) {
            Log("NEW EVENT DETECTED (Container)! Closing due to event ID: " . evId)
            containerTarget := "ahk_id " . containerHwnd
            Log("Closing container: " . containerTarget . " (containerHwnd=" . containerHwnd . ")")
            ForceCloseWindow(containerTarget)
        } else {
            Log("NEW EVENT DETECTED! Closing due to event ID: " . evId . " (RecordId " . current . ")")
            ForceCloseWindow(target)
        }
        ExitApp
    }
}

; Session change handler (WM_WTSSESSION_CHANGE)
OnSessionChange(wParam, lParam, msg, hwnd) {
    static WTS_SESSION_CONSOLE_CONNECT := 0x1
    static WTS_SESSION_REMOTE_CONNECT  := 0x3
    static WTS_SESSION_REMOTE_DISCONNECT := 0x4
    static WTS_SESSION_DISCONNECT := 0x5
    static WTS_SESSION_LOGOFF := 0x6
    static WTS_SESSION_LOCK := 0x7
    static WTS_SESSION_UNLOCK := 0x8

    global target, DUAL_APP_MODE

    if (wParam = WTS_SESSION_DISCONNECT
     || wParam = WTS_SESSION_REMOTE_DISCONNECT
     || wParam = WTS_SESSION_LOGOFF
     || wParam = WTS_SESSION_LOCK) 
    {
        if (DUAL_APP_MODE) {
            Log("WM_WTSSESSION_CHANGE (Container): early close on wParam=" . wParam)
            containerTarget := "ahk_id " . hwnd
            Log("Closing container: " . containerTarget . " (hwnd=" . hwnd . ")")
            ForceCloseWindow(containerTarget)
        } else {
            Log("WM_WTSSESSION_CHANGE: early close on wParam=" . wParam . " (pre-disconnect)")
            ForceCloseWindow(target)
        }
        ExitApp
    }
}

; Query end session handler (WM_QUERYENDSESSION - logoff/shutdown)
OnQueryEndSession(wParam, lParam, msg, hwnd) {
    global target, DUAL_APP_MODE
    
    if (DUAL_APP_MODE) {
        Log("WM_QUERYENDSESSION (Container): attempting early close", "DEBUG")
        containerTarget := "ahk_id " . hwnd
        Log("Closing container: " . containerTarget . " (hwnd=" . hwnd . ")")
        ForceCloseWindow(containerTarget)
    } else {
        Log("WM_QUERYENDSESSION received: attempting early close", "DEBUG")
        ForceCloseWindow(target)
    }
    ExitApp
}

; Setup RDP event monitoring (used by both modes)
SetupRdpMonitoring(hwnd) {
    global POLL_INTERVAL_MS, lastId, WTS_NOTIFICATIONS_ACTIVE
    
    ; Register for session notifications
    if DllCall("Wtsapi32\WTSRegisterSessionNotification", "ptr", hwnd, "uint", 0, "int") {
        global WTS_NOTIFICATIONS_ACTIVE
        WTS_NOTIFICATIONS_ACTIVE := true
        SetTimer(CheckSessionEvents, 0)  ; Disable any residual polling
        OnMessage(0x02B1, OnSessionChange)
        OnMessage(0x0011, OnQueryEndSession)
        OnExit((*) => (
            DllCall("Wtsapi32\WTSUnRegisterSessionNotification", "ptr", hwnd),
            OnMessage(0x02B1, OnSessionChange, 0),
            OnMessage(0x0011, OnQueryEndSession, 0)
        ))
        Log("Registered for WM_WTSSESSION_CHANGE / WM_QUERYENDSESSION notifications - polling disabled", "DEBUG")
    } else {
        global WTS_NOTIFICATIONS_ACTIVE
        WTS_NOTIFICATIONS_ACTIVE := false
        Log("WARNING: Could not register for session notifications - falling back to polling", "WARNING")
        
        ; Initialize polling as fallback
        lastId := 0
        SetTimer(CheckSessionEvents, POLL_INTERVAL_MS)
    }
}
