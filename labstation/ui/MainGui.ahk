; ============================================================================
; Lab Station - Desktop GUI
; ============================================================================
#Requires AutoHotkey v2.0
#Include ..\core\Config.ahk
#Include ..\core\Logger.ahk
#Include ..\core\Admin.ahk
#Include ..\diagnostics\Status.ahk
#Include ..\service\SessionManager.ahk
#Include ..\service\SessionGuard.ahk
#Include ..\system\PowerManager.ahk

; Entry point for LabStation.exe gui
LS_StartMainGui() {
    global LS_GUI
    if (IsSet(LS_GUI) && LS_GUI && LS_GUI.Visible) {
        LS_GUI.Show()
        return
    }
    LS_GUI := LS_BuildGui()
    LS_GUI.Show()
}

LS_BuildGui() {
    myGui := Gui("+Resize", "Lab Station Control Panel")
    myGui.BackColor := "0F1419"
    myGui.SetFont("s10", "Segoe UI")
    
    ; Store status box reference in GUI object for later access
    myGui.StatusBox := ""
    
    ; Header with icon
    myGui.SetFont("s17 Bold cFFFFFF", "Bahnschrift")
    myGui.AddText("x24 y16", "🖥️ Lab Station")
    myGui.SetFont("s9 c9CA3AF")
    myGui.AddText("x24 yp+28", "Workstation management console")
    logoPaths := [
        LAB_STATION_PROJECT_ROOT "\img\DecentraLabs.png",
        A_ScriptDir "\img\DecentraLabs.png",
        A_ScriptDir "\DecentraLabs.png"
    ]
    for path in logoPaths {
        if (FileExist(path)) {
        myGui.AddPicture("x500 y12 w196 h40 +BackgroundTrans", path)
        break
        }
    }
    logoPath := LAB_STATION_PROJECT_ROOT "\img\DecentraLabs.png"
    if (FileExist(logoPath)) {
        myGui.AddPicture("x500 y12 w196 h40 +BackgroundTrans", logoPath)
    }
    
    ; Status section
    myGui.SetFont("s11 Bold cFFFFFF")
    myGui.AddText("x24 y72", "📊 System Status")
    
    myGui.SetFont("s9 cE5E7EB")
    myGui.StatusBox := myGui.AddEdit("x24 y100 w420 h180 -Wrap ReadOnly -TabStop cD1FAE5 Background1F2937 +Border")
    myGui.StatusBox.Value := "Loading system status..."
    
    ; Status action buttons
    myGui.SetFont("s9 cFFFFFF")
    refreshBtn := myGui.AddButton("x24 y290 w130 h32", "🔄 Refresh")
    refreshBtn.OnEvent("Click", LS_GuiRefreshStatus_Handler)
    
    exportBtn := myGui.AddButton("x164 y290 w150 h32", "💾 Export JSON")
    exportBtn.OnEvent("Click", LS_GuiExportStatus_Handler)
    
    logBtn := myGui.AddButton("x324 y290 w120 h32", "📄 Open Log")
    logBtn.OnEvent("Click", LS_GuiOpenLog_Handler)
    
    ; Vertical separator
    myGui.SetFont("s1 c374151")
    myGui.AddText("x470 y16 w2 h310", "│")
    
    ; Actions section
    myGui.SetFont("s11 Bold cFFFFFF")
    myGui.AddText("x490 y65", "⚡ Quick Actions")
    
    myGui.SetFont("s8 cC08A2B")
    myGui.AddText("x490 y85 w230", "⚠️ Actions require admin privileges")
    
    ; Session management buttons
    myGui.SetFont("s9 Bold c9CA3AF")
    myGui.AddText("x490 y110", "Session Management")
    
    myGui.SetFont("s9 cFFFFFF")
    guardBtn := myGui.AddButton("x490 y130 w220 h34", "🛡️ Start Session Guard")
    guardBtn.OnEvent("Click", LS_GuiRunGuard_Handler)
    
    prepBtn := myGui.AddButton("x490 y170 w220 h34", "🔧 Prepare Session")
    prepBtn.OnEvent("Click", LS_GuiRunPrepare_Handler)
    
    relBtn := myGui.AddButton("x490 y210 w220 h34", "🔄 Release + Reboot")
    relBtn.OnEvent("Click", LS_GuiRunRelease_Handler)
    
    ; Power management buttons
    myGui.SetFont("s9 Bold c9CA3AF")
    myGui.AddText("x490 y255", "Power Management")
    
    myGui.SetFont("s9 cFFFFFF")
    shutBtn := myGui.AddButton("x490 y275 w220 h34", "🔌 Shutdown (60s)")
    shutBtn.OnEvent("Click", LS_GuiRunPowerShutdown_Handler)
    
    hibBtn := myGui.AddButton("x490 y315 w220 h34", "💤 Hibernate (30s)")
    hibBtn.OnEvent("Click", LS_GuiRunPowerHibernate_Handler)
    
    ; Footer
    myGui.SetFont("s8 c6B7280")
    myGui.AddText("x24 y350 w686 Center", "DecentraLabs © 2025 · Lab Station v3.0.0")
    refreshBtn.Focus()
    
    myGui.OnEvent("Close", (*) => myGui.Destroy())
    LS_GuiRefreshStatus(myGui)
    return myGui
}

LS_GuiRefreshStatus(gui) {
    status := LS_Status.Collect()
    summary := []
    
    ; Header
    summary.Push("═══════════════════════════════════════")
    summary.Push("  SYSTEM STATUS REPORT")
    summary.Push("═══════════════════════════════════════")
    summary.Push("")
    
    ; Host info
    summary.Push("🖥️  Host: " . (status.Has("host") ? status["host"] : A_ComputerName))
    summary.Push("")
    
    ; Readiness
    ready := (status.Has("summary") && status["summary"].Has("ready")) ? status["summary"]["ready"] : false
    readyIcon := ready ? "✅" : "⚠️"
    summary.Push(readyIcon . "  Ready: " . (ready ? "Yes" : "Needs attention"))
    summary.Push("")
    
    ; Local mode
    localMode := status.Has("localModeEnabled") ? status["localModeEnabled"] : false
    localIcon := localMode ? "🔒" : "🌐"
    summary.Push(localIcon . "  Local mode: " . (localMode ? "Enabled" : "Disabled"))
    summary.Push("")
    
    ; Active sessions
    hasUsers := status.Has("sessions") && status["sessions"].Has("hasOtherUsers") && status["sessions"]["hasOtherUsers"]
    userIcon := hasUsers ? "👤" : "○"
    summary.Push(userIcon . "  Active sessions: " . (hasUsers ? "Present" : "None"))
    summary.Push("")
    
    ; Issues
    if (status.Has("summary") && status["summary"].Has("issues") && status["summary"]["issues"].Length > 0) {
        summary.Push("⚠️  ISSUES DETECTED:")
        for issue in status["summary"]["issues"] {
            summary.Push("   • " . issue)
        }
    } else {
        summary.Push("✓  No issues detected")
    }
    
    summary.Push("")
    summary.Push("Last refresh: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))
    
    gui.StatusBox.Value := LS_StrJoin(summary, "`r`n")
}

LS_GuiExportStatus(gui) {
    target := LAB_STATION_STATUS_FILE
    if (LS_Status.ExportJson(target)) {
        MsgBox "Report saved to " . target, "Lab Station", "OK Iconi"
    } else {
        MsgBox "Unable to export report", "Lab Station", "OK Iconx"
    }
}

LS_GuiOpenLog() {
    if (!FileExist(LAB_STATION_LOG)) {
        MsgBox "Log file not found at " . LAB_STATION_LOG, "Lab Station", "OK Iconx"
        return
    }
    Run Format('notepad.exe "{1}"', LAB_STATION_LOG)
}

LS_GuiEnsureAdmin() {
    if (!LS_EnsureAdmin(false)) {
        MsgBox "Admin privileges required for this action.", "Lab Station", "OK Iconx"
        return false
    }
    return true
}

LS_GuiRunGuard() {
    if (!LS_GuiEnsureAdmin())
        return
    success := LS_SessionGuard.Run(Map("grace", 90))
    icon := success ? "OK Iconi" : "OK Iconx"
    MsgBox (success ? "Session guard finished" : "Session guard reported warnings"), "Lab Station", icon
}

LS_GuiRunPrepare() {
    if (!LS_GuiEnsureAdmin())
        return
    success := LS_SessionManager.PrepareSession()
    icon := success ? "OK Iconi" : "OK Iconx"
    MsgBox (success ? "Prepare-session completed" : "Prepare-session finished with warnings"), "Lab Station", icon
}

LS_GuiRunRelease() {
    if (!LS_GuiEnsureAdmin())
        return
    success := LS_SessionManager.ReleaseSession(Map("reboot", true))
    icon := success ? "OK Iconi" : "OK Iconx"
    MsgBox (success ? "Release-session completed" : "Release-session finished with warnings"), "Lab Station", icon
}

LS_GuiRunPower(mode) {
    if (!LS_GuiEnsureAdmin())
        return
    opts := mode = "shutdown" ? Map("delay", 60, "reason", "GUI action") : Map("delay", 30, "reason", "GUI action")
    success := mode = "shutdown" ? LS_PowerManager.Shutdown(opts) : LS_PowerManager.Hibernate(opts)
    icon := success ? "OK Iconi" : "OK Iconx"
    MsgBox (success ? "Power action scheduled" : "Power action failed (see log)"), "Lab Station", icon
}

; Event handlers - receive button control and can access Gui via control.Gui
LS_GuiRefreshStatus_Handler(ctrl, info) {
    LS_GuiRefreshStatus(ctrl.Gui)
}

LS_GuiExportStatus_Handler(ctrl, info) {
    LS_GuiExportStatus(ctrl.Gui)
}

LS_GuiOpenLog_Handler(ctrl, info) {
    LS_GuiOpenLog()
}

LS_GuiRunGuard_Handler(ctrl, info) {
    LS_GuiRunGuard()
}

LS_GuiRunPrepare_Handler(ctrl, info) {
    LS_GuiRunPrepare()
}

LS_GuiRunRelease_Handler(ctrl, info) {
    LS_GuiRunRelease()
}

LS_GuiRunPowerShutdown_Handler(ctrl, info) {
    LS_GuiRunPower("shutdown")
}

LS_GuiRunPowerHibernate_Handler(ctrl, info) {
    LS_GuiRunPower("hibernate")
}
