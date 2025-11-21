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
    prompt := "Select the station profile:" . "`n`n" .
        "Yes = Dedicated lab server (LABUSER autologon + lockdown)." . "`n" .
        "No = Hybrid station (coexists with local usage)." . "`n" .
        "Cancel = Exit the wizard."
    choice := MsgBox(prompt, "Lab Station Setup", "YesNoCancel Iconi")
    if (choice = "Cancel") {
        return ""
    }
    return choice = "Yes" ? "server" : "hybrid"
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
