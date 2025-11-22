; ============================================================================
; Lab Station - Setup wizard
; ============================================================================
#Requires AutoHotkey v2.0
#Include ..\core\Config.ahk
#Include ..\core\Logger.ahk
#Include ..\core\Admin.ahk
#Include ..\system\RegistryManager.ahk
#Include ..\system\WakeOnLan.ahk
#Include ..\system\Autostart.ahk
#Include ..\system\AccountManager.ahk
#Include ..\diagnostics\Status.ahk

LS_RunSetupWizard() {
    if (!LS_EnsureAdmin()) {
        return false
    }
    mode := LS_WizardSelectMode()
    if (mode = "") {
        return false
    }
    steps := mode = "server" ? LS_WizardServerSteps() : LS_WizardHybridSteps()

    for step in steps {
        response := MsgBox(step["label"] . "?", "Lab Station Setup", "YesNo Iconi")
        if (response = "Yes") {
            success := step["action"].Call()
            if (success) {
                MsgBox "Completed: " . step["label"], "Lab Station", "OK Iconi"
            } else {
                MsgBox "There was an issue executing: " . step["label"], "Lab Station", "OK Iconx"
            }
        }
    }

    MsgBox "Setup completed. Check labstation.log for details.", "Lab Station", "OK Iconi"
    return true
}

LS_WizardSelectMode() {
    gui := Gui("+AlwaysOnTop +ToolWindow", "Lab Station Setup")
    gui.BackColor := "0F1419"
    gui.SetFont("s10", "Segoe UI")

    gui.SetFont("s14 Bold cFFFFFF", "Bahnschrift")
    gui.AddText("x20 y14", "⚙️ Select station profile")
    gui.SetFont("s9 c9CA3AF")
    gui.AddText("x20 yp+24 w400", "Non-destructive: close this window to cancel. Choose the mode that matches the host.")

    gui.SetFont("s10 cFFFFFF")
    serverBtn := gui.AddButton("x20 y78 w300 h36", "Dedicated Lab Server")
    hybridBtn := gui.AddButton("x20 y122 w300 h36", "Hybrid Lab Station")
    gui.SetFont("s8 cC08A2B")
    gui.AddText("x20 y166 w360", "Dedicated: LABUSER autologon + lockdown. Hybrid: coexists with local use.")

    result := ""
    serverBtn.OnEvent("Click", (*) => (result := "server", gui.Destroy()))
    hybridBtn.OnEvent("Click", (*) => (result := "hybrid", gui.Destroy()))
    gui.OnEvent("Close", (*) => gui.Destroy())

    gui.Show("w360 h200")
    while (gui && gui.Visible && result = "")
        Sleep 50
    try gui.Destroy()
    return result
}

LS_WizardServerSteps() {
    return [
        Map("label", "Create/configure LABUSER + Autologon", "action", Func("LS_WizardAccountServer")),
        Map("label", "Enable RemoteApp (fAllowUnlistedRemotePrograms)", "action", Func("LS_RegistryManager.SetRemoteAppPolicy")),
        Map("label", "Configure Wake-on-LAN", "action", Func("LS_WakeOnLan.Configure")),
        Map("label", "Register AppControl autostart", "action", Func("LS_WizardAutostartServer")),
        Map("label", "Export diagnostics report", "action", Func("LS_WizardDiagnostics"))
    ]
}

LS_WizardHybridSteps() {
    return [
        Map("label", "Create/update LABUSER (no autologon)", "action", Func("LS_WizardAccountHybrid")),
        Map("label", "Enable RemoteApp (fAllowUnlistedRemotePrograms)", "action", Func("LS_RegistryManager.SetRemoteAppPolicy")),
        Map("label", "Configure Wake-on-LAN", "action", Func("LS_WakeOnLan.Configure")),
        Map("label", "Register autostart only for LABUSER", "action", Func("LS_WizardAutostartHybrid")),
        Map("label", "Export diagnostics report", "action", Func("LS_WizardDiagnostics"))
    ]
}

LS_WizardDiagnostics() {
    if (LS_Status.ExportJson(LAB_STATION_STATUS_FILE)) {
        MsgBox "Report saved to " . LAB_STATION_STATUS_FILE, "Lab Station", "OK Iconi"
        return true
    }
    MsgBox "Unable to export report", "Lab Station", "OK Iconx"
    return false
}

LS_WizardAccountServer() {
    pass := ""
    if (LS_AccountManager.Setup("", pass)) {
        LS_WizardShowAccountInfo(pass, true)
        return true
    }
    return false
}

LS_WizardAccountHybrid() {
    pass := ""
    if (LS_AccountManager.EnsureAccount("", pass)) {
        LS_WizardShowAccountInfo(pass, false)
        return true
    }
    return false
}

LS_WizardShowAccountInfo(password, autologon := false) {
    text := "User: " . LS_AccountManager.DefaultUser . "`nPassword: " . password
    if (autologon) {
        text .= "`nAutologon enabled. Store the credentials safely."
    } else {
        text .= "`nUse these credentials when Lab Gateway prepares remote sessions."
    }
    MsgBox text, "Lab Station", "OK Iconi"
}

LS_WizardAutostartServer() {
    return LS_Autostart.Configure()
}

LS_WizardAutostartHybrid() {
    return LS_Autostart.Configure("", LS_AccountManager.DefaultUser)
}
