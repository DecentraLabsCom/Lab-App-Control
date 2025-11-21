; ============================================================================
; Lab Station - Account management helpers
; ============================================================================
#Requires AutoHotkey v2.0
#Include ..\core\Config.ahk
#Include ..\core\Logger.ahk
#Include ..\core\Admin.ahk
#Include ..\core\Shell.ahk

class LS_AccountManager {
    static DefaultUser := "LABUSER"

    static Setup(user := "", ByRef password := "") {
        if (!LS_EnsureAdmin()) {
            return false
        }
        if (!user || user = "") {
            user := this.DefaultUser
        }
        localPass := password
        if (!this.EnsureAccount(user, localPass)) {
            return false
        }
        if (!this.ConfigureAutologon(user, localPass)) {
            return false
        }
        password := localPass
        return this.ApplyLockdown(user)
    }

    static EnsureAccount(user := "", ByRef password := "") {
        if (!LS_EnsureAdmin()) {
            return false
        }
        if (!user || user = "") {
            user := this.DefaultUser
        }
        localPassword := password && password != "" ? password : this.GeneratePassword()
        script := Format("@'`n$User = \"{1}\"`n$Password = \"{2}\"`n$secure = ConvertTo-SecureString $Password -AsPlainText -Force`n$description = 'DecentraLabs Lab Station service account'`nif (-not (Get-LocalUser -Name $User -ErrorAction SilentlyContinue)) {{`n    New-LocalUser -Name $User -Password $secure -PasswordNeverExpires $true -AccountNeverExpires $true -Description $description -UserMayNotChangePassword $true | Out-Null`n}} else {{`n    Set-LocalUser -Name $User -Password $secure -PasswordNeverExpires $true -UserMayNotChangePassword $true -AccountNeverExpires $true -Description $description`n    Enable-LocalUser -Name $User -ErrorAction SilentlyContinue | Out-Null`n}}`n$groups = @('Users', 'Remote Desktop Users')`nforeach ($group in $groups) {{`n    try {{ Add-LocalGroupMember -Group $group -Member $User -ErrorAction SilentlyContinue }} catch {{}}`n}}`ntry {{ Remove-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction SilentlyContinue }} catch {{}}`n'@", user, localPassword)
        exitCode := LS_RunPowerShell(script, "Configure lab service account")
        if (exitCode = 0) {
            password := localPassword
            LS_LogInfo(Format("Account {1} created/updated", user))
            return true
        }
        LS_LogError(Format("Unable to create/configure account {1} (exit={2})", user, exitCode))
        return false
    }

    static ConfigureAutologon(user, password, domain := "") {
        if (!LS_EnsureAdmin()) {
            return false
        }
        if (!user || user = "") {
            user := this.DefaultUser
        }
        if (!password || password = "") {
            LS_LogError("Password required to configure Autologon")
            return false
        }
        key := "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
        try {
            RegWrite("1", "REG_SZ", key, "AutoAdminLogon")
            RegWrite(user, "REG_SZ", key, "DefaultUserName")
            RegWrite(password, "REG_SZ", key, "DefaultPassword")
            RegWrite(domain, "REG_SZ", key, "DefaultDomainName")
            RegWrite("1", "REG_DWORD", key, "ForceAutoLogon")
            RegWrite("0", "REG_DWORD", key, "DisableCAD")
            LS_LogInfo("Autologon configured successfully")
            return true
        } catch as e {
            LS_LogError("Error configuring Autologon: " . e.Message)
            return false
        }
    }

    static ApplyLockdown(user := "") {
        if (!LS_EnsureAdmin()) {
            return false
        }
        if (!user || user = "") {
            user := this.DefaultUser
        }
        ok := true
        ok := this.EnsureRemoteDesktopRestrictions(user) && ok
        ok := this.ConfigureDenyInteractiveLogon(user) && ok
        ok := this.RefreshAutologonState(user) && ok
        if (ok) {
            LS_LogInfo("Lockdown applied")
        } else {
            LS_LogWarning("Lockdown completed with warnings")
        }
        return ok
    }

    static EnsureRemoteDesktopRestrictions(user) {
        script := Format("@'`n$User = \"{1}\"`n$group = 'Remote Desktop Users'`n$members = Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue`nforeach ($member in $members) {{`n    if ($member.ObjectClass -eq 'User' -and $member.Name -ne $User) {{`n        try {{ Remove-LocalGroupMember -Group $group -Member $member.Name -ErrorAction SilentlyContinue }} catch {{}}`n    }}`n}`ntry {{`n    Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0`n    New-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon' -Name 'DisableLockWorkstation' -Value 1 -PropertyType DWORD -Force | Out-Null`n}} catch {{}}`n'@", user)
        exitCode := LS_RunPowerShell(script, "Restrict Remote Desktop users")
        if (exitCode != 0) {
            LS_LogError("Unable to adjust Remote Desktop Users membership (exit=" . exitCode . ")")
            return false
        }
        return true
    }

    static ConfigureDenyInteractiveLogon(user) {
        script := this.BuildDenyInteractiveScript(user)
        exitCode := LS_RunPowerShell(script, "Configure SeDenyInteractiveLogonRight")
        if (exitCode != 0) {
            LS_LogError("Unable to apply SeDenyInteractiveLogonRight (exit=" . exitCode . ")")
            return false
        }
        return true
    }

    static BuildDenyInteractiveScript(user) {
        escaped := this.EscapeForPSSingleQuote(user)
        template := "@'`n$ErrorActionPreference = 'Stop'`n$target = '__LABUSER__'`n$targetLower = $target.ToLower()`n$exempt = @('__LABUSER__','Administrator','DefaultAccount','WDAGUtilityAccount','Guest') | ForEach-Object { $_.ToLower() }`n$localUsers = Get-LocalUser -ErrorAction SilentlyContinue`n$targetSid = ''`ntry { $targetSid = ($localUsers | Where-Object { $_.Name -eq $target } | Select-Object -First 1).SID.Value } catch {}`n$denySids = New-Object System.Collections.Generic.List[string]`n$tempExport = Join-Path $env:TEMP ('ls-secexport-' + [guid]::NewGuid().Guid + '.inf')`nsecedit /export /cfg $tempExport /areas USER_RIGHTS | Out-Null`nif (Test-Path $tempExport) {`n    foreach ($line in Get-Content $tempExport) {`n        if ($line -match '^SeDenyInteractiveLogonRight\s*=\s*(.*)$') {`n            $tokens = $Matches[1].Split(',')`n            foreach ($token in $tokens) {`n                $t = $token.Trim()`n                if (-not $t) { continue }`n                if ($targetSid -and $t -eq ('*' + $targetSid)) { continue }`n                if ($t.ToLower() -eq $targetLower) { continue }`n                [void]$denySids.Add($t)`n            }`n            break`n        }`n    }`n    Remove-Item $tempExport -Force -ErrorAction SilentlyContinue`n}`nforeach ($user in $localUsers) {`n    $nameLower = $user.Name.ToLower()`n    if ($nameLower -eq $targetLower) { continue }`n    if ($exempt -contains $nameLower) { continue }`n    try {`n        $sid = $user.SID.Value`n        if (-not $sid) { continue }`n        $token = '*' + $sid`n        if (-not $denySids.Contains($token)) { [void]$denySids.Add($token) }`n    } catch {}`n}`nif ($denySids.Count -eq 0) { [void]$denySids.Add('*S-1-5-32-546') }`n$tempCfg = Join-Path $env:TEMP ('ls-deny-' + [guid]::NewGuid().Guid + '.inf')`n$cfg = @"`n[Unicode]`nUnicode=yes`n[Version]`nsignature=""$CHICAGO$""`nRevision=1`n[Privilege Rights]`nSeDenyInteractiveLogonRight = {0}`n"@ -f ($denySids -join ',')`n$cfg | Out-File -FilePath $tempCfg -Encoding Unicode -Force`n$dbPath = Join-Path $env:TEMP 'ls-deny.sdb'`n& secedit /configure /db $dbPath /cfg $tempCfg /areas USER_RIGHTS /quiet | Out-Null`n$code = $LASTEXITCODE`nRemove-Item $tempCfg -Force -ErrorAction SilentlyContinue`nif ($code -ne 0) { throw "secedit failed with exit code $code" }`n'@"
        return StrReplace(template, "__LABUSER__", escaped)
    }

    static RefreshAutologonState(user) {
        password := this.GetStoredAutologonPassword()
        if (password = "") {
            LS_LogWarning("Autologon password not found; skipping refresh")
            return false
        }
        domain := ""
        key := "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
        try domain := RegRead(key, "DefaultDomainName")
        return this.ConfigureAutologon(user, password, domain)
    }

    static GetStoredAutologonPassword() {
        key := "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
        try {
            return RegRead(key, "DefaultPassword")
        } catch {
            return ""
        }
    }

    static EscapeForPSSingleQuote(value) {
        return StrReplace(value, "'", "''")
    }

    static GeneratePassword(length := 20) {
        chars := "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
        password := ""
        total := StrLen(chars)
        Loop length {
            idx := Floor(Random() * total) + 1
            password .= SubStr(chars, idx, 1)
        }
        return password
    }
}
