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

    myGui.StatusBox := ""
    myGui.SetupButton := ""
    myGui.SetupChip := ""

    ; Header
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
            myGui.AddPicture("x500 y12 h40 +BackgroundTrans", path)
            break
        }
    }
    myGui.SetFont("s8 cC08A2B")
    myGui.SetupChip := myGui.AddText("x24 y56 w420", "Setup status: checking...")

    ; Status section
    myGui.SetFont("s11 Bold cFFFFFF")
    myGui.AddText("x24 y82", "📊 System Status")

    myGui.SetFont("s9 cE5E7EB")
    myGui.StatusBox := myGui.AddEdit("x24 y110 w420 h180 -Wrap ReadOnly -TabStop cD1FAE5 Background1F2937 +Border")
    myGui.StatusBox.Value := "Loading system status..."

    ; Status action buttons
    myGui.SetFont("s9 cFFFFFF")
    refreshBtn := myGui.AddButton("x24 y300 w130 h32", "🔄 Refresh")
    refreshBtn.OnEvent("Click", LS_GuiRefreshStatus_Handler)

    exportBtn := myGui.AddButton("x164 y300 w150 h32", "💾 Export JSON")
    exportBtn.OnEvent("Click", LS_GuiExportStatus_Handler)

    logBtn := myGui.AddButton("x324 y300 w120 h32", "📄 Open Log")
    logBtn.OnEvent("Click", LS_GuiOpenLog_Handler)

    ; Separator
    myGui.SetFont("s1 c374151")
    myGui.AddText("x470 y16 w2 h330", "│")

    ; Actions
    myGui.SetFont("s11 Bold cFFFFFF")
    myGui.AddText("x490 y65", "⚡ Quick Actions")

    myGui.SetFont("s8 cC08A2B")
    myGui.AddText("x490 y85 w230", "⚠️ Actions require admin privileges")

    myGui.SetFont("s9 Bold c9CA3AF")
    myGui.AddText("x490 y110", "Setup & Sessions")

    myGui.SetFont("s9 cFFFFFF")
    myGui.SetupButton := myGui.AddButton("x490 y130 w220 h34", "🛠️ Run Setup Wizard")
    myGui.SetupButton.OnEvent("Click", LS_GuiRunSetup_Handler)

    guardBtn := myGui.AddButton("x490 y180 w220 h34", "🛡️ Start Session Guard")
    guardBtn.OnEvent("Click", LS_GuiRunGuard_Handler)

    prepBtn := myGui.AddButton("x490 y220 w220 h34", "🔧 Prepare Session")
    prepBtn.OnEvent("Click", LS_GuiRunPrepare_Handler)

    relBtn := myGui.AddButton("x490 y260 w220 h34", "🔄 Release + Reboot")
    relBtn.OnEvent("Click", LS_GuiRunRelease_Handler)

    ; Footer
    myGui.SetFont("s8 c6B7280")
    myGui.AddText("x24 y360 w686 Center", "DecentraLabs © 2025 · Lab Station v3.0.0")
    refreshBtn.Focus()

    myGui.OnEvent("Close", (*) => myGui.Destroy())
    LS_GuiRefreshStatus(myGui)
    return myGui
}

LS_GuiNeedsSetup(status) {
    ; Basic readiness check: summary.ready false OR missing core features
    if (status.Has("summary") && status["summary"].Has("ready") && !status["summary"]["ready"])
        return true
    if (status.Has("remoteAppEnabled") && !status["remoteAppEnabled"])
        return true
    if (status.Has("autoStartConfigured") && !status["autoStartConfigured"])
        return true
    if (status.Has("wake")) {
        wake := status["wake"]
        if (wake.Has("armedCount") && wake["armedCount"] = 0)
            return true
    }
    return false
}

LS_GuiRefreshStatus(gui) {
    status := LS_Status.Collect()
    needsSetup := LS_GuiNeedsSetup(status)
    gui.SetupButton.Enabled := needsSetup
    gui.SetupButton.Text := needsSetup ? "🛠️ Run Setup Wizard" : "🛠️ Setup already applied"
    gui.SetupChip.Text := needsSetup ? "Setup status: Needs action" : "Setup status: OK"
    gui.SetupChip.Opt("c" . (needsSetup ? "FFB020" : "9CA3AF"))

    summary := []
    summary.Push("═══════════════════════════════════════")
    summary.Push("  SYSTEM STATUS REPORT")
    summary.Push("═══════════════════════════════════════")
    summary.Push("")
    summary.Push("🖥️  Host: " . (status.Has("host") ? status["host"] : A_ComputerName))
    summary.Push("")
    ready := (status.Has("summary") && status["summary"].Has("ready")) ? status["summary"]["ready"] : false
    readyIcon := ready ? "✅" : "⚠️"
    summary.Push(readyIcon . "  Ready: " . (ready ? "Yes" : "Needs attention"))
    summary.Push("")
    localMode := status.Has("localModeEnabled") ? status["localModeEnabled"] : false
    localIcon := localMode ? "🔒" : "🌐"
    summary.Push(localIcon . "  Local mode: " . (localMode ? "Enabled" : "Disabled"))
    summary.Push("")
    hasUsers := status.Has("sessions") && status["sessions"].Has("hasOtherUsers") && status["sessions"]["hasOtherUsers"]
    userIcon := hasUsers ? "👤" : "○"
    summary.Push(userIcon . "  Active sessions: " . (hasUsers ? "Present" : "None"))
    summary.Push("")
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

LS_GuiRunSetup() {
    if (!LS_GuiEnsureAdmin())
        return
    LS_RunSetupWizard()
    ; Refresh status after setup
    if (IsSet(LS_GUI) && LS_GUI)
        LS_GuiRefreshStatus(LS_GUI)
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

; Event handlers
LS_GuiRefreshStatus_Handler(ctrl, info) {
    LS_GuiRefreshStatus(ctrl.Gui)
}

LS_GuiExportStatus_Handler(ctrl, info) {
    LS_GuiExportStatus(ctrl.Gui)
}

LS_GuiOpenLog_Handler(ctrl, info) {
    LS_GuiOpenLog()
}

LS_GuiRunSetup_Handler(ctrl, info) {
    LS_GuiRunSetup()
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
