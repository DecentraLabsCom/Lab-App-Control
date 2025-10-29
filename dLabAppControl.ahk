; ============================================================================
; dLabAppControl - Lab Application Controller for RDP Disconnect Handling
; ============================================================================
; Manages single or dual applications with automatic closure on RDP disconnect
; Supports custom close methods and embedded app containers
; ============================================================================

#SingleInstance Force
; #Requires AutoHotkey v2.0
; ProcessSetPriority "High"

; ============================================================================
; LOAD MODULES
; ============================================================================
#Include lib\Config.ahk
#Include lib\Utils.ahk
#Include lib\WindowClosing.ahk
#Include lib\RdpMonitoring.ahk
#Include lib\SingleAppMode.ahk
#Include lib\DualAppMode.ahk

; ============================================================================
; HELP & USAGE
; ============================================================================

; Single mode examples:
; dLabAppControl.exe "MozillaWindowClass" "C:\Program Files\Mozilla Firefox\firefox.exe"
; dLabAppControl.exe "Notepad++" "C:\Program Files (x86)\Notepad++\notepad++.exe"
; dLabAppControl.exe "Chrome_WidgetWin_1" "\"C:\Program Files\Google\Chrome\Application\chrome.exe\" --app=http://127.0.0.1:8000 --incognito"
;
; Dual mode example:
; dLabAppControl.exe --dual "MozillaWindowClass" "C:\Program Files\Mozilla Firefox\firefox.exe" "Notepad++" "C:\Program Files (x86)\Notepad++\notepad++.exe" --tab1="Firefox" --tab2="Notepad++"

if (A_Args.Length < 2) {
    MsgBox "Use: dLabAppControl.exe [window_ahk_class] [C:\path\to\app.exe] [options]"
    . "`n`nSingle Application Mode:"
    . "`n- dLabAppControl.exe `"MozillaWindowClass`" `"C:\Program Files\Mozilla\firefox.exe`""
    . "`n- dLabAppControl.exe `"Chrome_WidgetWin_1`" `\`"C:\Program Files\Google\Chrome\Application\chrome.exe\`" --app=http://127.0.0.1:8000 --incognito`""
    . "`n- dLabAppControl.exe `"MyAppClass`" `"myapp.exe`" --close-button=`"Button2`""
    . "`n- dLabAppControl.exe `"LVDChild`" `"myVI.exe`" --close-coords=`"330,484`" --test"
    . "`n`nDual Application Mode (Tabbed Container):"
    . "`n- dLabAppControl.exe --dual `"Class1`" `"App1.exe`" `"Class2`" `"App2.exe`""
    . "`n- dLabAppControl.exe --dual `"Class1`" `\`"App1.exe\`" --param1 value1`" `"Class2`" `\`"App2.exe\`" --param2 value2`" --tab1=`"Camera`" --tab2=`"Viewer`""
    . "`n- Both apps will be shown in tabs within a single container window"
    . "`n`nOptions:"
    . "`n  --dual                    Enable dual app mode (tabbed container)"
    . "`n  --tab1=`"Title`"           Custom title for first tab (dual mode only)"
    . "`n  --tab2=`"Title`"           Custom title for second tab (dual mode only)"
    . "`n  --close-button=`"ClassNN`" Custom close button control (e.g., Button2)"
    . "`n  --close-coords=`"X,Y`"     Custom close coordinates in CLIENT space"
    . "`n  --test                    Test custom close method after 5 seconds"
    . "`n`nApplication Commands:"
    . "`n- Simple paths: C:\path\to\app.exe"
    . "`n- With spaces and parameters: `\`"C:\my path\to\app.exe\`" --param1 value1 --param2 value2`""
    . "`n- CMD: Use \`" to escape quotes."
    . "`n- Guacamole Remote App: No escape needed."
    . "`n  Example: Chrome_WidgetWin_1 `"C:\Program Files\Google\Chrome\Application\chrome.exe`" --app=http://127.0.0.1:8000"
    . "`n`nCoordinate Guidelines (use CLIENT coordinates from WindowSpy):"
    . "`n- Example: --close-coords=`"330,484`" means 330 pixels right, 484 down from client area"
    ExitApp
}

; ============================================================================
; MAIN ENTRY POINT - Argument Parsing & Mode Detection
; ============================================================================

; Helper function to determine if an argument is a full command (with parameters) or just a path
IsFullCommand(arg) {
    ; If it contains spaces and looks like a command with parameters, treat as full command
    ; Examples: "C:\path\to\app.exe --param value", "\"C:\path\to\app.exe\" --param value"
    if (InStr(arg, " ") && (InStr(arg, ".exe") || InStr(arg, ".bat") || InStr(arg, ".cmd"))) {
        return true
    }
    ; If it starts and ends with quotes and contains spaces inside, it's likely a full command
    if (SubStr(arg, 1, 1) = '"' && SubStr(arg, -1) = '"' && InStr(SubStr(arg, 2, StrLen(arg) - 2), " ")) {
        return true
    }
    return false
}

; Parse optional parameters
DUAL_APP_MODE := false
tab1Title := "Application 1"  ; Default title
tab2Title := "Application 2"  ; Default title
positionalArgs := []  ; Non-option arguments

; Global variables for custom close (accessed by Utils.ahk and WindowClosing.ahk)
global customCloseControl := ""
global customCloseX := 0
global customCloseY := 0
global TEST_MODE := false
global CUSTOM_CLOSE_METHOD := "none"

; First pass: extract options and collect positional arguments
for index, arg in A_Args {
    if (SubStr(arg, 1, 2) = "--") {
        ; This is an option
        argLower := StrLower(arg)
        
        if (argLower = "--dual") {
            DUAL_APP_MODE := true
            Log("--dual flag detected - Dual app mode enabled")
        } else if (argLower = "--test") {
            TEST_MODE := true
            Log("--test flag detected - Test mode enabled")
        } else if (SubStr(arg, 1, 7) = "--tab1=") {
            tab1Title := SubStr(arg, 8)
            if (SubStr(tab1Title, 1, 1) = '"' && SubStr(tab1Title, -1) = '"') {
                tab1Title := SubStr(tab1Title, 2, StrLen(tab1Title) - 2)
            }
            Log("Custom tab 1 title: " . tab1Title)
        } else if (SubStr(arg, 1, 7) = "--tab2=") {
            tab2Title := SubStr(arg, 8)
            if (SubStr(tab2Title, 1, 1) = '"' && SubStr(tab2Title, -1) = '"') {
                tab2Title := SubStr(tab2Title, 2, StrLen(tab2Title) - 2)
            }
            Log("Custom tab 2 title: " . tab2Title)
        } else if (SubStr(arg, 1, 15) = "--close-button=") {
            customCloseControl := SubStr(arg, 16)
            if (SubStr(customCloseControl, 1, 1) = '"' && SubStr(customCloseControl, -1) = '"') {
                customCloseControl := SubStr(customCloseControl, 2, StrLen(customCloseControl) - 2)
            }
            CUSTOM_CLOSE_METHOD := "control"
            Log("Custom close button: " . customCloseControl)
        } else if (SubStr(arg, 1, 15) = "--close-coords=") {
            coordsStr := SubStr(arg, 16)
            if (SubStr(coordsStr, 1, 1) = '"' && SubStr(coordsStr, -1) = '"') {
                coordsStr := SubStr(coordsStr, 2, StrLen(coordsStr) - 2)
            }
            ; Parse X,Y coordinates
            coords := StrSplit(coordsStr, ",")
            if (coords.Length = 2) {
                customCloseX := Integer(coords[1])
                customCloseY := Integer(coords[2])
                CUSTOM_CLOSE_METHOD := "coordinates"
                Log("Custom close coordinates: " . customCloseX . "," . customCloseY)
            } else {
                MsgBox("Error: --close-coords must be in format X,Y (e.g., --close-coords=`"330,484`")", "Invalid Coordinates", 16)
                ExitApp(1)
            }
        }
    } else {
        ; This is a positional argument
        positionalArgs.Push(arg)
    }
}

; Validate custom close parameters
if (customCloseControl != "" && (customCloseX > 0 || customCloseY > 0)) {
    MsgBox("Error: Cannot use both --close-button and --close-coords at the same time", "Invalid Parameters", 16)
    ExitApp(1)
}

; Parse arguments based on mode
if (DUAL_APP_MODE) {
    ; Dual app mode: class1 command1 class2 command2
    if (positionalArgs.Length < 4) {
        MsgBox "Error: Dual mode requires 4 arguments: class1 command1 class2 command2"
        ExitApp
    }
    
    windowClass := positionalArgs[1]
    appCommand := positionalArgs[2]
    windowClass2 := positionalArgs[3]
    appCommand2 := positionalArgs[4]
    
    ; Extract executable paths for validation and logging
    appPath := IsFullCommand(appCommand) ? ExtractExecutablePath(appCommand) : appCommand
    appPath2 := IsFullCommand(appCommand2) ? ExtractExecutablePath(appCommand2) : appCommand2
    
    Log("App 1: Class=" . windowClass . ", Command=" . appCommand . ", Tab Title=" . tab1Title)
    Log("App 2: Class=" . windowClass2 . ", Command=" . appCommand2 . ", Tab Title=" . tab2Title)
    
    ; Launch dual app container with custom tab titles
    CreateDualAppContainer(windowClass, appCommand, windowClass2, appCommand2, tab1Title, tab2Title)
    return  ; Container handles everything from here
    
} else {
    ; Single app mode
    if (positionalArgs.Length < 2) {
        MsgBox "Error: Single mode requires at least 2 arguments: class command"
        ExitApp
    }
    
    windowClass := positionalArgs[1]
    appCommand := positionalArgs[2]
    
    ; Extract executable path for validation
    appPath := IsFullCommand(appCommand) ? ExtractExecutablePath(appCommand) : appCommand
    
    Log("SINGLE APP MODE - Class: " . windowClass . ", Command: " . appCommand)
    if (CUSTOM_CLOSE_METHOD = "control") {
        Log("Custom close method: Button control '" . customCloseControl . "'")
    } else if (CUSTOM_CLOSE_METHOD = "coordinates") {
        Log("Custom close method: Coordinates (" . customCloseX . "," . customCloseY . ")")
    } else {
        Log("Custom close method: Standard cascade")
    }
    
    ; Launch single app mode
    CreateSingleApp(windowClass, appCommand)
    return  ; Single mode handles everything from here
}

; ============================================================================
; HOTKEY DIRECTIVES (Must be at file level, not inside functions)
; ============================================================================

; Block Alt+F4 on the lab window (single app mode)
#HotIf WinActive(target)
!F4::return
#HotIf

; Block Alt+F4 on both embedded applications (dual app mode)
; Check if app1Hwnd is set (non-zero) to ensure we're in dual mode
#HotIf (app1Hwnd != 0) && (WinActive("ahk_id " . app1Hwnd) || WinActive("ahk_id " . app2Hwnd))
!F4::return
#HotIf
