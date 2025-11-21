; ============================================================================
; Lab Station - Dedicated lab workstation controller
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include core\Config.ahk
#Include core\Logger.ahk
#Include core\Admin.ahk
#Include core\Shell.ahk
#Include system\RegistryManager.ahk
#Include system\WakeOnLan.ahk
#Include system\Autostart.ahk
#Include setup\Wizard.ahk

LabStationMain(A_Args)
return

LabStationMain(args) {
    if (args.Length = 0) {
        LS_ShowHelp()
        return
    }

    command := StrLower(args[1])
    remaining := args.Length > 1 ? args[2..] : []

    switch command {
        case "setup":
            LS_RunSetupWizard()
        case "remoteapp":
            LS_RegistryManager.SetRemoteAppPolicy()
        case "wol":
            LS_WakeOnLan.Configure()
        case "autostart":
            target := remaining.Length >= 1 ? remaining[1] : ""
            if (target != "") {
                LS_Autostart.Configure(target)
            } else {
                LS_Autostart.Configure()
            }
        case "launch-app-control":
            LS_LaunchAppControl(remaining)
        default:
            LS_LogWarning("Unknown command: " . command)
            LS_ShowHelp()
    }
}

LS_ShowHelp() {
    text := "Lab Station " . LAB_STATION_VERSION . "`n" .
        "Uso:" . "`n" .
        "  LabStation.exe setup                 # Ejecutor interactivo" . "`n" .
        "  LabStation.exe remoteapp            # Configura fAllowUnlistedRemotePrograms" . "`n" .
        "  LabStation.exe wol                  # Configura Wake-on-LAN" . "`n" .
        "  LabStation.exe autostart [ruta]     # Configura inicio automático del controlador" . "`n" .
        "  LabStation.exe launch-app-control [args...]" . "`n"
    MsgBox text, "Lab Station", "OK"
}

LS_LaunchAppControl(args) {
    controllerExe := LAB_STATION_PROJECT_ROOT "\dLabAppControl.exe"
    controllerScript := LAB_STATION_PROJECT_ROOT "\dLabAppControl.ahk"
    if (FileExist(controllerExe)) {
        Run Format('"{1}" {2}', controllerExe, LS_BuildCliFromArgs(args))
        return
    }
    if (!FileExist(controllerScript)) {
        MsgBox "No se encontró dLabAppControl en el directorio del proyecto.", "Lab Station", "OK Iconx"
        LS_LogError("dLabAppControl.* not available")
        return
    }
    Run Format('"{1}" "{2}" {3}', A_AhkPath, controllerScript, LS_BuildCliFromArgs(args))
}

LS_BuildCliFromArgs(args) {
    cli := ""
    for arg in args {
        cli .= (cli = "" ? "" : " ") . LS_EscapeCliArgument(arg)
    }
    return cli
}
