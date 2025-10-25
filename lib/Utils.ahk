; ============================================================================
; Utils.ahk - Utility Functions
; ============================================================================
; General utility functions used across the application
; ============================================================================

; Logging function for auditing and support
; Levels: ERROR, WARNING, INFO (default), DEBUG
; In PRODUCTION_MODE, only ERROR and WARNING are logged
Log(msg, level := "INFO") {
    global PRODUCTION_MODE
    
    ; In production mode, only log ERROR and WARNING
    if (PRODUCTION_MODE && level != "ERROR" && level != "WARNING") {
        return
    }
    
    logFile := A_ScriptDir "\dLabAppControl.log"
    timestamp := FormatTime(A_Now, "yyyyMMddHHmmss")
    prefix := (level != "INFO") ? "[" . level . "] " : ""
    logEntry := timestamp . " - " . prefix . msg . "`n"
    FileAppend(logEntry, logFile, "UTF-8")
    OutputDebug(timestamp . " - dLabAppControl: " . prefix . msg)
}

; Helper function to check if a string is a number
IsNumber(str) {
    try {
        Integer(str)
        return true
    } catch {
        return false
    }
}

; Detect if a window uses a custom-drawn title bar (modern apps) or standard Windows title bar
; Parameters: hwnd - Window handle, className - Optional window class name (if already known)
; Returns: true if custom title bar, false if standard Windows title bar
HasCustomTitleBar(hwnd, className := "") {
    ; Get window styles
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")  ; GWL_STYLE
    exStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Int") ; GWL_EXSTYLE
    
    ; Check if window has WS_CAPTION (title bar)
    WS_CAPTION := 0x00C00000
    hasCaption := (style & WS_CAPTION) = WS_CAPTION
    
    ; If no caption at all, it's likely custom-drawn
    if (!hasCaption) {
        return true
    }
    
    ; Check for WS_EX_NOREDIRECTIONBITMAP - used by modern apps with custom rendering
    WS_EX_NOREDIRECTIONBITMAP := 0x00200000
    hasNoRedirection := (exStyle & WS_EX_NOREDIRECTIONBITMAP) = WS_EX_NOREDIRECTIONBITMAP
    
    if (hasNoRedirection) {
        return true
    }
    
    ; Check window class - use provided className or get it from hwnd
    try {
        if (className = "") {
            className := WinGetClass("ahk_id " . hwnd)
        }
        
        ; Known custom title bar apps
        customTitleBarApps := [
            "Chrome_WidgetWin_1",   ; Chrome/Edge
            "MozillaWindowClass",   ; Firefox
            "Qt5",                  ; Qt apps
            "Qt6",                  ; Qt apps
            "Electron",             ; Electron apps (VSCode, Discord, etc.)
        ]
        
        for appClass in customTitleBarApps {
            if (InStr(className, appClass)) {
                return true
            }
        }
    }
    
    ; Default: assume standard Windows title bar
    return false
}

; Get the height of a custom title bar for modern apps
; Parameters: className - The window class name (from command line args)
; Returns: Estimated height in pixels (typically 30-40px)
GetCustomTitleBarHeight(className) {
    ; Known title bar heights for common apps
    if (InStr(className, "MozillaWindowClass")) {
        Log("MozillaWindowClass detected - returning title bar height 40", "DEBUG")
        return 40  ; Firefox title bar height
    }
    else if (InStr(className, "Chrome_WidgetWin_1")) {
        return 32  ; Chrome/Edge title bar height
    }
    else if (InStr(className, "Qt5") || InStr(className, "Qt6")) {
        return 30  ; Qt apps title bar height
    }
    else if (InStr(className, "Electron")) {
        return 32  ; Electron apps (VSCode, Discord, etc.)
    }
    
    ; Default estimate for unknown custom title bar apps
    return 30
}

; Detect if a window is a UWP (Universal Windows Platform) application
; Parameters: hwnd - Window handle, className - Optional window class name
; Returns: true if UWP app, false otherwise
IsUWPApp(hwnd, className := "") {
    try {
        if (className = "") {
            className := WinGetClass("ahk_id " . hwnd)
        }
        
        ; UWP apps typically use ApplicationFrameWindow as container or specific classes
        if (InStr(className, "ApplicationFrameWindow")) {
            return true
        }
        
        ; Check process name - UWP apps often run through specific hosts
        processPath := WinGetProcessPath("ahk_id " . hwnd)
        if (InStr(processPath, "WindowsApps") || InStr(processPath, "SystemApps")) {
            return true
        }
        
        ; Check extended style for WS_EX_NOREDIRECTIONBITMAP (common in UWP)
        exStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Int")
        WS_EX_NOREDIRECTIONBITMAP := 0x00200000
        if ((exStyle & WS_EX_NOREDIRECTIONBITMAP) = WS_EX_NOREDIRECTIONBITMAP) {
            ; Also check if it's in WindowsApps path to confirm UWP
            if (InStr(processPath, "WindowsApps")) {
                return true
            }
        }
    }
    
    return false
}
