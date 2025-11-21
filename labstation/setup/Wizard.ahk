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

LS_RunSetupWizard() {
    if (!LS_EnsureAdmin()) {
        return false
    }
    steps := [
        Map("label", "Habilitar RemoteApp (fAllowUnlistedRemotePrograms)", "action", Func("LS_RegistryManager.SetRemoteAppPolicy")),
        Map("label", "Configurar Wake-on-LAN", "action", Func("LS_WakeOnLan.Configure")),
        Map("label", "Configurar inicio automático de dLabAppControl", "action", Func("LS_Autostart.Configure"))
    ]

    for step in steps {
        response := MsgBox(step["label"] . "?", "Lab Station Setup", "YesNo Iconi")
        if (response = "Yes") {
            success := step["action"].Call()
            if (success) {
                MsgBox "Completado: " . step["label"], "Lab Station", "OK Iconi"
            } else {
                MsgBox "Hubo un problema al ejecutar: " . step["label"], "Lab Station", "OK Iconx"
            }
        }
    }

    MsgBox "Setup finalizado. Revisa labstation.log para más detalles.", "Lab Station", "OK Iconi"
    return true
}
