; ============================================================================
; Lab Station - Autostart configuration
; ============================================================================
#Requires AutoHotkey v2.0
#Include ..\core\Config.ahk
#Include ..\core\Logger.ahk
#Include ..\core\Admin.ahk
#Include RegistryManager.ahk

class LS_Autostart {
    static Configure(appPath := "") {
        if (!appPath || appPath = "") {
            exePath := LAB_STATION_PROJECT_ROOT "\dLabAppControl.exe"
            ahkPath := LAB_STATION_PROJECT_ROOT "\dLabAppControl.ahk"
            appPath := FileExist(exePath) ? exePath : Format('"{1}" "{2}"', A_AhkPath, ahkPath)
        }
        command := appPath
        return LS_RegistryManager.SetRunEntry("LabStationAppControl", command)
    }
}
