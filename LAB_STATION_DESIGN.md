# Lab Station v1.0 (Fase 1)

## Objetivos

- Evolucionar *Lab App Control* a una plataforma completa para estaciones de laboratorio.
- Automatizar configuraciones críticas de Windows (RemoteApp, Wake-on-LAN, arranque de controladores).
- Mantener compatibilidad con el controlador actual (`dLabAppControl`).

## Alcance Fase 1

1. **Setup asistido (wizard)**
   - Solicita permisos de administrador.
   - Habilita RemoteApp (`fAllowUnlistedRemotePrograms`).
   - Configura Wake-on-LAN (adaptador + plan de energía).
   - Registra `dLabAppControl` en Run (HKLM) para iniciar con el sistema.

2. **CLI / Automatización**
   - `LabStation.ahk` admite comandos directos: `setup`, `remoteapp`, `wol`, `autostart`, `launch-app-control`.
   - Reutiliza AutoHotkey v2 para orquestar scripts, PowerShell y registro.

3. **Compatibilidad**
   - `launch-app-control` reusa `dLabAppControl.exe` si existe, o compila al vuelo usando AHK.
   - No se rompe el release actual; Lab Station vive en carpeta `labstation/`.

## Arquitectura

```
labstation/
├── LabStation.ahk              # Punto de entrada CLI
├── core/
│   ├── Config.ahk              # Rutas, versión, log
│   ├── Logger.ahk              # Logging centralizado
│   ├── Admin.ahk               # Verificación/admin helpers
│   └── Shell.ahk               # Ejecución PowerShell/CLI
├── system/
│   ├── RegistryManager.ahk     # HKLM policies + Run entries
│   ├── WakeOnLan.ahk           # Configuración WOL vía PowerShell
│   └── Autostart.ahk           # Registro de inicio con Windows
└── setup/
    └── Wizard.ahk              # Asistente interactivo (MsgBox)
```

## Roadmap próximo

- **v1.1**
  - Validaciones y reporte de estado (logs, export JSON).
  - Detección de compatibilidad BIOS/firmware para WOL (documentación de pasos manuales).
  - Integración básica con Guacamole (generar plantillas).

- **v1.5**
  - UI en bandeja del sistema con estado en tiempo real.
  - Gestión de servicios (instalación opcional como servicio Windows).
  - Panel de diagnóstico rápido (verificar RemoteApp, WoL, autostart y exportar informe).

- **v2.0**
  - Orquestación remota (API ligera + CLI remoto).
  - Dashboard de salud y diagnósticos avanzados.
  - Integraciones con sistemas de ticketing/alerting.

## Notas de implementación

- Todas las operaciones críticas escriben en `labstation/labstation.log`.
- Se requiere ejecutar como administrador; el wizard lo valida antes de aplicar cambios.
- Wake-on-LAN depende también de configuración BIOS. El script documenta que la parte de firmware sigue siendo manual.
- Se mantienen los tests y pipelines previos; la nueva carpeta no interfiere con `dLabAppControl.ahk` ni el release.
