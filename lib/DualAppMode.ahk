; ============================================================================
; DualAppMode.ahk - Dual Application Container Mode
; ============================================================================
; Functions for managing two applications in a tabbed container with RDP handling
; ============================================================================

; Robust positioning for UWP applications (with retries)
PositionUWPApp(hwnd, x, y, width, height, maxRetries := 5) {
    Loop maxRetries {
        ; Try SetWindowPos first
        result := DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0,
            "Int", x, "Int", y, "Int", width, "Int", height, "UInt", 0x0014)
        
        Sleep(50)
        
        ; Verify the window actually moved/resized
        try {
            WinGetPos(&actualX, &actualY, &actualW, &actualH, "ahk_id " . hwnd)
            
            ; Allow small tolerance (±10 pixels)
            xOk := Abs(actualX - x) <= 10
            yOk := Abs(actualY - y) <= 10
            wOk := Abs(actualW - width) <= 10
            hOk := Abs(actualH - height) <= 10
            
            if (xOk && yOk && wOk && hOk) {
                Log("UWP app positioned successfully on attempt " . A_Index, "DEBUG")
                ; Force redraw
                DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0085)
                return true
            }
            
            Log("UWP positioning attempt " . A_Index . " - Actual: " . actualX . "," . actualY . " " . actualW . "x" . actualH . " (Expected: " . x . "," . y . " " . width . "x" . height . ")", "DEBUG")
        }
        
        ; If SetWindowPos didn't work, try WinMove as fallback
        if (A_Index >= 3) {
            try {
                WinMove(x, y, width, height, "ahk_id " . hwnd)
                Sleep(50)
            }
        }
        
        Sleep(100 * A_Index)  ; Increasing delay between retries
    }
    
    Log("WARNING: Failed to position UWP app after " . maxRetries . " attempts", "WARNING")
    return false
}

CreateDualAppContainer(class1, path1, class2, path2, tab1Title := "Application 1", tab2Title := "Application 2") {
    global STARTUP_TIMEOUT, POLL_INTERVAL_MS
    
    Log("Initializing dual app container mode", "INFO")
    Log("Tab titles: '" . tab1Title . "' and '" . tab2Title . "'", "DEBUG")
    
    ; Validate that application files exist
    if !FileExist(path1) {
        Log("ERROR: Application 1 file not found: " . path1, "ERROR")
        MsgBox "Application 1 file not found: " . path1
        ExitApp
    }
    if !FileExist(path2) {
        Log("ERROR: Application 2 file not found: " . path2, "ERROR")
        MsgBox "Application 2 file not found: " . path2
        ExitApp
    }
    
    ; Create container GUI without title bar
    container := Gui("+Resize -Caption -DPIScale")
    container.SetFont("s10", "Segoe UI")
    
    ; Show container maximized FIRST to get real dimensions
    container.Show("Maximize")
    
    ; Get actual container size after maximizing
    container.GetPos(, , &cWidth, &cHeight)
    Log("Container maximized - Actual size: " . cWidth . "x" . cHeight, "DEBUG")
    
    ; Create a child GUI container for the apps (full screen behind tabs)
    appContainer := Gui("+Parent" . container.Hwnd . " -Caption -Border -DPIScale", "AppContainer")
    appContainer.BackColor := "000000"
    appContainer.Show("x0 y0 w" . cWidth . " h" . cHeight)
    
    Log("App container created - Full screen: " . cWidth . "x" . cHeight, "DEBUG")
    
    ; Launch applications FIRST to detect their window classes
    Log("Launching Application 1: " . path1, "DEBUG")
    try {
        Run(path1, , , &pid1)
    } catch as e {
        Log("ERROR: Failed to launch App 1: " . e.message, "ERROR")
        MsgBox "Failed to launch Application 1: " . path1 . "`n`nError: " . e.message
        ExitApp
    }
    
    ; Check if App 1 is a launcher (jar, bat, script) - may spawn different process
    SplitPath(path1, , , &ext1)
    isLauncher1 := (StrLower(ext1) != "exe")
    if (isLauncher1) {
        Log("App 1 is a launcher file (." . ext1 . ") - will use class-only detection", "DEBUG")
    }
    
    Log("Launching Application 2: " . path2, "DEBUG")
    try {
        Run(path2, , , &pid2)
    } catch as e {
        Log("ERROR: Failed to launch App 2: " . e.message, "ERROR")
        MsgBox "Failed to launch Application 2: " . path2 . "`n`nError: " . e.message
        ExitApp
    }
    
    ; Check if App 2 is a launcher (jar, bat, script) - may spawn different process
    SplitPath(path2, , , &ext2)
    isLauncher2 := (StrLower(ext2) != "exe")
    if (isLauncher2) {
        Log("App 2 is a launcher file (." . ext2 . ") - will use class-only detection", "DEBUG")
    }
    
    ; Wait for windows to appear using window classes
    Log("Waiting for Application 1 window (Class: " . class1 . ", PID: " . pid1 . ", Launcher: " . isLauncher1 . ")...", "DEBUG")
    
    waitStart := A_TickCount
    hwnd1 := 0
    Loop {
        if (!isLauncher1) {
            target1 := "ahk_class " . class1 . " ahk_pid " . pid1
            if WinExist(target1) {
                hwnd1 := WinGetID(target1)
                WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd1)
                title := WinGetTitle("ahk_id " . hwnd1)
                Log("Found App 1 by class+pid - Window " . hwnd1 . ": " . w . "x" . h . " - Title: '" . title . "'", "DEBUG")
                
                if (w > 100 && h > 100) {
                    Log("Selected App 1 window: " . hwnd1, "DEBUG")
                    break
                }
            }
        }
        
        if (hwnd1 == 0) {
            target1 := "ahk_class " . class1
            if WinExist(target1) {
                wins := WinGetList(target1)
                Log("Found " . wins.Length . " window(s) for class " . class1, "DEBUG")
                
                for hwnd in wins {
                    if WinExist("ahk_id " . hwnd) {
                        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
                        title := WinGetTitle("ahk_id " . hwnd)
                        Log("  Window " . hwnd . ": " . w . "x" . h . " - Title: '" . title . "'", "DEBUG")
                        
                        if (w > 100 && h > 100) {
                            hwnd1 := hwnd
                            Log("Selected App 1 window by class" . (isLauncher1 ? " (launcher mode)" : "") . ": " . hwnd1, "DEBUG")
                            break 2
                        }
                    }
                }
            }
        }
        
        if ((A_TickCount - waitStart) / 1000 > STARTUP_TIMEOUT) {
            Log("ERROR: Application 1 window did not appear within timeout", "ERROR")
            MsgBox "Application 1 window (class: " . class1 . ") did not appear within " . STARTUP_TIMEOUT . " seconds"
            ExitApp
        }
        
        Sleep(200)
    }
    
    Log("Waiting for Application 2 window (Class: " . class2 . ", PID: " . pid2 . ", Launcher: " . isLauncher2 . ")...", "DEBUG")
    
    waitStart := A_TickCount
    hwnd2 := 0
    Loop {
        if (!isLauncher2) {
            target2 := "ahk_class " . class2 . " ahk_pid " . pid2
            if WinExist(target2) {
                hwnd2 := WinGetID(target2)
                WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd2)
                title := WinGetTitle("ahk_id " . hwnd2)
                Log("Found App 2 by class+pid - Window " . hwnd2 . ": " . w . "x" . h . " - Title: '" . title . "'", "DEBUG")
                
                if (w > 100 && h > 100) {
                    Log("Selected App 2 window: " . hwnd2, "DEBUG")
                    break
                }
            }
        }
        
        if (hwnd2 == 0) {
            target2 := "ahk_class " . class2
            if WinExist(target2) {
                wins := WinGetList(target2)
                Log("Found " . wins.Length . " window(s) for class " . class2, "DEBUG")
                
                for hwnd in wins {
                    if WinExist("ahk_id " . hwnd) {
                        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
                        title := WinGetTitle("ahk_id " . hwnd)
                        Log("  Window " . hwnd . ": " . w . "x" . h . " - Title: '" . title . "'", "DEBUG")
                        
                        if (w > 100 && h > 100) {
                            hwnd2 := hwnd
                            Log("Selected App 2 window by class" . (isLauncher2 ? " (launcher mode)" : "") . ": " . hwnd2, "DEBUG")
                            break 2
                        }
                    }
                }
            }
        }
        
        if ((A_TickCount - waitStart) / 1000 > STARTUP_TIMEOUT) {
            Log("ERROR: Application 2 window did not appear within timeout", "ERROR")
            MsgBox "Application 2 window (class: " . class2 . ") did not appear within " . STARTUP_TIMEOUT . " seconds"
            ExitApp
        }
        
        Sleep(200)
    }
    
    Log("App 1 HWND: " . hwnd1 . ", App 2 HWND: " . hwnd2)
    
    ; Detect if apps are UWP applications
    app1IsUWP := IsUWPApp(hwnd1, class1)
    app2IsUWP := IsUWPApp(hwnd2, class2)
    
    Log("App 1 is UWP: " . (app1IsUWP ? "Yes" : "No") . ", App 2 is UWP: " . (app2IsUWP ? "Yes" : "No"), "DEBUG")
    
    ; Detect if apps use custom title bars (pass className to avoid WinGetClass call)
    app1HasCustomTitleBar := HasCustomTitleBar(hwnd1, class1)
    app2HasCustomTitleBar := HasCustomTitleBar(hwnd2, class2)
        
    ; Remove minimize, maximize and close buttons ONLY for apps with standard title bars
    if (!app1HasCustomTitleBar) {
        try {
            WinSetStyle("-0x20000", "ahk_id " . hwnd1) ; WS_MINIMIZEBOX
            WinSetStyle("-0x10000", "ahk_id " . hwnd1) ; WS_MAXIMIZEBOX
            WinSetStyle("-0x80000", "ahk_id " . hwnd1) ; WS_SYSMENU
            Log("App 1 window styles modified (standard titlebar - buttons removed)", "DEBUG")
        } catch as e {
            Log("WARNING: Could not modify App 1 window styles: " . e.message, "WARNING")
        }
    } else {
        Log("App 1 uses custom titlebar - skipping style modifications (SetParent will handle it)", "DEBUG")
    }
    
    if (!app2HasCustomTitleBar) {
        try {
            WinSetStyle("-0x20000", "ahk_id " . hwnd2) ; WS_MINIMIZEBOX
            WinSetStyle("-0x10000", "ahk_id " . hwnd2) ; WS_MAXIMIZEBOX
            WinSetStyle("-0x80000", "ahk_id " . hwnd2) ; WS_SYSMENU
            Log("App 2 window styles modified (standard titlebar - buttons removed)", "DEBUG")
        } catch as e {
            Log("WARNING: Could not modify App 2 window styles: " . e.message, "WARNING")
        }
    } else {
        Log("App 2 uses custom titlebar - skipping style modifications (SetParent will handle it)", "DEBUG")
    }
    
    ; Make apps children of container (skip for UWP apps - they don't support SetParent well)
    if (!app1IsUWP) {
        Log("Setting parent for Application 1", "DEBUG")
        DllCall("SetParent", "Ptr", hwnd1, "Ptr", appContainer.Hwnd)
    } else {
        Log("App 1 is UWP - skipping SetParent", "DEBUG")
    }
    
    if (!app2IsUWP) {
        Log("Setting parent for Application 2", "DEBUG")
        DllCall("SetParent", "Ptr", hwnd2, "Ptr", appContainer.Hwnd)
    } else {
        Log("App 2 is UWP - skipping SetParent", "DEBUG")
    }
    
    ; Calculate custom title bar heights
    titleBarHeight1 := app1HasCustomTitleBar ? GetCustomTitleBarHeight(class1) : 20
    titleBarHeight2 := app2HasCustomTitleBar ? GetCustomTitleBarHeight(class2) : 20
    
    ; Tab height should match the tallest custom titlebar
    tabHeight := Max(titleBarHeight1, titleBarHeight2)
    if (tabHeight < 35) {
        tabHeight := 35  ; Minimum tab height for usability
    }
    
    Log("Title bar heights - App1: " . titleBarHeight1 . "px, App2: " . titleBarHeight2 . "px, Tab height: " . tabHeight . "px", "DEBUG")
    
    ; Now create tab control with the calculated height
    container.SetFont("s11", "Segoe UI")
    tabs := container.AddTab3("x0 y0 w" . cWidth . " h" . tabHeight, [tab1Title, tab2Title])
    
    ; Apply tab control style (TCS_BUTTONS for flat modern look)
    try {
        tabHwnd := tabs.Hwnd
        currentStyle := DllCall("GetWindowLong", "Ptr", tabHwnd, "Int", -16, "Int")
        newStyle := currentStyle | 0x0100 | 0x0008  ; TCS_BUTTONS | TCS_FLATBUTTONS
        DllCall("SetWindowLong", "Ptr", tabHwnd, "Int", -16, "Int", newStyle)
        
        ; Set tab control to be always on top (within container)
        DllCall("SetWindowPos", "Ptr", tabHwnd, "Ptr", -1,  ; HWND_TOPMOST
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003)  ; SWP_NOMOVE | SWP_NOSIZE
        
        DllCall("InvalidateRect", "Ptr", tabHwnd, "Ptr", 0, "Int", 1)
        Log("Tab control created with height " . tabHeight . "px (floating overlay)", "DEBUG")
    } catch as e {
        Log("WARNING: Could not apply tab styling: " . e.message, "WARNING")
    }
    
    container.SetFont("s10 norm", "Segoe UI")
    
    ; Ensure app container is behind tabs
    DllCall("SetWindowPos", "Ptr", appContainer.Hwnd, "Ptr", 1,  ; HWND_BOTTOM
        "Int", 0, "Int", 0, "Int", cWidth, "Int", cHeight, "UInt", 0x0043)
    
    ; Position and size apps
    Log("Positioning applications in container", "DEBUG")
    Sleep(100)
    
    ; Get container screen position for UWP apps
    container.GetPos(&containerX, &containerY, , )
    Log("Container position for UWP: X=" . containerX . " Y=" . containerY, "DEBUG")
    
    ; Calculate position below tabs for UWP apps
    uwpY := containerY + tabHeight
    uwpHeight := cHeight - tabHeight
    
    ; Handle App 1 - Always show on start
    if (!app1IsUWP) {
        try WinMaximize("ahk_id " . hwnd1)
        DllCall("ShowWindow", "Ptr", hwnd1, "Int", 5)  ; SW_SHOW
    } else {
        ; UWP apps: Position manually below tabs with robust retry logic
        Log("Positioning UWP App 1 at screen coords - X:" . containerX . " Y:" . uwpY . " W:" . cWidth . " H:" . uwpHeight, "DEBUG")
        PositionUWPApp(hwnd1, containerX, uwpY, cWidth, uwpHeight)
        DllCall("ShowWindow", "Ptr", hwnd1, "Int", 5)  ; SW_SHOW
        Log("UWP App 1 shown at startup", "DEBUG")
    }
    
    ; Handle App 2 - Hide on start (will be shown when switching to tab 2)
    if (!app2IsUWP) {
        try WinMaximize("ahk_id " . hwnd2)
        DllCall("ShowWindow", "Ptr", hwnd2, "Int", 0)  ; SW_HIDE
    } else {
        ; UWP apps: Position first, then minimize AND move off-screen
        Log("Positioning UWP App 2 (will be hidden initially)", "DEBUG")
        PositionUWPApp(hwnd2, containerX, uwpY, cWidth, uwpHeight)
        Sleep(200)
        ; First minimize the window
        Log("Minimizing UWP App 2", "DEBUG")
        WinMinimize("ahk_id " . hwnd2)
        Sleep(200)
        ; Verify it's actually minimized
        if (WinGetMinMax("ahk_id " . hwnd2) != -1) {
            Log("WARNING: WinMinimize didn't work, forcing with ShowWindow(SW_MINIMIZE)", "WARNING")
            DllCall("ShowWindow", "Ptr", hwnd2, "Int", 6)  ; SW_MINIMIZE
            Sleep(100)
        }
        ; Then move it off-screen to ensure it's not visible
        Log("Moving UWP App 2 off-screen (-10000, -10000)", "DEBUG")
        DllCall("SetWindowPos", "Ptr", hwnd2, "Ptr", 0,
            "Int", -10000, "Int", -10000, "Int", 0, "Int", 0, "UInt", 0x0015)  ; SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOSIZE
        minState := WinGetMinMax("ahk_id " . hwnd2)
        Log("UWP App 2 state after minimize+move: " . minState . " (-1=minimized, 0=normal, 1=maximized)", "DEBUG")
    }
    
    ; Ensure tabs are always on top (especially over UWP apps)
    tabHwnd := tabs.Hwnd
    DllCall("SetWindowPos", "Ptr", tabHwnd, "Ptr", -1,  ; HWND_TOPMOST
        "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)  ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    
    tabs.Value := 1
    
    Log("Applications embedded in dual container", "DEBUG")
    
    ; Store handles and UWP status globally
    global app1Hwnd, app2Hwnd, appPid1, appPid2, containerHwnd, appContainerHwnd, containerTabHeight
    global app1IsUWPApp, app2IsUWPApp
    app1Hwnd := hwnd1
    app2Hwnd := hwnd2
    appPid1 := pid1
    appPid2 := pid2
    containerHwnd := container.Hwnd
    appContainerHwnd := appContainer.Hwnd
    containerTabHeight := tabHeight
    app1IsUWPApp := app1IsUWP
    app2IsUWPApp := app2IsUWP
        
    ; Tab switching handler
    tabs.OnEvent("Change", (*) => SwitchTab_Container(tabs, hwnd1, hwnd2))
    
    ; Resize handler
    container.OnEvent("Size", (*) => ResizeApps_Container(tabs, hwnd1, hwnd2, container, appContainer))
    
    ; Setup WTS Session Notifications
    if DllCall("Wtsapi32\WTSRegisterSessionNotification", "ptr", container.Hwnd, "uint", 0, "int") {
        OnMessage(0x02B1, OnSessionChange)
        OnMessage(0x0011, OnQueryEndSession)
        OnExit((*) => (
            DllCall("Wtsapi32\WTSUnRegisterSessionNotification", "ptr", container.Hwnd),
            OnMessage(0x02B1, OnSessionChange, 0),
            OnMessage(0x0011, OnQueryEndSession, 0)
        ))
        Log("Registered for", "DEBUG")
    } else {
        Log("WARNING: Could not register for session notifications (Container mode)", "WARNING")
    }
    
    ; Initialize polling as fallback
    global lastId := 0
    SetTimer(CheckSessionEvents, POLL_INTERVAL_MS)
    
    Log("Dual app container initialization complete - monitoring session events", "INFO")
    
    ; For robustness with UWP apps: Force tab cycle to ensure proper initial state
    ; This fixes visibility issues where UWP App 2 might remain visible at startup
    if (app1IsUWP || app2IsUWP) {
        Log("UWP app(s) detected - performing automatic tab cycle for robust initialization", "DEBUG")
        SetTimer(() => PerformInitialTabCycle(tabs), -200)  ; Run once after 100ms
    }
}

; Performs automatic tab cycle during initialization to ensure UWP apps are in correct state
PerformInitialTabCycle(tabCtrl) {
    Log("Starting automatic tab cycle: 1 → 2 → 1", "DEBUG")
    
    ; Switch to tab 2
    tabCtrl.Value := 2
    SwitchTab_Container(tabCtrl, app1Hwnd, app2Hwnd)
    Log("Auto-cycle: Tab 2 activated", "DEBUG")
    
    ; Wait 1 second, then switch back to tab 1
    ; Capture tabCtrl in a local variable for the lambda
    ctrl := tabCtrl
    SetTimer(() => SwitchBackToTab1(ctrl), -500)  ; Run once after 600ms
}

; Helper function for tab cycle - switches back to tab 1
SwitchBackToTab1(tabCtrl) {
    global app1Hwnd, app2Hwnd
    tabCtrl.Value := 1
    SwitchTab_Container(tabCtrl, app1Hwnd, app2Hwnd)
    Log("Auto-cycle: Tab 1 activated - initialization cycle complete", "DEBUG")
}

; Tab switching for container mode
SwitchTab_Container(tabCtrl, hwnd1, hwnd2) {
    try {
        global app1IsUWPApp, app2IsUWPApp, containerHwnd, containerTabHeight
        local containerX := 0, containerY := 0, cWidth := 0, cHeight := 0
        local uwpY := 0, uwpHeight := 0
        
        activeTab := tabCtrl.Value
        
        Log("SwitchTab_Container called - switching to tab " . activeTab . " (App1 UWP=" . app1IsUWPApp . ", App2 UWP=" . app2IsUWPApp . ")", "DEBUG")
        
        ; Get container position for UWP apps
        if (app1IsUWPApp || app2IsUWPApp) {
            try {
                WinGetPos(&containerX, &containerY, &cWidth, &cHeight, "ahk_id " . containerHwnd)
                uwpY := containerY + containerTabHeight
                uwpHeight := cHeight - containerTabHeight
                Log("Container position for UWP: X=" . containerX . " Y=" . containerY . " W=" . cWidth . " H=" . cHeight . " (UWP Y=" . uwpY . " H=" . uwpHeight . ")", "DEBUG")
            } catch as e {
                Log("ERROR: Could not get container position: " . e.message, "ERROR")
                return
            }
        }
        
        if (activeTab = 1) {
            ; Show App 1, hide App 2
            Log("Tab 1 selected - Showing App 1 (HWND=" . hwnd1 . ", UWP=" . app1IsUWPApp . "), Hiding App 2 (HWND=" . hwnd2 . ", UWP=" . app2IsUWPApp . ")", "DEBUG")
            
            if (!app2IsUWPApp) {
                DllCall("RedrawWindow", "Ptr", hwnd2, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
                DllCall("ShowWindow", "Ptr", hwnd2, "Int", 0)  ; SW_HIDE
                Log("App 2 (non-UWP) hidden", "DEBUG")
            } else {
                ; UWP: Minimize to hide
                Log("Minimizing UWP App 2", "DEBUG")
                WinMinimize("ahk_id " . hwnd2)
                Sleep(100)
                ; Force minimize if it didn't work
                if (WinGetMinMax("ahk_id " . hwnd2) != -1) {
                    Log("WARNING: WinMinimize didn't work for App 2, forcing with ShowWindow", "WARNING")
                    DllCall("ShowWindow", "Ptr", hwnd2, "Int", 6)  ; SW_MINIMIZE
                }
                ; Move off-screen to ensure it's not visible
                DllCall("SetWindowPos", "Ptr", hwnd2, "Ptr", 0,
                    "Int", -10000, "Int", -10000, "Int", 0, "Int", 0, "UInt", 0x0015)
                Log("App 2 (UWP) minimized and moved off-screen - state: " . WinGetMinMax("ahk_id " . hwnd2), "DEBUG")
            }
            
            if (!app1IsUWPApp) {
                Log("Showing non-UWP App 1", "DEBUG")
                DllCall("ShowWindow", "Ptr", hwnd1, "Int", 5)  ; SW_SHOW
                DllCall("RedrawWindow", "Ptr", hwnd1, "Ptr", 0, "Ptr", 0, "UInt", 0x0085)
                ; Force to foreground
                DllCall("SetForegroundWindow", "Ptr", hwnd1)
                Log("App 1 (non-UWP) now visible", "DEBUG")
            } else {
                ; UWP: Restore from minimized state, position, and show
                Log("Showing UWP App 1 - restoring from minimized", "DEBUG")
                Log("App 1 state before restore: " . WinGetMinMax("ahk_id " . hwnd1), "DEBUG")
                WinRestore("ahk_id " . hwnd1)
                Sleep(100)
                Log("App 1 state after restore: " . WinGetMinMax("ahk_id " . hwnd1), "DEBUG")
                PositionUWPApp(hwnd1, containerX, uwpY, cWidth, uwpHeight)
                Sleep(50)
                DllCall("ShowWindow", "Ptr", hwnd1, "Int", 5)  ; SW_SHOW
                DllCall("RedrawWindow", "Ptr", hwnd1, "Ptr", 0, "Ptr", 0, "UInt", 0x0085)
                Log("App 1 (UWP) should now be visible - final state: " . WinGetMinMax("ahk_id " . hwnd1), "DEBUG")
            }
        } else {
            ; Show App 2, hide App 1
            Log("Tab 2 selected - Hiding App 1 (HWND=" . hwnd1 . ", UWP=" . app1IsUWPApp . "), Showing App 2 (HWND=" . hwnd2 . ", UWP=" . app2IsUWPApp . ")", "DEBUG")
            
            if (!app1IsUWPApp) {
                DllCall("RedrawWindow", "Ptr", hwnd1, "Ptr", 0, "Ptr", 0, "UInt", 0x0001)
                DllCall("ShowWindow", "Ptr", hwnd1, "Int", 0)  ; SW_HIDE
                Log("App 1 (non-UWP) hidden", "DEBUG")
            } else {
                ; UWP: Minimize to hide
                Log("Minimizing UWP App 1", "DEBUG")
                WinMinimize("ahk_id " . hwnd1)
                Sleep(100)
                ; Force minimize if it didn't work
                if (WinGetMinMax("ahk_id " . hwnd1) != -1) {
                    Log("WARNING: WinMinimize didn't work for App 1, forcing with ShowWindow", "WARNING")
                    DllCall("ShowWindow", "Ptr", hwnd1, "Int", 6)  ; SW_MINIMIZE
                }
                ; Move off-screen to ensure it's not visible
                DllCall("SetWindowPos", "Ptr", hwnd1, "Ptr", 0,
                    "Int", -10000, "Int", -10000, "Int", 0, "Int", 0, "UInt", 0x0015)
                Log("App 1 (UWP) minimized and moved off-screen - state: " . WinGetMinMax("ahk_id " . hwnd1), "DEBUG")
            }
            
            if (!app2IsUWPApp) {
                Log("Showing non-UWP App 2", "DEBUG")
                DllCall("ShowWindow", "Ptr", hwnd2, "Int", 5)  ; SW_SHOW
                DllCall("RedrawWindow", "Ptr", hwnd2, "Ptr", 0, "Ptr", 0, "UInt", 0x0085)
                ; Force to foreground
                DllCall("SetForegroundWindow", "Ptr", hwnd2)
                Log("App 2 (non-UWP) now visible", "DEBUG")
            } else {
                ; UWP: Restore from minimized state, position, and show
                Log("Showing UWP App 2 - restoring from minimized", "DEBUG")
                Log("App 2 state before restore: " . WinGetMinMax("ahk_id " . hwnd2), "DEBUG")
                WinRestore("ahk_id " . hwnd2)
                Sleep(100)
                Log("App 2 state after restore: " . WinGetMinMax("ahk_id " . hwnd2), "DEBUG")
                PositionUWPApp(hwnd2, containerX, uwpY, cWidth, uwpHeight)
                Sleep(50)
                DllCall("ShowWindow", "Ptr", hwnd2, "Int", 5)  ; SW_SHOW
                DllCall("RedrawWindow", "Ptr", hwnd2, "Ptr", 0, "Ptr", 0, "UInt", 0x0085)
                Log("App 2 (UWP) should now be visible - final state: " . WinGetMinMax("ahk_id " . hwnd2), "DEBUG")
            }
        }
    } catch as e {
        Log("ERROR in SwitchTab_Container: " . e.message . " at line " . e.line, "ERROR")
    }
}

; Resize apps when container resizes
ResizeApps_Container(tabCtrl, hwnd1, hwnd2, container, appContainer) {
    global containerTabHeight, app1IsUWPApp, app2IsUWPApp
    
    activeTab := tabCtrl.Value
    
    container.GetPos(&containerX, &containerY, &cWidth, &cHeight)
    
    ; Apps fill entire screen
    appContainer.Move(0, 0, cWidth, cHeight)
    
    ; Update tab control to match calculated height and keep on top
    tabHwnd := tabCtrl.Hwnd
    DllCall("SetWindowPos", "Ptr", tabHwnd, "Ptr", -1,  ; Keep HWND_TOPMOST
        "Int", 0, "Int", 0, "Int", cWidth, "Int", containerTabHeight, "UInt", 0x0010)  ; SWP_NOACTIVATE
    
    ; Calculate position below tabs for UWP apps
    uwpY := containerY + containerTabHeight
    uwpHeight := cHeight - containerTabHeight
    
    ; Resize apps - only resize the currently visible app (especially important for UWP)
    if (activeTab = 1) {
        ; Tab 1 active - resize App 1
        if (!app1IsUWPApp) {
            try WinMaximize("ahk_id " . hwnd1)
        } else {
            PositionUWPApp(hwnd1, containerX, uwpY, cWidth, uwpHeight)
        }
        ; App 2 stays hidden (off-screen for UWP, hidden for normal)
    } else {
        ; Tab 2 active - resize App 2
        if (!app2IsUWPApp) {
            try WinMaximize("ahk_id " . hwnd2)
        } else {
            PositionUWPApp(hwnd2, containerX, uwpY, cWidth, uwpHeight)
        }
        ; App 1 stays hidden (off-screen for UWP, hidden for normal)
    }
}
