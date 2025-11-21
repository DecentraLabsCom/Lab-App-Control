; ============================================================================
; Lab Station - Core Configuration
; ============================================================================
#Requires AutoHotkey v2.0

if (!IsSet(LAB_STATION_VERSION)) {
    global LAB_STATION_VERSION := "1.0.0-alpha"
}

if (!IsSet(LAB_STATION_ROOT)) {
    ; LabStation scripts live inside the labstation/ folder. Project root is one level up.
    global LAB_STATION_ROOT := A_ScriptDir
    global LAB_STATION_PROJECT_ROOT := NormalizePath(A_ScriptDir "\..")
}

if (!IsSet(LAB_STATION_LOG)) {
    global LAB_STATION_LOG := LAB_STATION_ROOT "\labstation.log"
}

NormalizePath(path) {
    try {
        return StrReplace(Trim(DirExist(path) ? DirExist(path) : PathGet(path)), "//", "\\")
    } catch {
        return path
    }
}

PathGet(path) {
    return (SubStr(path, 1, 2) = "\\" ? path : FileExist(path) ? (GetFullPathName(path)) : path)
}

GetFullPathName(path) {
    buf := Buffer(32768)
    size := DllCall("GetFullPathName", "str", path, "UInt", buf.Size, "str", buf, "ptr", 0, "UInt")
    if (size = 0 || size > buf.Size) {
        return path
    }
    return StrGet(buf, size)
}
