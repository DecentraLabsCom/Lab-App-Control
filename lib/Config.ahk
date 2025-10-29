; ============================================================================
; Config.ahk - Configuration and Constants
; ============================================================================
; Centralized configuration for dLabAppControl
; ============================================================================

; Configuration constants
global POLL_INTERVAL_MS := 5000  ; Monitoring interval in milliseconds
global STARTUP_TIMEOUT  := 6     ; Startup timeout in seconds
global ACTIVATION_RETRIES := 3   ; Number of retries for window activation
global VERBOSE_LOGGING  := false ; Set to true for detailed polling logs, false for events only
global SILENT_ERRORS    := true  ; Set to true to suppress error MsgBox popups (log only)
global PRODUCTION_MODE  := true ; Set to true to log only critical messages (errors, warnings, key events)

; Browser auto-kiosk configuration
global AUTO_BROWSER_KIOSK := true  ; Set to true to automatically add kiosk/incognito flags to browsers
global BROWSER_KIOSK_FLAGS := Map(
    "chrome.exe", "--kiosk --incognito",
    "msedge.exe", "--kiosk --inprivate",
    "firefox.exe", "-kiosk -private-window"
)

; Global variables (initialized here to avoid errors in #HotIf)
global app1Hwnd := 0
global app2Hwnd := 0
global appPid1 := 0
global appPid2 := 0
global containerHwnd := 0
global appContainerHwnd := 0
global containerTabHeight := 35
global app1IsUWPApp := false
global app2IsUWPApp := false
global DUAL_APP_MODE := false
global CUSTOM_CLOSE_METHOD := "none"
global target := ""  ; Target window for single mode
global lastId := 0   ; Last RDP event ID processed

; Custom close method variables (single mode)
global customCloseControl := ""
global customCloseX := 0
global customCloseY := 0
global TEST_MODE := false

; RDP event monitoring
global CloseOnEventIds := [23, 24, 39, 40]
