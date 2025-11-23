# Remote consumption of `heartbeat.json` and telemetry

This document explains how Lab Gateway should ingest the telemetry Lab Station publishes without relying on persistent WinRM sessions.

## 1. Files produced by Lab Station

| File | Frequency | Contents | Suggested use |
| --- | --- | --- | --- |
| `labstation/data/telemetry/heartbeat.json` | Every minute (service) | Full snapshot of `status.json` plus an `operations` block with the latest `prepare-session`, `release-session`, `safeguard-reboot`, and `forced-logoff` runs. | Single source of truth for dashboards and quick alerts. |
| `labstation/data/status.json` | On demand (`status-json`) | Same schema as the `status` field inside the heartbeat. | Export on demand when WinRM is already active. |
| `labstation/data/telemetry/session-guard-events.jsonl` | Only when evictions occur | JSON Lines (one line per eviction) with `timestamp`, `user`, `sessionId`, `grace`, `force`, `message`, `source`. | Historical audit trail and booking traceability. |
| `labstation/data/service-state.ini` | After each relevant operation | Latest results from `prepare-session`, `release-session`, `safeguard-reboot`, and `forced-logoff`. | Backup for the `operations` block; useful if the heartbeat is lost. |
| `reservation_operations` (MySQL) | On every `/ops/api/reservations/start|end` execution | Persists WoL/prepare/release/power outcomes per reservation (status, duration, stdout/stderr). | Feed reservation timelines and SLA tracking dashboards. |

## 2. Ingestion strategy

**Lab Gateway implementation (ops-worker)**

Lab Gateway ahora incluye `ops-worker` (Python/Flask) que automatiza la ingesta:

1. **Polling automático**: Configurar `OPS_POLL_ENABLED=true` y `OPS_POLL_INTERVAL=60` (segundos) en `docker-compose.yml`.
2. **Endpoints disponibles**:
   - `POST /api/heartbeat/poll` - Lee `heartbeat.json` vía WinRM, persiste en MySQL
   - `POST /api/wol` - Envía magic packet + valida ping con reintentos
   - `POST /api/winrm` - Proxy para ejecutar comandos `LabStation.exe`
3. **MySQL persistence**: Schema `005-labstation-ops.sql` con `lab_hosts`, `lab_host_heartbeat`, `lab_host_events`.
4. **Lab Manager UI**: Panel visual en `/lab-manager` para monitoreo y acciones rápidas.

**Manual polling (alternativa)**

Si prefieres lógica custom sin ops-worker:

### Quick PowerShell example

```powershell
param(
    [string]$Host = "LAB-WS01",
    [string]$DataShare = "\\LAB-WS01\LabStation"
)
$heartbeatPath = Join-Path $DataShare 'data/telemetry/heartbeat.json'
if (!(Test-Path $heartbeatPath)) {
    throw "Heartbeat not found on $Host. Ensure the LabStation share is published."
}
$content = Get-Content $heartbeatPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nicIssues = 0
if ($content.status.wake.nicNonCompliant) {
    $nicIssues = $content.status.wake.nicNonCompliant.Count
}
$lastPower = $content.operations.lastPowerAction
$lastPowerTimestamp = $null
$lastPowerMode = $null
if ($lastPower) {
    $lastPowerTimestamp = $lastPower.timestamp
    $lastPowerMode = $lastPower.mode
}
$summary = [pscustomobject]@{
    Host = $content.host
    Updated = $content.timestamp
    Ready = $content.summary.ready
    LocalMode = $content.status.localModeEnabled
    LocalUsers = $content.status.localSessionActive
    NicIssues = $nicIssues
    SleepCompliant = $content.status.power.sleepCompliant
    HibernateCompliant = $content.status.power.hibernateCompliant
    LastPrepare = $content.operations.lastPrepareSession.timestamp
    LastPowerAction = $lastPowerTimestamp
    LastPowerMode = $lastPowerMode
    LastForcedLogoffUser = $content.operations.lastForcedLogoff.user
}
$summary
```

> **Tip:** If SMB is not exposed, use `Copy-Item -FromSession (New-PSSession -ComputerName $Host) -Path 'C:\LabStation\labstation\data\telemetry\heartbeat.json' -Destination 'C:\Temp\heartbeat.json'`.

## 3. Key fields for dashboards

- `summary.ready`: `true` when RemoteApp, autostart, WoL, and policies are healthy.
- `status.localSessionActive`: signals if a local session is still active (instructor). Combine with `operations.lastForcedLogoff.timestamp` to know if the host was cleaned.
- `status.localModeEnabled`: reflects the presence of `data/local-mode.flag`; the UI should block reservations while this is true.
- `status.wake.nicPower`: array of adapters with `wolReady`, `wakeArmed`, and `complianceIssues` (Wake on Magic Packet, Wake on Pattern, AllowTurnOff). Allows alerts when someone re-enabled "Allow computer to turn off" or the wake patterns changed.
- `status.power.sleepCompliant` / `power.hibernateCompliant`: confirm that `powercfg /q` still shows 0 seconds for AC/DC.
- `operations.lastPrepareSession` / `lastReleaseSession`: include `timestamp`, `success`, and metadata (`durationMs`, `user`). Useful for preparation/cleanup SLAs.
- `operations.lastForcedLogoff`: mirrors the latest line in the JSONL log; lets you show whom the instructor expelled and the message used.
- `operations.lastPowerAction`: tracks when the last `power shutdown`/`power hibernate` was requested, whether it was forced, and if the WoL check passed (`wakeReady`).

## 4. Recommended alerts

| Condition | How to detect it | Suggested response |
| --- | --- | --- |
| `summary.ready = false` for >2 minutes | Read `content.summary.ready` | Open an incident or trigger `recovery reboot-if-needed` automatically. |
| `status.localSessionActive = true` just before a reservation | Compare each poll with the schedule | Notify the instructor and run `session guard` manually if the grace period expires. |
| `status.localModeEnabled = true` while there are pending reservations | Inspect the flag | Block new reservations or ask for explicit confirmation. |
| `operations.lastForcedLogoff.timestamp` > 15 minutes before the reservation | Compare with start time | Repeat `session guard` to ensure the host is cleaned shortly before the session. |
| Missing `heartbeat.json` for >3 intervals | Detect an unchanged `timestamp` | Mark the host as down and trigger a WoL check. |

## 5. Historical persistence

Although the heartbeat is a snapshot, store each version in a table such as `lab_station_heartbeat` with:

- Key `(host, timestampUtc)`
- Raw JSON (for traceability) plus denormalized columns (`ready`, `localModeEnabled`, etc.)
- Link to the active reservation so you can reconstruct what happened if disputes arise.

## 6. Relationship with `session-guard-events.jsonl`

- When `operations.lastForcedLogoff.timestamp` changes, read the latest lines from the JSONL file until you find the matching timestamp.
- Save that event in the backend database (`reservation_forced_logoffs`). Include `user`, `sessionId`, `grace`, `message`, and `force`.
- Surface it to the operator alongside the reservation to justify automatic evictions.

With this flow, the backend consumes all telemetry from a simple file drop and avoids constant WinRM calls.
