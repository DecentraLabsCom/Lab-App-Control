---
description: Automatically open and close Windows lab apps based on user sessions.

The script includes several configuration constants that can be modified at the top of the file:

#### **Core Settings**
* **`POLL_INTERVAL_MS`**: Monitoring interval in milliseconds (default: **2000** = 2 seconds)
* **`STARTUP_TIMEOUT`**: How long to wait for app window to appear (default: **6** seconds)
* **`CloseOnEventIds`**: RDP event IDs that trigger app closure (default: `[23, 24, 40]`)
  - `23`: Logoff, `24`: Disconnect, `40`: Reconnect

#### **Debugging & Testing**
* **`VERBOSE_LOGGING`**: Enable detailed polling logs (default: `false` for production)
* **`RDP_CONTEXT`**: Enhanced logging for RDP/Guacamole environments (default: `true`)
* **`TEST_MODE`**: Test custom close after 5 seconds - **DISABLE IN PRODUCTION** (default: `true`)

#### **Custom Close Methods**
The script supports three ways to close applications gracefully:

1. **Standard cascade**: `WinClose` → `WM_SYSCOMMAND` → `WM_CLOSE` → `ProcessClose`
2. **ClassNN control**: For Win32 apps with accessible controls
   ```powershell
   dLabAppControl_v2.exe "Notepad" "notepad.exe" "Button2"
   ```
3. **Client coordinates**: For LabVIEW/custom apps (use WindowSpy CLIENT coordinates)
   ```powershell
   dLabAppControl_v2.exe "LVWindow" "myVI.exe" 330 484
   ```

#### **Finding Window Information**
Use the included **WindowSpy.exe** tool to identify:
- **Window Class** (`ahk_class`): Used as first parameter
- **ClassNN** controls: For control-based closing
- **CLIENT coordinates**: Most reliable for custom apps (not Screen or Window coordinates)

#### **Log Files**
- Location: Same directory as script/exe (`dLabAppControl.log`)
- Contains: Startup info, coordinate calculations, event detection, close attempts
- Enable `VERBOSE_LOGGING` for detailed polling information.
---

# Lab Control

**dLabAppControl** is an AutoHotKey script designed to auto-control the lab app lifecycle based on user session events (RDP) in the DecentraLabs lab provider machine.

This single-instance AHK v2 script that launches your lab control app on connect, keeps it foregrounded, and closes it automatically when the user session changes (e.g., disconnects).

> Usage:\
> `dLabAppControl.exe "WindowClass" "C:\path\to\app.exe"`
>
> Advanced usage with custom close:\
> `dLabAppControl.exe "WindowClass" "C:\path\to\app.exe" "Button2"`\
> `dLabAppControl.exe "LVWindow" "C:\path\to\myVI.exe" 330 484`
>
> or
>
> `dLabAppControl.ahk "window ahk_class" "C:\path\to\app.exe"`

***

### 🚀 Features

* **Single instance & CLI args**\
  Runs as a single instance and takes two arguments: target window class and app executable path.
* **Smart auto-startup**\
  If the target window isn’t found, it launches the lab control app and waits (up to 5 s) for the window.
* **Window management & hardening**\
  Activates and maximizes the window; removes minimize and close buttons to prevent user-initiated closure.
* **Session-aware auto-shutdown**\
  Automatically closes the app when a **new RDP session event** is detected (e.g., connect/reconnect/disconnect from _Microsoft-Windows-TerminalServices-LocalSessionManager/Operational_, IDs 24/40).
* **Background monitoring (2 s interval)**\
  Runs silently, polling every 2 s via native `wevtutil` (faster than PowerShell).
* **Custom close methods**\
  Supports graceful app closure via ClassNN controls or X,Y coordinates for LabVIEW/custom apps.
* **Smart coordinate handling**\
  Automatically converts WindowSpy CLIENT coordinates to screen coordinates with robust fallbacks.
* **Enhanced logging**\
  Detailed logs saved to script directory with configurable verbosity for debugging.
* **Lightweight integration**\
  No changes to the lab application; acts as a wrapper on the provider’s Windows machine. Optional compile to EXE.

***

### 🔧 Installation and Use

First option (using the executable):

1. Download `dLabAppControl.exe`.
2.  Run with:

    ```powershell
    # Basic usage
    .\dLabAppControl.exe "YourWindowClass" "C:\Path\To\LabControl.exe"
    
    # With custom close button (ClassNN)
    .\dLabAppControl.exe "Notepad" "C:\Windows\System32\notepad.exe" "Button2"
    
    # With custom close coordinates (LabVIEW/custom apps)
    .\dLabAppControl.exe "LVWindow" "C:\Path\To\myVI.exe" 330 484
    ```

Second option (download and compile script)

1. Install AutoHotKey v2.
2. Place `dLabAppControl.ahk` on the provider machine.
3.  (Optional) Compile:

    ```powershell
    Ahk2Exe.exe /in dLabAppControl.ahk /out dLabAppControl.exe
    ```
4.  Run with:

    ```powershell
    AutoHotkey.exe dLabAppControl.ahk "YourWindowClass" "C:\Path\To\LabControl.exe"
    ```

***

### 🌐 Integration with DecentraLabs

Run this script **when a user session starts** (e.g., on Guacamole/RDP connect).\
It will keep the lab app active and **will close it on the next RDP session event** (typically the disconnect at the end of the session).