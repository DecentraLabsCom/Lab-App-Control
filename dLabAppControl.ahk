#SingleInstance Force
;ProcessSetPriority "High"

if (A_Args.Length < 2)
{
    MsgBox "Use: ControlApp.ahk [window ahk_class] [C:\path\to\app.exe]"
    ExitApp
}
windowClass := A_Args[1]
appPath := A_Args[2]

tempFile := A_Temp . "\RDPLastEvent.txt"

psScript := "
(
    $tempFile = Join-Path $env:TEMP 'RDPLastEvent.txt'
    $e = Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
        ID=24,40
    } -MaxEvents 1 -ErrorAction SilentlyContinue
    if($e) {
		$e.RecordId | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
	} else {
		'0' | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
	}
)"
lastEventId := GetLastSessionEventId()

window_id := WinWait("ahk_class " . windowClass, , 0.4)
if (!window_id) {
	Run appPath
	window_id := WinWait("ahk_class " . windowClass, , 5)
	if (!window_id) {
        MsgBox "Couldn't open lab app at: " appPath
        ExitApp
    }
}

if (WinExist(window_id)) {
	WinActivate window_id
	WinMaximize window_id
	WinSetStyle "-0x20000, window_id"  ; Remove minimize button
	WinSetStyle "-0xC00000, window_id" ; Remove close button
}

SetTimer(CheckSessionEvents, 4000)  ; Check session events every 4 seconds


; FUNCTIONS

; Obtain the ID for the last registered session disconnect or close event
GetLastSessionEventId() {
	global tempFile, psScript

	RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' psScript '"', , "Hide")

	if (FileExist(tempFile)) {
		result := FileRead(tempFile)
		return result ~= "^\d+$" ? Integer(result) : 0
	}
	return 0
}

CheckSessionEvents() {
	global tempFile, psScript, lastEventId, window_id

	RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' psScript '"', , "Hide")

	if (FileExist(tempFile)) {
		result := FileRead(tempFile)
		if (result != lastEventId) {
			; Close window and stop script execution when a new event has been registered
			lastEventId := result
			if (WinExist(window_id)) { 
				WinClose window_id	
			}
			ExitApp
		}
	}
}